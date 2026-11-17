import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/completion_record.dart';
import '../../study/data/firestore_study_repository.dart';
import '../domain/common_hall_models.dart';
import 'common_hall_repository.dart';

class FirestoreCommonHallRepository implements CommonHallRepository {
  FirestoreCommonHallRepository({required this.db, required this.currentUid});
  final FirebaseFirestore db;
  final String? Function() currentUid;
  String get uid =>
      currentUid() ??
      (throw const HallFailure('Sign in to study in the Common Hall.'));
  DocumentReference<Map<String, dynamic>> activeRef(String user) =>
      db.doc('users/$user/hallSession/current');
  DocumentReference<Map<String, dynamic>> presenceRef(String user) =>
      db.doc('commonHallPresence/$user');
  void _sameUser(String user) {
    if (currentUid() != user) {
      throw const HallFailure('Account changed. Reopen the Common Hall.');
    }
  }

  @override
  Stream<HallSession?> watchCurrentSession() {
    final user = uid;
    return activeRef(user)
        .snapshots(includeMetadataChanges: true)
        .where((snapshot) => !snapshot.metadata.hasPendingWrites)
        .map((snapshot) {
          _sameUser(user);
          return snapshot.exists ? decodeSession(snapshot.data()!) : null;
        });
  }

  @override
  Stream<List<HallParticipant>> watchParticipants() {
    final user = uid;
    final cutoff = DateTime.now().toUtc().subtract(
      HallSession.presenceLifetime,
    );
    return db
        .collection('commonHallPresence')
        .where('lastSeenAt', isGreaterThan: Timestamp.fromDate(cutoff))
        .snapshots(includeMetadataChanges: true)
        .where((snapshot) => !snapshot.metadata.hasPendingWrites)
        .map((snapshot) {
          _sameUser(user);
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return HallParticipant(
              userId: doc.id,
              sessionId: data['sessionId'],
              displayName: data['displayName'],
              avatarId: data['avatarId'],
              joinedAt: time(data['joinedAt']),
              lastSeenAt: time(data['lastSeenAt']),
            );
          }).toList()..sort((a, b) {
            final order = a.joinedAt.compareTo(b.joinedAt);
            return order == 0 ? a.userId.compareTo(b.userId) : order;
          });
        });
  }

  @override
  Future<HallSession?> getCurrentSession() async {
    final user = uid;
    final snapshot = await activeRef(user)
        .get(const GetOptions(source: Source.server));
    _sameUser(user);
    return snapshot.exists ? decodeSession(snapshot.data()!) : null;
  }

  @override
  Future<HallSession> enter({required String goalText}) async {
    final user = uid;
    final goal = goalText.trim().isEmpty ? 'Self study' : goalText.trim();
    if (goal.length > 160) {
      throw const HallFailure('Keep your goal within 160 characters.');
    }
    final id = 'hall-${db.collection('commonHallPresence').doc().id}';
    await db.runTransaction((tx) async {
      final existing = await tx.get(activeRef(user));
      if (existing.exists) return;
      final roomClaim = await tx.get(db.doc('activeSeatClaims/$user'));
      final roomSession = await tx.get(
        db.doc('users/$user/activeSession/current'),
      );
      final profile = (await tx.get(db.doc('users/$user'))).data();
      _sameUser(user);
      if (roomClaim.exists || roomSession.exists) {
        throw const HallFailure(
          'Finish your room session and release its desk before entering the Common Hall.',
        );
      }
      if (profile == null ||
          (profile['displayName'] as String? ?? '').trim().isEmpty) {
        throw const HallFailure('Set up your profile before entering.');
      }
      tx.set(activeRef(user), {
        'userId': user,
        'sessionId': id,
        'goalText': goal,
        'startsAt': FieldValue.serverTimestamp(),
        'confirmedAt': FieldValue.serverTimestamp(),
      });
      tx.set(presenceRef(user), {
        'userId': user,
        'sessionId': id,
        'displayName': profile['displayName'],
        'avatarId': profile['avatarId'] ?? 'default',
        'joinedAt': FieldValue.serverTimestamp(),
        'lastSeenAt': FieldValue.serverTimestamp(),
      });
    });
    return (await getCurrentSession())!;
  }

  @override
  Future<HallSession> renew(String expectedSessionId) async {
    final user = uid;
    await db.runTransaction((tx) async {
      final raw = (await tx.get(activeRef(user))).data();
      final presence = await tx.get(presenceRef(user));
      _sameUser(user);
      if (raw == null ||
          raw['sessionId'] != expectedSessionId ||
          !presence.exists ||
          presence.data()!['sessionId'] != expectedSessionId) {
        throw const HallFailure('This hall session has ended.');
      }
      if (!decodeSession(raw).isLive(DateTime.now())) {
        throw const HallFailure(
          'Hall connection expired. Save the confirmed time and start again.',
        );
      }
      tx.update(activeRef(user), {'confirmedAt': FieldValue.serverTimestamp()});
      tx.update(presenceRef(user), {
        'lastSeenAt': FieldValue.serverTimestamp(),
      });
    });
    return (await getCurrentSession())!;
  }

  @override
  Future<CompletionRecord> finish({
    required String expectedSessionId,
    required GoalOutcome goalOutcome,
  }) async {
    final user = uid;
    final destination = db.doc('users/$user/completions/$expectedSessionId');
    final saved = await destination.get(
      const GetOptions(source: Source.server),
    );
    _sameUser(user);
    if (saved.exists) return decodeCompletion(saved.data()!);
    final session = await getCurrentSession();
    if (session == null || session.sessionId != expectedSessionId) {
      throw const HallFailure('Session changed. Reopen the Common Hall.');
    }
    // A confirmed server timestamp supplies the final credit boundary. Expired
    // sessions retain only their last confirmed time, never a later offline gap.
    if (session.isLive(DateTime.now())) {
      try {
        await renew(expectedSessionId);
      } on HallFailure {
        // A lease may expire between the read and renewal. The transaction
        // below can still save its exact last-confirmed credit safely.
      } on FirebaseException catch (error) {
        if (error.code != 'permission-denied') rethrow;
      }
    }
    await db.runTransaction((tx) async {
      final existing = await tx.get(destination);
      if (existing.exists) return;
      final raw = (await tx.get(activeRef(user))).data();
      _sameUser(user);
      if (raw == null || raw['sessionId'] != expectedSessionId) {
        throw const HallFailure('Session changed. Reopen the Common Hall.');
      }
      final active = decodeSession(raw);
      final start = raw['startsAt'] as Timestamp,
          end = raw['confirmedAt'] as Timestamp;
      final elapsed =
          end.seconds -
          start.seconds -
          (end.nanoseconds < start.nanoseconds ? 1 : 0);
      tx.set(destination, {
        'recordId': expectedSessionId,
        'userId': user,
        'sessionId': expectedSessionId,
        'goalText': active.goalText,
        'endedAt': FieldValue.serverTimestamp(),
        'creditedSeconds': HallTiming.elapsed(elapsed).creditedSeconds,
        'timerStatus': 'completed',
        'goalOutcome': goalOutcome.name,
        'isDemo': false,
      });
      tx.delete(activeRef(user));
      tx.delete(presenceRef(user));
    });
    _sameUser(user);
    return decodeCompletion(
      (await destination.get(const GetOptions(source: Source.server))).data()!,
    );
  }

  static HallSession decodeSession(Map<String, dynamic> data) => HallSession(
    userId: data['userId'],
    sessionId: data['sessionId'],
    goalText: data['goalText'],
    startsAt: time(data['startsAt']),
    confirmedAt: time(data['confirmedAt']),
  );
}
