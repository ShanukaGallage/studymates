import 'package:material_ui/material_ui.dart';

import '../../../../core/models/completion_record.dart';
import '../../../../core/widgets/app_card.dart';
import '../../data/session_timing.dart';

String sessionDuration(int seconds) =>
    '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

/// Presentation only. The caller supplies timing and outcome; no credit is awarded.
class SessionView extends StatelessWidget {
  const SessionView({
    super.key,
    required this.roomTitle,
    required this.seat,
    required this.goal,
    required this.timing,
    required this.elapsedSeconds,
  });
  final String roomTitle, goal;
  final int seat, elapsedSeconds;
  final SessionTiming timing;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(switch (timing.phase) {
          SessionPhase.waiting => 'Getting ready',
          SessionPhase.focus => 'Time to focus',
          SessionPhase.breakTime => 'Take a short break',
          SessionPhase.completed => 'Cycle complete',
        }, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        Text(
          sessionDuration(timing.remainingSeconds),
          semanticsLabel: '${timing.remainingSeconds} seconds remaining',
          style: Theme.of(context).textTheme.displayMedium,
        ),
        const Text('Remaining in this phase'),
        const SizedBox(height: 16),
        Text('$roomTitle • Seat $seat'),
        const SizedBox(height: 16),
        Text('Your goal', style: Theme.of(context).textTheme.titleMedium),
        Text(goal),
        const SizedBox(height: 16),
        Text('Elapsed: ${sessionDuration(elapsedSeconds)}'),
      ],
    ),
  );
}

class SessionSummaryView extends StatelessWidget {
  const SessionSummaryView({
    super.key,
    required this.goal,
    required this.elapsedSeconds,
    required this.timerStatus,
    required this.goalOutcome,
  });
  final String goal;
  final int elapsedSeconds;
  final TimerCompletionStatus timerStatus;
  final GoalOutcome goalOutcome;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Session summary',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Text(
          timerStatus == TimerCompletionStatus.completed
              ? 'Cycle completed'
              : 'Ended early',
        ),
        Text('Elapsed preview time: ${sessionDuration(elapsedSeconds)}'),
        const SizedBox(height: 16),
        Text(goal),
        Text(
          goalOutcome == GoalOutcome.completed
              ? 'Goal completed'
              : 'Goal unfinished',
        ),
        const SizedBox(height: 16),
        const Text(
          'Preview only. Nothing was saved and no study credit was awarded. Progress shows separate sample records.',
        ),
      ],
    ),
  );
}
