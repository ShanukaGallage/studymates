import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../core/models/completion_record.dart';
import '../../../../core/theme/app_theme.dart';

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

const progressPanelBorder = Color(0xFFDCD4EE);

BoxDecoration progressPanelDecoration() => BoxDecoration(
  color: AppColors.surface,
  border: Border.all(color: progressPanelBorder),
  borderRadius: BorderRadius.circular(20),
);

class ProgressPanel extends StatelessWidget {
  const ProgressPanel({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: progressPanelDecoration(),
    child: child,
  );
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
  Widget build(BuildContext context) => ProgressPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
          child: Icon(icon, color: AppColors.primary),
        ),
        const SizedBox(height: 12),
        Text(value, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
}

class ProgressTotals extends StatelessWidget {
  const ProgressTotals({super.key, required this.time, required this.count});
  final String time;
  final int count;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final metrics = [
        ProgressMetric(
          key: const ValueKey('progress-total-time'),
          label: 'Study time',
          value: time,
          icon: Icons.schedule,
          tint: AppColors.softAccent,
        ),
        ProgressMetric(
          key: const ValueKey('progress-total-count'),
          label: 'Sessions completed',
          value: '$count',
          icon: Icons.auto_stories_outlined,
          tint: AppColors.softAccent,
        ),
      ];
      if (constraints.maxWidth >= 480 ||
          MediaQuery.textScalerOf(context).scale(16) <= 22) {
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: metrics[0]),
              const SizedBox(width: 12),
              Expanded(child: metrics[1]),
            ],
          ),
        );
      }
      // Full-width cards prevent words breaking into fragments at large text sizes.
      // Measure both labels/values with the same inherited styles, then reserve the
      // larger height for both. Minimum height still lets unexpected text grow.
      double textHeight(String value, TextStyle? style) {
        final painter = TextPainter(
          text: TextSpan(
            text: value,
            style: DefaultTextStyle.of(context).style.merge(style),
          ),
          textScaler: MediaQuery.textScalerOf(context),
          textDirection: Directionality.of(context),
        )..layout(maxWidth: constraints.maxWidth - 32);
        final height = painter.height;
        painter.dispose();
        return height;
      }

      final theme = Theme.of(context).textTheme;
      final height =
          104.0 +
          math.max(
            textHeight(time, theme.headlineSmall) +
                textHeight('Study time', theme.bodyMedium),
            textHeight('$count', theme.headlineSmall) +
                textHeight('Sessions completed', theme.bodyMedium),
          );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < metrics.length; index++) ...[
            if (index > 0) const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: height),
              child: metrics[index],
            ),
          ],
        ],
      );
    },
  );
}

/// The chart remains seven local days filtered by the selected period. Goal
/// counts use all loaded records in that period, including zero-time records.
class ProgressActivity extends StatelessWidget {
  const ProgressActivity({
    super.key,
    required this.records,
    required this.period,
    required this.now,
    required this.hasMore,
  });
  final List<CompletionRecord> records;
  final ProgressPeriod period;
  final DateTime now;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    final filtered = filterProgressRecords(records, period, now);
    final finished = filtered
        .where((r) => r.goalOutcome == GoalOutcome.completed)
        .length;
    final unfinished = filtered.length - finished;
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
    final scope = switch (period) {
      ProgressPeriod.day => 'Day',
      ProgressPeriod.week => 'Week',
      ProgressPeriod.month => 'Month',
      ProgressPeriod.allTime => 'All time',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProgressPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Study time', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                period == ProgressPeriod.allTime
                    ? 'Last 7 days'
                    : 'Last 7 days · $scope filter',
              ),
              Text(
                '${_date(dates.first)} – ${_date(dates.last)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (largest > 0)
                Text(
                  'Minutes recorded',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (hasMore)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Partial history · Loaded records only',
                    style: TextStyle(color: AppColors.secondaryText),
                  ),
                ),
              const SizedBox(height: 16),
              if (largest == 0)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No study time recorded for this period',
                    textAlign: TextAlign.center,
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (MediaQuery.textScalerOf(context).scale(14) > 21 ||
                        constraints.maxWidth < 260) {
                      return Column(
                        children: [
                          for (var i = 0; i < dates.length; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                spacing: 12,
                                children: [
                                  Text(_date(dates[i])),
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
                                        height: math.max(
                                          3,
                                          seconds[i] / largest * 102,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
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
            ],
          ),
        ),
        const SizedBox(height: 16),
        ProgressPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Goal outcomes',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                '$scope${hasMore ? ' · Partial history' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              if (filtered.isEmpty)
                const Text('No goal outcomes in this period.')
              else
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _GoalCount(
                          label: 'Completed',
                          count: finished,
                          icon: Icons.check,
                          valueKey: 'progress-goals-completed',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _GoalCount(
                          label: 'Unfinished',
                          count: unfinished,
                          icon: Icons.outlined_flag,
                          valueKey: 'progress-goals-unfinished',
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GoalCount extends StatelessWidget {
  const _GoalCount({
    required this.label,
    required this.count,
    required this.icon,
    required this.valueKey,
  });
  final String label, valueKey;
  final int count;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$count', style: Theme.of(context).textTheme.titleLarge),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
    final symbol = Icon(icon, color: AppColors.primary);
    return Container(
      key: ValueKey(valueKey),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: progressPanelBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: MediaQuery.textScalerOf(context).scale(14) > 21
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [symbol, const SizedBox(height: 8), details],
            )
          : Row(
              children: [
                symbol,
                const SizedBox(width: 8),
                Expanded(child: details),
              ],
            ),
    );
  }
}

String _date(DateTime date) => '${date.day}/${date.month}/${date.year}';
String _time(int seconds) => '${seconds ~/ 60}m ${seconds % 60}s';
