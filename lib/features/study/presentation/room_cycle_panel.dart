import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../sessions/presentation/widgets/cycle_timer_card.dart';
import '../data/firestore_study_repository.dart';
import '../data/room_cycle_repository.dart';

final roomCyclesProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, (String, String)>(
      (ref, room) =>
          ref.watch(studyRepositoryProvider).watchRoomCycles(room.$1, room.$2),
    );

class RoomCyclePanel extends ConsumerWidget {
  const RoomCyclePanel({
    super.key,
    required this.subgroup,
    required this.room,
    required this.sessionId,
  });
  final String subgroup, room;
  final String? sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(roomCyclesProvider((subgroup, room)))
      .when(
        loading: () => const LoadingView(message: 'Loading room cycles…'),
        error: (_, _) => ErrorView(
          message: 'Room cycle updates unavailable.',
          onRetry: () => ref.invalidate(roomCyclesProvider((subgroup, room))),
        ),
        data: (cycles) {
          final now = DateTime.now().toUtc();
          final current = cycles
              .where((s) => s['sessionId'] == sessionId)
              .firstOrNull;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                child: Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  children: [
                    Text(
                      '${completedRoomCycles(cycles, now)} cycles done',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (completedRoomCycles(cycles, now, demo: true) > 0)
                      Text(
                        '${completedRoomCycles(cycles, now, demo: true)} demo cycles',
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (cycles.any((c) => c['cached'] == true))
                const Text('Cached cycle data · connection unverified'),
              if (current == null)
                const AppCard(
                  child: Text('Ready to focus?\n25 min focus · 5 min break'),
                )
              else if (current['startsAt'] is! Timestamp)
                const LoadingView(message: 'Confirming shared cycle start…')
              else
                CycleTimerCard(
                  startsAt: time(current['startsAt']),
                  isDemo: current['isDemo'] == true,
                  now: now,
                ),
              const SizedBox(height: 16),
            ],
          );
        },
      );
}
