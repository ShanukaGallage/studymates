import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_theme.dart';
import 'desk_illustration.dart';
import 'room_scene_models.dart';

// Presentation only: the caller supplies seat state and handles all actions.
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
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Natural card heights let names and controls wrap without shrinking text.
          final columns =
              constraints.maxWidth < 280 ||
                  MediaQuery.textScalerOf(context).scale(16) > 24
              ? 1
              : 2;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var start = 0; start < seats.length; start += columns) ...[
                if (start > 0) const SizedBox(height: AppSpacing.md),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var offset = 0; offset < columns; offset++) ...[
                        if (offset > 0) const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: start + offset >= seats.length
                              ? const SizedBox.shrink()
                              : _DeskCard(
                                  seat: seats[start + offset],
                                  selectionEnabled: selectionEnabled,
                                  onTap: () =>
                                      onSeatTap(seats[start + offset].number),
                                ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    ),
  );
}

class _DeskCard extends StatelessWidget {
  const _DeskCard({
    required this.seat,
    required this.selectionEnabled,
    required this.onTap,
  });
  final RoomSeat seat;
  final bool selectionEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final interactive = switch (seat.status) {
      RoomSeatStatus.available ||
      RoomSeatStatus.selected ||
      RoomSeatStatus.failed => true,
      _ => false,
    };
    final enabled = selectionEnabled && interactive;
    final active =
        seat.status == RoomSeatStatus.selected ||
        seat.status == RoomSeatStatus.yours;
    final failed = seat.status == RoomSeatStatus.failed;
    final accent = failed ? colors.error : colors.primary;
    final label = switch (seat.status) {
      RoomSeatStatus.available => 'Available',
      RoomSeatStatus.occupied => 'Occupied',
      RoomSeatStatus.selected => 'Selected',
      RoomSeatStatus.yours => 'Yours',
      RoomSeatStatus.pending => 'Pending',
      RoomSeatStatus.failed => 'Try again',
    };
    final action = switch (seat.status) {
      RoomSeatStatus.available => 'Take this seat',
      RoomSeatStatus.selected => 'Clear selection',
      RoomSeatStatus.failed => 'Retry selection',
      RoomSeatStatus.pending => 'Checking…',
      _ => seat.description,
    };
    final icon = switch (seat.status) {
      RoomSeatStatus.available => Icons.add,
      RoomSeatStatus.occupied => Icons.person_outline,
      RoomSeatStatus.selected => Icons.check,
      RoomSeatStatus.yours => Icons.verified_outlined,
      RoomSeatStatus.pending => Icons.hourglass_top,
      RoomSeatStatus.failed => Icons.refresh,
    };
    return Semantics(
      key: ValueKey('seat-${seat.number}'),
      label: 'Seat ${seat.number}, ${seat.description}',
      button: true,
      enabled: enabled,
      selected: active,
      liveRegion: seat.status == RoomSeatStatus.pending || failed,
      onTap: enabled ? onTap : null,
      child: ExcludeSemantics(
        child: Material(
          color: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: active || failed ? accent : colors.outlineVariant,
              width: active || failed ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      Text(
                        'Desk ${seat.number.toString().padLeft(2, '0')}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                DeskIllustration(avatarId: seat.occupant?.avatarId),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: seat.occupant != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              seat.occupant!.name,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              seat.status == RoomSeatStatus.yours
                                  ? seat.description
                                  : 'Study mate',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        )
                      : Container(
                          constraints: const BoxConstraints(minHeight: 48),
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: failed
                                ? colors.errorContainer
                                : colors.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: AppSpacing.xs,
                              children: [
                                Icon(icon, size: 18, color: accent),
                                Text(
                                  action,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
                if (seat.status == RoomSeatStatus.selected)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    child: Text(
                      'Local choice only',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
