const { FieldValue, Timestamp } = require('firebase-admin/firestore');

// Trusted, idempotent continuation of M2's removalPending protocol. Clients can
// request cleanup but cannot acknowledge it or release another learner's seat.
async function completeMembershipCleanup(db, requestId) {
  const requestRef = db.doc(`membershipCleanupRequests/${requestId}`);
  const outside = await requestRef.get();
  if (!outside.exists || outside.data().status === 'completed') return;
  const uid = outside.data().userId;
  const hosted = await db.collectionGroup('rooms').where('hostUid', '==', uid).get();
  await db.runTransaction(async tx => {
    const request = (await tx.get(requestRef)).data();
    if (!request || request.status === 'completed') return;
    const markerRef = db.doc(`activeSeatClaims/${uid}`);
    const activeRef = db.doc(`users/${uid}/activeSession/current`);
    const claim = (await tx.get(markerRef)).data();
    const active = (await tx.get(activeRef)).data();
    const occupiedByUser = await tx.get(
      db.collectionGroup('seats').where('userId', '==', uid),
    );
    const reads = new Map();
    async function read(path) {
      if (!reads.has(path)) reads.set(path, (await tx.get(db.doc(path))).data());
      return reads.get(path);
    }
    async function inScope(subgroupId) {
      const group = await read(`subgroups/${subgroupId}`);
      return group && group.sigId === request.sigId &&
        (request.scope === 'sig' || request.subgroupId === subgroupId);
    }
    const memberPath = request.scope === 'sig'
      ? `sigs/${request.sigId}/members/${uid}`
      : `subgroups/${request.subgroupId}/members/${uid}`;
    const member = await read(memberPath);
    if (member?.status !== 'removalPending' || member.removalRequestId !== requestId) {
      throw new Error('Cleanup does not match the pending membership request');
    }
    const operations = [];
    const applicableSeats = [];
    for (const seatDocument of occupiedByUser.docs) {
      const seat = seatDocument.data();
      if (seat.status !== 'occupied') continue;
      const pathParts = seatDocument.ref.path.split('/');
      // Expected: subgroups/{subgroup}/rooms/{room}/seats/{seat}.
      if (pathParts.length !== 6 || pathParts[0] !== 'subgroups' ||
          pathParts[2] !== 'rooms' || pathParts[4] !== 'seats') {
        throw new Error('Occupied seat is stored at an invalid path; cleanup remains pending');
      }
      if (await inScope(pathParts[1])) applicableSeats.push({
        path: seatDocument.ref.path,
        subgroupId: pathParts[1],
        roomId: pathParts[3],
        seatId: pathParts[5],
        data: seat,
      });
    }
    const markerInScope = claim && await inScope(claim.subgroupId);
    if (applicableSeats.length > 1) {
      throw new Error('Multiple occupied seats are inconsistent; cleanup remains pending');
    }
    if (applicableSeats.length === 1) {
      const occupied = applicableSeats[0];
      if (!claim || !markerInScope || claim.userId !== uid ||
          claim.subgroupId !== occupied.subgroupId || claim.roomId !== occupied.roomId ||
          claim.seatId !== occupied.seatId || claim.claimId !== occupied.data.claimId ||
          !claim.claimId) {
        throw new Error('Occupied seat and claim marker disagree; cleanup remains pending');
      }
      operations.push(() => tx.set(db.doc(occupied.path), {
        seatId: occupied.seatId, status: 'available',
      }));
      operations.push(() => tx.delete(markerRef));
    } else if (markerInScope) {
      const path = `subgroups/${claim.subgroupId}/rooms/${claim.roomId}/seats/${claim.seatId}`;
      const seat = await read(path);
      if (seat?.status === 'occupied') {
        throw new Error('Claim marker points to an occupied seat absent from the user scan');
      }
      // No occupied seat is left behind. Removing a stale marker is safe.
      operations.push(() => tx.delete(markerRef));
    }
    if (active && await inScope(active.subgroupId)) {
      const session = await read(`roomSessions/${active.sessionId}`);
      const completionRef = db.doc(`users/${uid}/completions/${active.sessionId}`);
      const completion = await read(completionRef.path);
      if (!completion && session) operations.push(() => tx.create(completionRef, {
        recordId: active.sessionId, sessionId: active.sessionId, userId: uid,
        goalText: active.goalText, endedAt: FieldValue.serverTimestamp(), creditedSeconds: 0,
        timerStatus: 'endedEarly', goalOutcome: 'unfinished', isDemo: session.isDemo,
      }));
      operations.push(() => tx.delete(activeRef));
    }
    for (const document of hosted.docs) {
      const room = await read(document.ref.path);
      if (!room || room.hostUid !== uid || !await inScope(room.subgroupId)) continue;
      const seats = await tx.get(document.ref.collection('seats'));
      let successor = null;
      const sig = await read(`sigs/${request.sigId}`);
      for (const documentSeat of seats.docs) {
        const seat = documentSeat.data();
        if (seat.status !== 'occupied' || seat.userId === uid || !seat.claimId ||
            !seat.leaseExpiresAt || seat.leaseExpiresAt.toMillis() <= Date.now()) continue;
        const seatPath = documentSeat.ref.path.split('/');
        const claimMarker = await read(`activeSeatClaims/${seat.userId}`);
        if (claimMarker?.userId !== seat.userId || claimMarker.claimId !== seat.claimId ||
            claimMarker.subgroupId !== room.subgroupId || claimMarker.roomId !== seatPath[3] ||
            claimMarker.seatId !== seatPath[5] || !claimMarker.leaseExpiresAt ||
            claimMarker.leaseExpiresAt.toMillis() <= Date.now()) continue;
        const child = await read(`subgroups/${room.subgroupId}/members/${seat.userId}`);
        const parent = await read(`sigs/${request.sigId}/members/${seat.userId}`);
        if (child?.status === 'active' && sig?.status === 'active' &&
          ((sig.ownerId === seat.userId && (!parent || parent.status === 'active')) || parent?.status === 'active')) {
          successor = seat.userId;
          break;
        }
      }
      operations.push(() => tx.update(document.ref, successor
        ? {hostUid: successor, updatedAt: FieldValue.serverTimestamp()}
        : {status: 'closed', updatedAt: FieldValue.serverTimestamp()}));
    }
    // All reads above precede all writes, including membership checks for hosts.
    for (const operation of operations) operation();
    tx.update(requestRef, {status: 'completed', updatedAt: Timestamp.now()});
  });
}
module.exports = {completeMembershipCleanup};
