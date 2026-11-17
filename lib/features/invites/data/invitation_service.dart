import '../../../core/models/community_models.dart';

enum InvitationPreviewStatus {
  ready,
  membershipRequired,
  fullRoom,
  invalid,
  expiredOrRevoked,
  unavailable,
}

enum InvitationAdmissionStatus {
  admitted,
  invalid,
  expiredOrRevoked,
  fullRoom,
  membershipRequired,
  hallSessionActive,
  unavailable,
}

/// Presentation data returned by a successful or membership-gated preview.
/// It is descriptive only and never reserves a room seat.
final class InvitationPreview {
  const InvitationPreview({
    required this.room,
    required this.sig,
    required this.subgroup,
  });

  final RoomSummary room;
  final SigSummary sig;
  final SubgroupSummary subgroup;
}

final class InvitationPreviewResult {
  const InvitationPreviewResult({required this.status, this.preview});

  final InvitationPreviewStatus status;
  final InvitationPreview? preview;
}

final class InvitationAdmissionResult {
  const InvitationAdmissionResult(this.status);

  final InvitationAdmissionStatus status;
}

abstract interface class InvitationService {
  /// Looks up an opaque token without reserving a seat or changing membership.
  Future<InvitationPreviewResult> resolveInvitation(String opaqueToken);

  /// Attempts admission after the user explicitly chooses Join.
  ///
  /// Consent is not proof of membership and must never enroll the user by itself.
  /// Implementations revalidate invitation state, membership, and room capacity.
  Future<InvitationAdmissionResult> admitInvitation({
    required String opaqueToken,
    required bool membershipConsentGranted,
  });
}
