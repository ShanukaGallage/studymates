import 'room_models.dart';
import '../../features/sessions/data/session_timing.dart';

enum ParticipationStatus { valid, requiresRevalidation }

/// Current user's view of a shared session schedule.
///
/// [participationSeat] and [seatLeaseVerified] are evidence supplied by the
/// repository, not persisted session fields. A lease is valid only while it is
/// confirmed and its expiry is strictly later than [nowUtc].
final class ActiveRoomSession {
  ActiveRoomSession({
    required String sessionId,
    required String roomId,
    required String subgroupId,
    required String roomTitle,
    required String seatId,
    required String userId,
    required String goalText,
    required this.isDemo,
    required DateTime startsAt,
    required DateTime focusEndsAt,
    required DateTime breakEndsAt,
    required SeatState participationSeat,
    required bool seatLeaseVerified,
    required DateTime nowUtc,
  }) : sessionId = _required(sessionId, 'sessionId'),
       roomId = _required(roomId, 'roomId'),
       subgroupId = _required(subgroupId, 'subgroupId'),
       roomTitle = _required(roomTitle, 'roomTitle'),
       seatId = _required(seatId, 'seatId'),
       userId = _required(userId, 'userId'),
       goalText = _required(goalText, 'goalText'),
       startsAt = startsAt.toUtc(),
       focusEndsAt = focusEndsAt.toUtc(),
       breakEndsAt = breakEndsAt.toUtc(),
       participationStatus = _participationStatus(
         seat: participationSeat,
         expectedSeatId: seatId,
         expectedUserId: userId,
         seatLeaseVerified: seatLeaseVerified,
         nowUtc: nowUtc,
       ) {
    final timing = calculateSessionTiming(
      nowUtc: this.startsAt,
      startsAt: this.startsAt,
      focusEndsAt: this.focusEndsAt,
      breakEndsAt: this.breakEndsAt,
    );
    if (timing is InvalidSessionTiming) {
      throw ArgumentError('Session timestamps must be strictly ordered.');
    }
  }

  final String sessionId;
  final String roomId;
  final String subgroupId;
  final String roomTitle;
  final String seatId;
  final String userId;
  final String goalText;
  final bool isDemo;
  final DateTime startsAt;
  final DateTime focusEndsAt;
  final DateTime breakEndsAt;
  final ParticipationStatus participationStatus;

  static String _required(String value, String name) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, name, 'Must not be empty.');
    }
    return value;
  }

  static ParticipationStatus _participationStatus({
    required SeatState seat,
    required String expectedSeatId,
    required String expectedUserId,
    required bool seatLeaseVerified,
    required DateTime nowUtc,
  }) {
    final expiry = seat.leaseExpiresAt;
    if (seatLeaseVerified &&
        seat.seatId == expectedSeatId &&
        seat.status == SeatStatus.occupied &&
        seat.userId == expectedUserId &&
        expiry != null &&
        expiry.toUtc().isAfter(nowUtc.toUtc())) {
      return ParticipationStatus.valid;
    }
    return ParticipationStatus.requiresRevalidation;
  }
}
