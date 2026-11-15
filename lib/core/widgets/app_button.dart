import 'package:material_ui/material_ui.dart';

enum AppButtonVariant { primary, secondary }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final content = isLoading
        ? Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              Text('$label…'),
            ],
          )
        : Text(label, textAlign: TextAlign.center);
    final callback = isLoading ? null : onPressed;
    return variant == AppButtonVariant.primary
        ? FilledButton(onPressed: callback, child: content)
        : OutlinedButton(onPressed: callback, child: content);
  }
}
