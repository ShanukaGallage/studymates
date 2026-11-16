import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';
import '../../data/session_timing.dart';
import 'session_views.dart';

class CycleTimerCard extends StatelessWidget {
  const CycleTimerCard({
    super.key,
    required this.startsAt,
    required this.isDemo,
    required this.now,
  });
  final DateTime startsAt, now;
  final bool isDemo;

  @override
  Widget build(BuildContext context) {
    final focus = isDemo ? 45 : 1500;
    final total = isDemo ? 60 : 1800;
    final timing = calculateSessionTiming(
      nowUtc: now,
      startsAt: startsAt,
      focusEndsAt: startsAt.add(Duration(seconds: focus)),
      breakEndsAt: startsAt.add(Duration(seconds: total)),
    ) as SessionTiming;
    final elapsed = now.difference(startsAt).inSeconds.clamp(0, total);
    final phase = switch (timing.phase) {
      SessionPhase.waiting => 'Getting ready',
      SessionPhase.focus => 'Focus time',
      SessionPhase.breakTime => 'Break time',
      SessionPhase.completed => 'Cycle complete',
    };
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.timelapse_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Current cycle',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            isDemo
                ? 'DEMO · 45s focus + 15s break'
                : '25 min focus + 5 min break',
            style: const TextStyle(color: AppColors.secondaryText),
          ),
          const SizedBox(height: 16),
          Text(
            phase,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            sessionDuration(timing.remainingSeconds),
            textAlign: TextAlign.center,
            semanticsLabel:
                '$phase, ${timing.remainingSeconds} seconds remaining',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Icon(Icons.directions_walk, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: LinearProgressIndicator(
                  value: elapsed / total,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(8),
                  backgroundColor: AppColors.softAccent,
                  semanticsLabel: 'Whole cycle progress',
                  semanticsValue: '${(elapsed * 100 / total).round()}%',
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.flag_outlined, color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${sessionDuration(elapsed)} / ${sessionDuration(total)} elapsed',
            textAlign: TextAlign.center,
          ),
          if (timing.phase == SessionPhase.completed)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Cycle finished. Save your session to join the next one.',
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
