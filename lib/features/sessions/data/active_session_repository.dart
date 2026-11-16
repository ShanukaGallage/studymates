import '../../../core/models/active_room_session.dart';

/// Account-scoped active-session observation contract.
///
/// A `null` event confirms that the authenticated user has no active session.
/// A stream error means the lookup failed. Implementations must scope reads to
/// the current authenticated UID, cancel/rebind on account changes, and never
/// emit a former account's session after that identity changes.
abstract interface class ActiveSessionRepository {
  Stream<ActiveRoomSession?> watchCurrentUserActiveSession();
}