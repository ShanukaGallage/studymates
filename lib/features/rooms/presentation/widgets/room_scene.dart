import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_theme.dart';
import 'room_scene_models.dart';

// Desk centers in the painted room's coordinate system. Background, avatars and
// touch targets all use this same aspect-ratio-preserving coordinate space.
const roomSeatCenters = [
  Offset(.20, .43),
  Offset(.50, .43),
  Offset(.80, .43),
  Offset(.20, .77),
  Offset(.50, .77),
  Offset(.80, .77),
];

class RoomScene extends StatelessWidget {
  const RoomScene({
    super.key,
    required this.seats,
    required this.onSeatTap,
    this.selectionEnabled = true,
  });
  final List<RoomSeat> seats;
  final ValueChanged<int> onSeatTap;
  final bool selectionEnabled;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      LayoutBuilder(
        builder: (context, constraints) {
          // Keep targets at least 48px even in unusually narrow split-screen views.
          final width = constraints.maxWidth < 280
              ? 280.0
              : constraints.maxWidth;
          final height = width / 1.12;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              height: height,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(painter: _RoomPainter()),
                    ),
                    for (final seat in seats)
                      Positioned(
                        left: roomSeatCenters[seat.number - 1].dx * width - 28,
                        top: roomSeatCenters[seat.number - 1].dy * height - 38,
                        width: 56,
                        height: 56,
                        child: _SceneSeat(
                          seat: seat,
                          enabled:
                              selectionEnabled &&
                              seat.status != RoomSeatStatus.occupied &&
                              seat.status != RoomSeatStatus.pending &&
                              seat.status != RoomSeatStatus.yours,
                          onTap: () => onSeatTap(seat.number),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      const SizedBox(height: AppSpacing.lg),
      // Scalable names/status text sits outside the fixed scene geometry.
      for (final seat in seats)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Text('Seat ${seat.number} · ${seat.description}'),
        ),
    ],
  );
}

class _SceneSeat extends StatelessWidget {
  const _SceneSeat({
    required this.seat,
    required this.enabled,
    required this.onTap,
  });
  final RoomSeat seat;
  final bool enabled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final active =
        seat.status == RoomSeatStatus.selected ||
        seat.status == RoomSeatStatus.yours;
    final failed = seat.status == RoomSeatStatus.failed;
    final foreground = failed
        ? colors.error
        : active
        ? colors.onPrimary
        : colors.primary;
    final icon = switch (seat.status) {
      RoomSeatStatus.available => Icons.add,
      RoomSeatStatus.occupied => Icons.person,
      RoomSeatStatus.selected => Icons.check,
      RoomSeatStatus.yours => Icons.person_pin,
      RoomSeatStatus.pending => Icons.hourglass_top,
      RoomSeatStatus.failed => Icons.refresh,
    };
    return Semantics(
      key: ValueKey('seat-${seat.number}'),
      label: 'Seat ${seat.number}, ${seat.description}',
      button: true,
      enabled: enabled,
      selected: active,
      onTap: enabled ? onTap : null,
      child: ExcludeSemantics(
        child: Tooltip(
          message: 'Seat ${seat.number}: ${seat.description}',
          child: Material(
            color: active ? colors.primary : colors.surface,
            shape: CircleBorder(
              side: BorderSide(
                color: failed ? colors.error : colors.primary,
                width: active || failed ? 3 : 1.5,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled ? onTap : null,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (seat.occupant != null)
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: _Avatar(avatarId: seat.occupant!.avatarId),
                      ),
                    ),
                  if (seat.occupant == null)
                    Icon(icon, color: foreground, size: 26),
                  if (seat.status == RoomSeatStatus.yours)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check,
                          size: 16,
                          color: colors.onPrimary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Avatar is independent of the background/desk layer and contains no baked text.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.avatarId});
  final String avatarId;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: avatarId == 'amber'
          ? const Color(0xFFF4DEAA)
          : AppColors.softAccent,
    ),
    child: const Icon(Icons.person, color: AppColors.primary, size: 32),
  );
}

class _RoomPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final paint = Paint();
    canvas.drawRect(Offset.zero & size, paint..color = const Color(0xFFF0E8D7));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h * .24),
      paint..color = AppColors.softAccent,
    );
    // Window and shelf: static room scenery only.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * .37, h * .04, w * .26, h * .14),
        const Radius.circular(8),
      ),
      paint..color = const Color(0xFFFBFCF6),
    );
    canvas.drawLine(
      Offset(w * .50, h * .04),
      Offset(w * .50, h * .18),
      paint
        ..color = AppColors.primary
        ..strokeWidth = 2,
    );
    canvas.drawLine(Offset(w * .37, h * .11), Offset(w * .63, h * .11), paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * .06, h * .10, w * .19, h * .06),
        const Radius.circular(4),
      ),
      paint..color = const Color(0xFFBDA882),
    );
    canvas.drawCircle(
      Offset(w * .86, h * .12),
      w * .035,
      paint..color = AppColors.primary,
    );
    canvas.drawRect(
      Rect.fromLTWH(w * .84, h * .15, w * .04, h * .04),
      paint..color = const Color(0xFFBDA882),
    );
    // A shared rug anchors the six independent desk and avatar layers.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * .06, h * .28, w * .88, h * .64),
        const Radius.circular(18),
      ),
      paint..color = const Color(0xFFE5DDC9),
    );
    for (final center in roomSeatCenters) {
      final x = center.dx * w, y = center.dy * h;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, y + 13),
            width: w * .23,
            height: h * .12,
          ),
          const Radius.circular(6),
        ),
        paint..color = const Color(0xFFB29B74),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, y + 8),
            width: w * .23,
            height: h * .12,
          ),
          const Radius.circular(6),
        ),
        paint..color = const Color(0xFFFAF7F0),
      );
      canvas.drawLine(
        Offset(x - w * .06, y + 10),
        Offset(x + w * .06, y + 10),
        paint
          ..color = const Color(0xFFBDA882)
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RoomPainter oldDelegate) => false;
}
