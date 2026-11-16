import 'package:material_ui/material_ui.dart';

// Original vector artwork adapted from docs/design/room-classroom.html.
// Names, statuses and hit targets remain in RoomScene, outside the painted art.
class DeskIllustration extends StatelessWidget {
  const DeskIllustration({super.key, this.avatarId});
  final String? avatarId;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AspectRatio(
      aspectRatio: 180 / 126,
      child: CustomPaint(painter: _DeskPainter(avatarId)),
    ),
  );
}

class _DeskPainter extends CustomPainter {
  const _DeskPainter(this.avatarId);
  final String? avatarId;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 180, size.height / 126);
    final paint = Paint();
    void shape(Path path, Color color) => canvas.drawPath(
      path,
      paint
        ..style = PaintingStyle.fill
        ..color = color,
    );
    void box(
      double x,
      double y,
      double w,
      double h,
      Color color, [
      double radius = 0,
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w, h),
          Radius.circular(radius),
        ),
        paint
          ..style = PaintingStyle.fill
          ..color = color,
      );
    }

    void line(Offset a, Offset b, Color color, double width) => canvas.drawLine(
      a,
      b,
      paint
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = width
        ..color = color,
    );
    void oval(Rect rect, Color color) => canvas.drawOval(
      rect,
      paint
        ..style = PaintingStyle.fill
        ..color = color,
    );
    const hair = Color(0xFF493A31);
    const skin = Color(0xFFEDC39D);
    const wood = Color(0xFFB08B5E);
    box(0, 0, 180, 126, const Color(0xFFFAF5E9));
    box(14, 16, 26, 23, const Color(0xFFE4EDDC), 2);
    line(const Offset(27, 17), const Offset(27, 38), Colors.white, 2);
    line(const Offset(15, 27), const Offset(39, 27), Colors.white, 2);
    line(
      const Offset(141, 17),
      const Offset(166, 17),
      const Color(0xFFE6DDCC),
      3,
    );
    if (avatarId == null) {
      box(65, 43, 48, 58, const Color(0xFFC2B49A), 14);
      box(67, 45, 44, 54, const Color(0xFFE0D7C4), 12);
      line(const Offset(73, 95), const Offset(69, 126), wood, 5);
      line(const Offset(105, 95), const Offset(109, 126), wood, 5);
    } else {
      // Stable preset appearance; unknown IDs retain a deterministic fallback.
      final variant =
          avatarId!.codeUnits.fold(0, (sum, unit) => sum + unit) % 3;
      final shirt = avatarId == 'amber'
          ? const Color(0xFFC67650)
          : avatarId == 'mint'
          ? const Color(0xFF658A73)
          : const [
              Color(0xFF7797B4),
              Color(0xFF8B809F),
              Color(0xFFB18A56),
            ][variant];
      if (variant == 1) {
        shape(
          Path()
            ..moveTo(62, 53)
            ..quadraticBezierTo(56, 4, 89, 8)
            ..quadraticBezierTo(124, 6, 122, 56)
            ..lineTo(128, 99)
            ..lineTo(58, 99)
            ..close(),
          hair,
        );
      } else if (variant == 2) {
        oval(const Rect.fromLTWH(51, 12, 27, 27), hair);
        oval(const Rect.fromLTWH(100, 12, 27, 27), hair);
      }
      shape(
        Path()
          ..moveTo(52, 108)
          ..quadraticBezierTo(54, 64, 77, 65)
          ..lineTo(102, 65)
          ..quadraticBezierTo(128, 68, 129, 108)
          ..close(),
        shirt,
      );
      shape(
        Path()
          ..moveTo(80, 60)
          ..lineTo(80, 73)
          ..quadraticBezierTo(90, 81, 99, 73)
          ..lineTo(99, 60)
          ..close(),
        const Color(0xFFD8A67E),
      );
      oval(const Rect.fromLTWH(62, 10, 54, 60), skin);
      shape(
        Path()
          ..moveTo(62, 40)
          ..quadraticBezierTo(54, 4, 88, 8)
          ..quadraticBezierTo(121, 4, 118, 42)
          ..lineTo(108, 32)
          ..lineTo(105, 22)
          ..quadraticBezierTo(88, 38, 65, 29)
          ..close(),
        hair,
      );
      line(const Offset(77, 46), const Offset(81, 47), hair, 2.5);
      line(const Offset(97, 47), const Offset(101, 46), hair, 2.5);
      canvas.drawPath(
        Path()
          ..moveTo(85, 56)
          ..quadraticBezierTo(89, 59, 94, 56),
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFA1684F),
      );
      for (final arm in [
        Path()
          ..moveTo(63, 84)
          ..quadraticBezierTo(70, 94, 86, 100),
        Path()
          ..moveTo(115, 84)
          ..quadraticBezierTo(108, 95, 94, 100),
      ]) {
        canvas.drawPath(
          arm,
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = 12
            ..strokeCap = StrokeCap.round
            ..color = skin,
        );
      }
      line(
        const Offset(103, 84),
        const Offset(91, 104),
        const Color(0xFF375D43),
        3,
      );
    }
    box(13, 109, 154, 12, wood, 3);
    line(
      const Offset(22, 121),
      const Offset(22, 126),
      const Color(0xFF9B7851),
      6,
    );
    line(
      const Offset(158, 121),
      const Offset(158, 126),
      const Color(0xFF9B7851),
      6,
    );
    box(10, 104, 160, 9, const Color(0xFFCFAD7C), 3);
    final book = Path()
      ..moveTo(65, 99)
      ..lineTo(87, 96)
      ..lineTo(110, 99)
      ..lineTo(108, 109)
      ..lineTo(87, 106)
      ..lineTo(66, 109)
      ..close();
    shape(book, const Color(0xFFFFFDF4));
    canvas.drawPath(
      book,
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFFBAAF95),
    );
    line(
      const Offset(87, 97),
      const Offset(87, 106),
      const Color(0xFFBAAF95),
      1,
    );
    for (var i = 0; i < 3; i++) {
      line(
        Offset(139, 97 - i * 5),
        Offset(162, 97 - i * 5),
        const Color(0xFF667D5D),
        3,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DeskPainter oldDelegate) =>
      avatarId != oldDelegate.avatarId;
}
