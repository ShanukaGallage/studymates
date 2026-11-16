import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../sessions/data/active_session_providers.dart';
import '../data/firestore_study_repository.dart';
import '../data/study_providers.dart';

/// Makes the one-seat rule recoverable without silently ending participation.
class SeatRecoveryCard extends ConsumerStatefulWidget {
  const SeatRecoveryCard({super.key, required this.roomId});
  final String roomId;
  @override
  ConsumerState<SeatRecoveryCard> createState() => _SeatRecoveryState();
}

class _SeatRecoveryState extends ConsumerState<SeatRecoveryCard> {
  bool _busy = false;
  String? _error;

  Future<void> _release(Map<String, dynamic> claim) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Release your reserved seat?'),
        content: const Text(
          'Your old desk becomes available to other learners. You can then choose a desk here. Any unfinished session must be saved first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep seat'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Release seat'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(studyRepositoryProvider)
          .releaseRoomSeat(
            subgroup: claim['subgroupId'],
            room: claim['roomId'],
            seat: claim['seatId'],
            claimId: claim['claimId'],
          );
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is StudyFailure ? error.message : 'Release could not be confirmed. Check your connection and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final claim = ref.watch(ownSeatClaimProvider).asData?.value;
    final active = ref.watch(currentUserActiveSessionProvider);
    final session = active.asData?.value;
    if (claim == null && session == null) return const SizedBox.shrink();
    if (session?.roomId == widget.roomId) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: AppButton(
          label: 'Return to session',
          onPressed: () => context.push('/session'),
        ),
      );
    }
    if (session == null && claim?['roomId'] == widget.roomId) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              session != null
                  ? 'Finish your previous session'
                  : 'You’re seated in another room',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              session != null
                  ? 'Save your session before taking a new desk.'
                  : 'Desk ${claim!['seatId'].toString().split('-').last} is reserved for you ${claim['roomId'] == widget.roomId ? 'in this room' : 'in another room'}. Release it to switch rooms.',
            ),
            const SizedBox(height: 12),
            if (session != null)
              AppButton(
                label: 'Return to unfinished session',
                onPressed: () => context.push('/session'),
              ),
            if (claim != null && claim['roomId'] != widget.roomId)
              AppButton(
                label: 'Open my reserved room',
                variant: AppButtonVariant.secondary,
                onPressed: () => context.push('/rooms/${claim['roomId']}'),
              ),
            if (claim != null && session == null)
              AppButton(
                label: 'Release reserved seat',
                variant: AppButtonVariant.secondary,
                isLoading: _busy,
                onPressed: active.isLoading || active.hasError
                    ? null
                    : () => _release(claim),
              ),
            if (_error != null)
              Semantics(liveRegion: true, child: Text(_error!)),
          ],
        ),
      ),
    );
  }
}
