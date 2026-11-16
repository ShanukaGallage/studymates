import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/widgets/app_button.dart';

class ShareInvitationButton extends StatefulWidget {
  const ShareInvitationButton({
    super.key,
    required this.roomTitle,
    required this.code,
  });

  final String roomTitle;
  final String code;

  @override
  State<ShareInvitationButton> createState() => _ShareInvitationButtonState();
}

class _ShareInvitationButtonState extends State<ShareInvitationButton> {
  bool _sharing = false;

  Future<void> _share() async {
    if (_sharing) return;
    final box = context.findRenderObject() as RenderBox?;
    setState(() => _sharing = true);
    try {
      await SharePlus.instance.share(
        ShareParams(
          title: 'StudyMates room invitation',
          text:
              'Join my StudyMates room: ${widget.roomTitle}\n'
              'Invitation code: ${widget.code}\n'
              'Open StudyMates → Scan invitation → enter the code manually. '
              'Community membership and an available desk are required.',
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open sharing. Select and copy the code instead.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppButton(
    label: 'Share invitation',
    isLoading: _sharing,
    onPressed: _share,
  );
}
