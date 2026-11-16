import 'dart:async';

import '../core/models/active_room_session.dart';
import '../core/models/room_models.dart';
import '../features/sessions/data/active_session_repository.dart';

/// Preview/test-only active session data. Nothing is persisted or restored
/// after an app restart.
abstract final class ActiveSessionFixtures {
  static final nowUtc = DateTime.utc(2026, 11, 16, 8);

  static final validActiveSession = _session(
    userId: 'preview-user-1',
    seatId: 'seat-1',
    leaseExpiresAt: nowUtc.add(const Duration(minutes: 2)),
    leaseVerified: true,
  );

  static const ActiveRoomSession? noActiveSession = null;

  static final sessionRequiringRevalidation = _session(
    userId: 'preview-user-1',
    seatId: 'seat-2',
    leaseExpiresAt: nowUtc.add(const Duration(minutes: 2)),
    leaseVerified: false,
  );

  static final expiredSeatLeaseSession = _session(
    userId: 'preview-user-1',
    seatId: 'seat-3',
    leaseExpiresAt: nowUtc,
    leaseVerified: true,
  );

  static final otherUserActiveSession = _session(
    userId: 'preview-user-2',
    seatId: 'seat-4',
    leaseExpiresAt: nowUtc.add(const Duration(minutes: 2)),
    leaseVerified: true,
  );

  static ActiveRoomSession _session({
    required String userId,
    required String seatId,
    required DateTime leaseExpiresAt,
    required bool leaseVerified,
  }) => ActiveRoomSession(
    sessionId: 'session-demo-001',
    roomId: 'room-demo-001',
    subgroupId: 'subgroup-demo-001',
    roomTitle: 'Sensor Study Club',
    seatId: seatId,
    userId: userId,
    goalText: 'Review the sensor notes',
    isDemo: true,
    startsAt: nowUtc,
    focusEndsAt: nowUtc.add(const Duration(minutes: 25)),
    breakEndsAt: nowUtc.add(const Duration(minutes: 30)),
    participationSeat: SeatState(
      seatId: seatId,
      status: SeatStatus.occupied,
      userId: userId,
      claimedAt: nowUtc.subtract(const Duration(minutes: 1)),
      leaseExpiresAt: leaseExpiresAt,
    ),
    seatLeaseVerified: leaseVerified,
    nowUtc: nowUtc,
  );
}

/// Local stream fixture for UI and contract tests. Account changes invalidate
/// the old subscription before the next account can emit. It is not a source of
/// persistent restoration or cross-device synchronization.
final class FixtureActiveSessionRepository implements ActiveSessionRepository {
  FixtureActiveSessionRepository({
    required this._currentUserId,
    required Map<String, ActiveRoomSession?> sessionsByUser,
  }) : _sessionsByUser = Map.of(sessionsByUser);

  String? _currentUserId;
  final Map<String, ActiveRoomSession?> _sessionsByUser;
  final Map<String, Object> _failuresByUser = {};
  final Map<String, StreamController<void>> _updatesByUser = {};
  final StreamController<String?> _userChanges =
      StreamController<String?>.broadcast(sync: true);
  bool _disposed = false;

  @override
  Stream<ActiveRoomSession?> watchCurrentUserActiveSession() => Stream.multi((
    sink,
  ) {
    var generation = 0;
    StreamSubscription<ActiveRoomSession?>? sessionSubscription;
    StreamSubscription<String?>? userSubscription;
    var cancelled = false;

    void bind(String? userId) {
      final currentGeneration = ++generation;
      final previous = sessionSubscription;
      sessionSubscription = null;
      unawaited(() async {
        await previous?.cancel();
        if (cancelled || currentGeneration != generation) return;
        if (userId == null) {
          sink.add(null);
          return;
        }
        sessionSubscription = _watchUser(userId).listen(
          (session) {
            if (!cancelled && currentGeneration == generation) {
              sink.add(session);
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!cancelled && currentGeneration == generation) {
              sink.addError(error, stackTrace);
            }
          },
        );
      }());
    }

    bind(_currentUserId);
    userSubscription = _userChanges.stream.listen(bind, onError: sink.addError);
    sink.onCancel = () async {
      cancelled = true;
      generation++;
      await userSubscription?.cancel();
      await sessionSubscription?.cancel();
    };
  });

  /// Changes the identity observed by existing subscriptions; test fixture API.
  void switchUserForTest(String? userId) {
    _ensureOpen();
    _currentUserId = userId;
    _userChanges.add(userId);
  }

  /// Emits a new account-scoped fixture value.
  void setSessionForTest(String userId, ActiveRoomSession? session) {
    _ensureOpen();
    _sessionsByUser[userId] = session;
    _failuresByUser.remove(userId);
    _updatesByUser[userId]?.add(null);
  }

  /// Emits an account-scoped lookup failure for stream error tests.
  void failForTest(String userId, Object error) {
    _ensureOpen();
    _failuresByUser[userId] = error;
    _updatesByUser[userId]?.add(null);
  }

  Stream<ActiveRoomSession?> _watchUser(String userId) => Stream.multi((sink) {
    final updates = _updatesByUser.putIfAbsent(
      userId,
      () => StreamController<void>.broadcast(sync: true),
    );
    void emitCurrent() {
      final failure = _failuresByUser[userId];
      if (failure != null) {
        sink.addError(failure, StackTrace.current);
      } else {
        sink.add(_sessionsByUser[userId]);
      }
    }

    final subscription = updates.stream.listen((_) => emitCurrent());
    emitCurrent();
    sink.onCancel = subscription.cancel;
  });

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _userChanges.close();
    await Future.wait([
      for (final updates in _updatesByUser.values) updates.close(),
    ]);
  }

  void _ensureOpen() {
    if (_disposed) throw StateError('Active session fixture is disposed.');
  }
}
