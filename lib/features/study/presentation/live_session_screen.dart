import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/models/completion_record.dart';
import '../../../core/models/active_room_session.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_details.dart';
import '../../../core/widgets/state_views.dart';
import '../../progress/presentation/controllers/progress_history_controller.dart';
import '../../sessions/data/active_session_providers.dart';
import '../../sessions/presentation/widgets/session_views.dart';
import '../../sessions/presentation/widgets/cycle_timer_card.dart';
import '../../sessions/presentation/widgets/keep_awake_control.dart';
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
        title: const Text('Finish this session?'),
        content: const Text(
          'Save your eligible focus time to Progress. Expired seats receive no credit; demo time stays separate.',
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
        child: AppContentWidth(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_result != null) ...[
                Text(
                  'Session saved',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  _result!.isDemo
                      ? 'DEMO • excluded from normal progress'
                      : 'Saved to Progress',
                ),
                Text(
                  'Credited focus time: ${sessionDuration(_result!.creditedSeconds)}',
                ),
                Text(_result!.goalText),
                Text(
                  _result!.goalOutcome == GoalOutcome.completed
                      ? 'Goal completed'
                      : 'Goal unfinished',
                ),
                Text(
                  _result!.timerStatus == TimerCompletionStatus.completed
                      ? 'Cycle completed'
                      : 'Ended early',
                ),
                const SizedBox(height: 16),
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
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (session.participationStatus ==
                            ParticipationStatus.requiresRevalidation)
                          const Text(
                            'Seat unverified · Check your connection before continuing.',
                          ),
                        CycleTimerCard(
                          startsAt: session.startsAt,
                          isDemo: session.isDemo,
                          now: DateTime.now().toUtc(),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${session.roomTitle} • Seat ${session.seatId.split('-').last}',
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Your goal',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(session.goalText),
                        const SizedBox(height: 12),
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
                  label: _error == null ? 'Finish session' : 'Retry save',
                  isLoading: _busy,
                  onPressed: active.asData?.value == null ? null : _finish,
                ),
                const SizedBox(height: 12),
                AppDetails(
                  title: 'Session options',
                  icon: Icons.tune,
                  children: [
                    KeepAwakeControl(key: ValueKey(_sessionId)),
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
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Seat and connection verified.',
                                      ),
                                    ),
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
                    const SizedBox(height: 8),
                    const Text(
                      'The room timer keeps running while you’re away. Your seat is checked when you return.',
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}