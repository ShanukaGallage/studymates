import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../core/models/completion_record.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';

enum ProgressPeriod { day, week, month, allTime }

List<CompletionRecord> filterProgressRecords(
  List<CompletionRecord> records,
  ProgressPeriod period,
  DateTime now,
) {
  final today = DateTime(now.year, now.month, now.day);
  final start = switch (period) {
    ProgressPeriod.day => today,
    ProgressPeriod.week => today.subtract(Duration(days: today.weekday - 1)),
    ProgressPeriod.month => DateTime(today.year, today.month),
    ProgressPeriod.allTime => null,
  };
  final tomorrow = DateTime(today.year, today.month, today.day + 1);
  return records.where((record) {
    final ended = record.endedAt.toLocal();
    return period == ProgressPeriod.allTime ||
        (!ended.isBefore(start!) && ended.isBefore(tomorrow));
  }).toList();
}

class ProgressMetric extends StatelessWidget {
  const ProgressMetric({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
  });
  final String label, value;
  final IconData icon;
  final Color tint;
  @override
  Widget build(BuildContext context) => Container(
    width: 154,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: tint,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(height: 20),
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

/// Read-only aggregates of the explicitly loaded, filtered records.
/// The complete-history summary remains owned by the repository.
class ProgressActivity extends StatelessWidget {
  const ProgressActivity({
    super.key,
    required this.records,
    required this.period,
    required this.onPeriodChanged,
    required this.now,
    required this.hasMore,
  });
  final List<CompletionRecord> records;
  final ProgressPeriod period;
  final ValueChanged<ProgressPeriod> onPeriodChanged;
  final DateTime now;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    final filtered = filterProgressRecords(records, period, now);
    final finished = filtered
        .where((r) => r.goalOutcome == GoalOutcome.completed)
        .length;
    final unfinished = filtered.length - finished;
    // Calendar days, never 24-hour buckets, so local day boundaries survive DST.
    final today = DateTime(now.year, now.month, now.day);
    final dates = List.generate(
      7,
      (index) => DateTime(today.year, today.month, today.day - 6 + index),
    );
    final seconds = [
      for (final date in dates)
        filtered
            .where((record) {
              final end = record.endedAt.toLocal();
              return end.year == date.year &&
                  end.month == date.month &&
                  end.day == date.day;
            })
            .fold<int>(0, (sum, record) => sum + record.creditedSeconds),
    ];
    final largest = seconds.fold<int>(0, math.max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in ProgressPeriod.values)
              ChoiceChip(
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(switch (value) {
                    ProgressPeriod.day => 'Day',
                    ProgressPeriod.week => 'Week',
                    ProgressPeriod.month => 'Month',
                    ProgressPeriod.allTime => 'All time',
                  }),
                ),
                selected: value == period,
                onSelected: (_) => onPeriodChanged(value),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Filters apply to loaded activity and history. Week starts Monday; dates use local time.${hasMore ? ' Older pages are not included yet.' : ''}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 20),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Study time', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              const Text(
                'Last 7 calendar days · loaded records in selected period',
              ),
              const SizedBox(height: 20),
              if (largest == 0)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text('No recorded time in these days.'),
                ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final large =
                      MediaQuery.textScalerOf(context).scale(14) > 21 ||
                      constraints.maxWidth < 260;
                  if (large) {
                    return Column(
                      children: [
                        for (var i = 0; i < dates.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Expanded(child: Text(_date(dates[i]))),
                                Text(_time(seconds[i])),
                              ],
                            ),
                          ),
                      ],
                    );
                  }
                  return SizedBox(
                    height: 170,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < dates.length; i++)
                          Expanded(
                            child: Semantics(
                              label:
                                  '${_date(dates[i])}: ${seconds[i]} recorded seconds',
                              excludeSemantics: true,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${(seconds[i] / 60).round()}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall,
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      height: largest == 0
                                          ? 3
                                          : math.max(
                                              3,
                                              seconds[i] / largest * 102,
                                            ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        gradient: const LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: [
                                            AppColors.softAccent,
                                            AppColors.primary,
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${dates[i].day}/${dates[i].month}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              const Text(
                'Values shown in minutes; credited seconds are retained.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Goal outcomes',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              const Text('Selected period · loaded records'),
              const SizedBox(height: 20),
              Center(
                child: SizedBox.square(
                  dimension: math.max(
                    160,
                    MediaQuery.textScalerOf(context).scale(100),
                  ),
                  child: CustomPaint(
                    painter: _OutcomeRing(
                      finished: finished,
                      total: filtered.length,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${filtered.length}',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const Text('Records'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Completed goals: $finished'),
              Text('Unfinished goals: $unfinished'),
              if (filtered.isEmpty)
                const Text('No goal outcomes in this period.'),
              const SizedBox(height: 8),
              const Text(
                'Goal outcome is separate from timer completion and credited time.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _date(DateTime date) => '${date.day}/${date.month}/${date.year}';
String _time(int seconds) => '${seconds ~/ 60}m ${seconds % 60}s';

class _OutcomeRing extends CustomPainter {
  const _OutcomeRing({required this.finished, required this.total});
  final int finished, total;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final ring = rect.deflate(10);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(
      ring,
      0,
      math.pi * 2,
      false,
      paint..color = AppColors.softAccent,
    );
    if (total == 0) return;
    final sweep = finished / total * math.pi * 2;
    canvas.drawArc(
      ring,
      -math.pi / 2,
      sweep,
      false,
      paint..color = AppColors.primary,
    );
    canvas.drawArc(
      ring,
      -math.pi / 2 + sweep,
      math.pi * 2 - sweep,
      false,
      paint..color = AppColors.secondaryText,
    );
  }

  @override
  bool shouldRepaint(_OutcomeRing oldDelegate) =>
      finished != oldDelegate.finished || total != oldDelegate.total;
}
