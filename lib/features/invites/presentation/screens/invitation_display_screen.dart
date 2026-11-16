import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/invitation_token.dart';
import '../widgets/share_invitation_button.dart';

/// Displays an already-issued token; never issues or authorizes an invitation.
class InvitationDisplayScreen extends StatelessWidget {
  const InvitationDisplayScreen({
    super.key,
    required this.opaqueToken,
    required this.roomTitle,
    this.isFixture = false,
    this.management,
  });
  final String opaqueToken;
  final String roomTitle;
  final bool isFixture;
  final Widget? management;

  String? get qrPayload => InvitationTokenParser.isOpaqueToken(opaqueToken)
      ? 'studymates://invite/v1/$opaqueToken'
      : null;

  @override
  Widget build(BuildContext context) {
    final payload = qrPayload;
    final valid = payload != null;
    final code = valid
        ? List.generate(
            4,
            (i) => opaqueToken.substring(i * 4, i * 4 + 4),
          ).join('-')
        : '';
    return Scaffold(
      appBar: AppBar(title: const Text('Room invitation')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            if (isFixture)
              const Text(
                'Fixture preview only. This is not a live room invitation.',
              ),
            Text(roomTitle, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.lg),
            if (!valid)
              const Text(
                'Invitation code is invalid. Ask the host for a new invitation.',
              )
            else ...[
              const Text(
                'Scan this QR or enter the code below. The learner will review the room before choosing Join.',
              ),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: QrImageView(
                      data: payload,
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.all(24),
                      semanticsLabel: 'Room invitation QR. A manual code is provided below.',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text('Manual invitation code'),
              SelectableText(
                code,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (!isFixture) ...[
                const SizedBox(height: AppSpacing.lg),
                ShareInvitationButton(roomTitle: roomTitle, code: code),
                ?management,
              ],
            ],
          ],
        ),
      ),
    );
  }
}
