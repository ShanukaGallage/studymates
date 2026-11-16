import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/models/completion_record.dart';
import '../../../core/models/active_room_session.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../progress/presentation/controllers/progress_history_controller.dart';
import '../../sessions/data/active_session_providers.dart';
import '../../sessions/data/session_timing.dart';
import '../../sessions/presentation/widgets/session_views.dart';
import '../data/firestore_study_repository.dart';

class LiveSessionScreen extends ConsumerStatefulWidget {
  const LiveSessionScreen({super.key});
  @override
  ConsumerState<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

class _LiveSessionScreenState extends ConsumerState<LiveSessionScreen> {
  Timer? _tick;
  bool _busy = false, _goalDone = false;
  String? _error;
  CompletionRecord? _result;
  String? _sessionId;
  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End and save participation?'),
        content: const Text(
          'Only eligible focus time is saved. A lost or expired lease receives zero credit. Demo sessions remain separate.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep studying'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End and save'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(studyRepositoryProvider)
          .finishSession(
            _goalDone ? GoalOutcome.completed : GoalOutcome.unfinished,
            expectedSessionId: _sessionId,
          );
      if (mounted) {
        setState(() => _result = result);
        ref.invalidate(progressHistoryProvider);
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is StudyFailure ? error.message : 'Save could not be confirmed. Retry, or check Progress before starting another cycle.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(currentUserActiveSessionProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study session'),
        leading: IconButton(
          tooltip: 'Return Home; session remains active',
          icon: const Icon(Icons.arrow_back),
          onPressed: _busy ? null : () => context.go('/home'),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_result != null) ...[
              Text(
                'Participation saved',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                _result!.isDemo
                    ? 'DEMO • excluded from normal progress'
                    : 'Normal study record',
              ),
              Text(
                'Credited focus time: ${sessionDuration(_result!.creditedSeconds)}',
              ),
              Text(_result!.goalText),
              Text('Goal: ${_result!.goalOutcome.name}'),
              Text('Timer: ${_result!.timerStatus.name}'),
              AppButton(
                label: 'View Progress',
                onPressed: () => context.go('/progress'),
              ),
              AppButton(
                label: 'Return Home',
                variant: AppButtonVariant.secondary,
                onPressed: () => context.go('/home'),
              ),
            ] else ...[
              active.when(
                loading: () =>
                    const LoadingView(message: 'Loading saved session…'),
                error: (_, _) => ErrorView(
                  message: 'Session connection unavailable.',
                  onRetry: () =>
                      ref.invalidate(activeSessionRepositoryProvider),
                ),
                data: (session) {
                  if (session == null) {
                    return const Text(
                      'No active session. Check Progress for a saved completion.',
                    );
                  }
                  _sessionId = session.sessionId;
                  final timing = calculateSessionTiming(
                    nowUtc: DateTime.now().toUtc(),
                    startsAt: session.startsAt,
                    focusEndsAt: session.focusEndsAt,
                    breakEndsAt: session.breakEndsAt,
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (session.isDemo)
                        const Text(
                          '60-SECOND DEMO • excluded from normal totals',
                        ),
                      if (session.participationStatus ==
                          ParticipationStatus.requiresRevalidation)
                        const Text(
                          'Connection or seat eligibility is unverified. Use Check seat and connection before continuing.',
                        ),
                      if (timing is SessionTiming)
                        SessionView(
                          roomTitle: session.roomTitle,
                          seat:
                              int.tryParse(session.seatId.split('-').last) ?? 0,
                          goal: session.goalText,
                          timing: timing,
                          elapsedSeconds: DateTime.now()
                              .toUtc()
                              .difference(session.startsAt)
                              .inSeconds
                              .clamp(0, 100000),
                        ),
                      const SizedBox(height: 12),
                      const Text(
                        'The shared schedule continues while away. Returning requires a fresh membership and seat check.',
                      ),
                    ],
                  );
                },
              ),
              SwitchListTile(
                title: const Text('I completed my goal'),
                value: _goalDone,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _goalDone = value),
              ),
              if (_error != null)
                Semantics(liveRegion: true, child: Text(_error!)),
              AppButton(
                label: _error == null
                    ? 'End and save participation'
                    : 'Retry save',
                isLoading: _busy,
                onPressed: active.asData?.value == null ? null : _finish,
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'Check seat and connection',
                variant: AppButtonVariant.secondary,
                onPressed: _busy
                    ? null
                    : () async {
                        try {
                          await ref
                              .read(studyRepositoryProvider)
                              .revalidateSession();
                          if (mounted) {
                            setState(
                              () => _error = 'Membership and seat verified.',
                            );
                          }
                        } catch (error) {
                          if (mounted) {
                            setState(
                              () => _error = error is StudyFailure
                                  ? error.message
                                  : 'Connection unavailable. Retry when online.',
                            );
                          }
                        }
                      },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
