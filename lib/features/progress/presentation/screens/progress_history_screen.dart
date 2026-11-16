import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/models/completion_record.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_details.dart';
import '../controllers/progress_history_controller.dart';
import '../widgets/progress_status_view.dart';
import '../widgets/progress_dashboard.dart';
import '../widgets/study_year_heatmap.dart';

/// Scrollable route body. Supply the read-only repository through ProviderScope.
class ProgressHistoryScreen extends ConsumerStatefulWidget {
  const ProgressHistoryScreen({super.key});

  @override
  ConsumerState<ProgressHistoryScreen> createState() =>
      _ProgressHistoryScreenState();
}

class _ProgressHistoryScreenState extends ConsumerState<ProgressHistoryScreen> {
  bool _showDemo = false;
  ProgressPeriod _period = ProgressPeriod.allTime;

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(progressHistoryProvider);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.background,
            AppColors.softAccent,
            AppColors.background,
          ],
        ),
      ),
      child: SafeArea(
        child: AppContentWidth(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Progress overview',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh history',
                    onPressed: () => ref.invalidate(progressHistoryProvider),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              history.when(
                skipLoadingOnRefresh: false,
                skipLoadingOnReload: false,
                loading: () => const ProgressStatusView.loading(),
                error: (_, _) => ProgressStatusView.error(
                  onRetry: () => ref.invalidate(progressHistoryProvider),
                ),
                data: (data) => _history(context, data),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _history(BuildContext context, ProgressHistoryData data) {
    final source = _showDemo ? data.demoRecords : data.normalRecords;
    final now = DateTime.now();
    final records = filterProgressRecords(source, _period, now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'All-time · Normal sessions',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ProgressMetric(
              key: const ValueKey('progress-total-time'),
              label: 'Study time',
              value: _duration(data.summary.creditedSeconds),
              icon: Icons.schedule,
              tint: AppColors.softAccent,
            ),
            ProgressMetric(
              key: const ValueKey('progress-total-count'),
              label: 'Sessions completed',
              value: '${data.summary.completedSessionCount}',
              icon: Icons.auto_stories_outlined,
              tint: AppColors.blueAccent,
            ),
          ],
        ),
        AppDetails(
          title: 'About your progress',
          children: const [
            Text(
              'Totals cover all your normal sessions. Demo time is excluded. Goal completion is separate from recorded focus time.',
            ),
            SizedBox(height: 8),
            Text(
              'Charts use the history loaded so far. Dates follow your local time; weeks start Monday.',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            AppButton(
              label: 'Normal history',
              variant: _showDemo
                  ? AppButtonVariant.secondary
                  : AppButtonVariant.primary,
              onPressed: () => setState(() => _showDemo = false),
            ),
            AppButton(
              label: 'Demo history',
              variant: _showDemo
                  ? AppButtonVariant.primary
                  : AppButtonVariant.secondary,
              onPressed: () => setState(() => _showDemo = true),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        StudyYearHeatmap(
          key: ValueKey(_showDemo),
          records: source,
          hasMore: data.nextPageToken != null,
          now: now,
          isDemo: _showDemo,
        ),
        const SizedBox(height: AppSpacing.xl),
        ProgressActivity(
          records: source,
          period: _period,
          now: now,
          hasMore: data.nextPageToken != null,
          onPeriodChanged: (value) => setState(() => _period = value),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          _showDemo ? 'Demo history · rehearsal only' : 'Personal history',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(_showDemo ? 'Excluded from normal totals' : 'Newest first'),
        const SizedBox(height: AppSpacing.lg),
        if (records.isEmpty)
          Text(
            data.nextPageToken != null
                ? 'No ${_showDemo ? 'demo' : 'normal'} records in loaded pages. Load more to check older history.'
                : _showDemo
                ? 'No demo records.'
                : _period == ProgressPeriod.allTime
                ? 'No recorded sessions yet.'
                : 'No loaded records in this period.',
          ),
        for (final record in records) _RecordCard(record: record),
        if (data.pageError != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Semantics(
            liveRegion: true,
            child: const Text(
              'Could not load more history. Your loaded records and summary are still shown.',
            ),
          ),
        ],
        if (data.nextPageToken != null) ...[
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: data.pageError == null
                ? 'Load more history'
                : 'Retry loading more',
            isLoading: data.isLoadingMore,
            onPressed: () =>
                ref.read(progressHistoryProvider.notifier).loadNextPage(),
          ),
        ],
      ],
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record});
  final CompletionRecord record;

  @override
  Widget build(BuildContext context) {
    final ended = record.endedAt.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    final date =
        '${ended.year}-${two(ended.month)}-${two(ended.day)} ${two(ended.hour)}:${two(ended.minute)}';
    final timer = switch (record.timerStatus) {
      TimerCompletionStatus.completed => 'Completed',
      TimerCompletionStatus.endedEarly => 'Ended early',
      TimerCompletionStatus.cancelled => 'Cancelled',
    };
    return Card(
      key: ValueKey('progress-record-${record.recordId}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              record.isDemo ? 'Demo session' : 'Study session',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              record.goalText.trim().isEmpty
                  ? 'No goal text recorded.'
                  : record.goalText,
              key: ValueKey('progress-goal-${record.recordId}'),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(date, style: Theme.of(context).textTheme.bodySmall),
            Text('Recorded time: ${_duration(record.creditedSeconds)}'),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                Text('Timer: $timer'),
                Text(
                  'Goal: ${record.goalOutcome == GoalOutcome.completed ? 'Completed' : 'Unfinished'}',
                ),
              ],
            ),
            AppDetails(
              title: 'Session details',
              children: [SelectableText('Session: ${record.sessionId}')],
            ),
          ],
        ),
      ),
    );
  }
}

String _duration(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final remainder = seconds % 60;
  return [
    if (hours > 0) '${hours}h',
    '${minutes}m',
    if (remainder > 0) '${remainder}s',
  ].join(' ');
}
