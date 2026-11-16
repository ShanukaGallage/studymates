import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_mode.dart';
import '../../../../core/models/community_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../rooms/data/room_providers.dart';
import '../../../study/data/firestore_study_repository.dart';
import '../../../study/data/study_providers.dart';
import '../../../study/presentation/room_creation_error.dart';
import '../../../study/presentation/study_dialogs.dart';

/// The same room list/creation path for inline browsing and subgroup deep links.
class SubgroupStudyRooms extends ConsumerStatefulWidget {
  const SubgroupStudyRooms({
    super.key,
    required this.subgroupId,
    required this.canCreate,
  });
  final String subgroupId;
  final bool canCreate;

  @override
  ConsumerState<SubgroupStudyRooms> createState() => _SubgroupStudyRoomsState();
}

class _SubgroupStudyRoomsState extends ConsumerState<SubgroupStudyRooms> {
  bool _creating = false;
  bool _saving = false;

  Future<void> _create() async {
    if (_creating || !widget.canCreate) return;
    setState(() => _creating = true);
    try {
      final options = await studyRoomDialog(context);
      if (options == null || !mounted) return;
      setState(() => _saving = true);
      final room = await ref
          .read(studyRepositoryProvider)
          .createRoom(
            subgroupId: widget.subgroupId,
            title: options.title,
            capacity: options.capacity,
            isPrivate: options.isPrivate,
          );
      if (!mounted) return;
      ref.invalidate(connectedRoomSummariesProvider(widget.subgroupId));
      context.pushNamed(
        'room-preview',
        pathParameters: {'roomId': room.roomId},
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(roomCreationError(error))));
      }
    } finally {
      if (mounted) {
        setState(() {
          _creating = false;
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = ref.watch(appModeProvider) == AppMode.preview;
    final rooms = ref.watch(
      preview
          ? subgroupRoomsProvider(widget.subgroupId)
          : connectedRoomSummariesProvider(widget.subgroupId),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final heading = Text(
              'Study rooms',
              style: Theme.of(context).textTheme.titleMedium,
            );
            final action = FilledButton.icon(
              key: ValueKey('create-room-${widget.subgroupId}'),
              onPressed: _creating ? null : _create,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add, size: 20),
              style: FilledButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              label: const Text('Create room'),
            );
            if (!widget.canCreate || preview) return heading;
            if (constraints.maxWidth < 280 ||
                MediaQuery.textScalerOf(context).scale(16) > 22) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [heading, const SizedBox(height: 8), action],
              );
            }
            return Row(
              children: [
                Expanded(child: heading),
                const SizedBox(width: 8),
                action,
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Open a room to see live seats and claim one.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColors.secondaryText),
        ),
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 12),
        rooms.when(
          skipLoadingOnRefresh: false,
          skipLoadingOnReload: false,
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: LoadingView(message: 'Loading rooms…'),
          ),
          error: (_, _) => ErrorView(
            message: 'Rooms are unavailable. Try again.',
            onRetry: () => preview
                ? ref.invalidate(subgroupRoomsProvider(widget.subgroupId))
                : ref.invalidate(
                    connectedRoomSummariesProvider(widget.subgroupId),
                  ),
          ),
          data: (rooms) => rooms.isEmpty
              ? EmptyView(
                  title: 'No rooms yet',
                  message: preview
                      ? 'No sample rooms in this subgroup.'
                      : widget.canCreate
                      ? 'Create a room to study together.'
                      : 'Rooms will appear here when members create them.',
                )
              : Column(
                  children: [
                    for (var index = 0; index < rooms.length; index++) ...[
                      if (index > 0) const SizedBox(height: 8),
                      _RoomRow(room: rooms[index]),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _RoomRow extends StatelessWidget {
  const _RoomRow({required this.room});
  final RoomSummary room;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: AppColors.primary.withValues(alpha: .2)),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      key: ValueKey('room-row-${room.id}'),
      onTap: () => context.pushNamed(
        'room-preview',
        pathParameters: {'roomId': room.id},
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.chair_alt_outlined,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${room.capacity} desks',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (room.isPrivate) ...[
                    const SizedBox(height: 4),
                    const Row(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 16,
                          color: AppColors.secondaryText,
                        ),
                        SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Private · invitation required',
                            style: TextStyle(color: AppColors.secondaryText),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: AppColors.secondaryText),
          ],
        ),
      ),
    ),
  );
}
