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
    if (claim && await inScope(claim.subgroupId)) {
      const path = `subgroups/${claim.subgroupId}/rooms/${claim.roomId}/seats/${claim.seatId}`;
      const seat = await read(path);
      if (seat?.userId === uid && seat.claimId === claim.claimId) {
        operations.push(() => tx.set(db.doc(path), {seatId: claim.seatId, status: 'available'}));
      }
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
        if (seat.status !== 'occupied' || seat.userId === uid || !seat.leaseExpiresAt || seat.leaseExpiresAt.toMillis() <= Date.now()) continue;
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
