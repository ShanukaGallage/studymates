import 'package:material_ui/material_ui.dart';

import '../core/theme/app_theme.dart';

/// Branded first Flutter frame, shown only while real startup is pending.
class StartupSplash extends StatelessWidget {
  const StartupSplash({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.background,
            AppColors.softAccent,
            AppColors.blueAccent,
          ],
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 48).clamp(
                  0,
                  double.infinity,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 550),
                    builder: (_, value, child) => Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 12 * (1 - value)),
                        child: child,
                      ),
                    ),
                    child: const SizedBox(
                      width: 240,
                      height: 240,
                      child: ExcludeSemantics(
                        child: CustomPaint(painter: _StudyMark()),
                      ),
                    ),
                  ),
                  Text(
                    'StudyMates',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: AppColors.text,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Find your people.\nMake room for focus.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 18,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 40),
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      semanticsLabel: 'Starting StudyMates',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Getting your study space ready…',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.secondaryText),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _StudyMark extends CustomPainter {
  const _StudyMark();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 288, size.height / 288);
    canvas.drawCircle(
      const Offset(144, 144),
      100,
      Paint()..color = AppColors.surface.withValues(alpha: .5),
    );
    canvas.drawCircle(
      const Offset(144, 144),
      80,
      Paint()..color = AppColors.primary,
    );
    final book = Path()
      ..moveTo(144, 136)
      ..quadraticBezierTo(118, 119, 94, 126)
      ..lineTo(94, 178)
      ..quadraticBezierTo(119, 171, 144, 190)
      ..quadraticBezierTo(169, 171, 194, 178)
      ..lineTo(194, 126)
      ..quadraticBezierTo(170, 119, 144, 136)
      ..close();
    canvas.drawPath(book, Paint()..color = AppColors.surface);
    final lines = Path()
      ..moveTo(144, 139)
      ..lineTo(144, 180)
      ..moveTo(107, 140)
      ..quadraticBezierTo(122, 139, 132, 146)
      ..moveTo(107, 153)
      ..quadraticBezierTo(122, 152, 132, 159)
      ..moveTo(156, 146)
      ..quadraticBezierTo(167, 139, 181, 140)
      ..moveTo(156, 159)
      ..quadraticBezierTo(167, 152, 181, 153);
    canvas.drawPath(
      lines,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      const Offset(120, 108),
      11,
      Paint()..color = AppColors.mintAccent,
    );
    canvas.drawCircle(
      const Offset(164, 102),
      11,
      Paint()..color = AppColors.mintAccent,
    );
    final spark = Path()
      ..moveTo(200, 80)
      ..lineTo(203, 88)
      ..lineTo(211, 91)
      ..lineTo(203, 94)
      ..lineTo(200, 102)
      ..lineTo(197, 94)
      ..lineTo(189, 91)
      ..lineTo(197, 88)
      ..close();
    canvas.drawPath(spark, Paint()..color = AppColors.blueAccent);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StudyMark oldDelegate) => false;
}
