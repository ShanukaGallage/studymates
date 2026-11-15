import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/models/completion_record.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../controllers/progress_history_controller.dart';
import '../widgets/progress_status_view.dart';

/// Scrollable route body. Supply the read-only repository through ProviderScope.
class ProgressHistoryScreen extends ConsumerStatefulWidget {
  const ProgressHistoryScreen({super.key});

  @override
  ConsumerState<ProgressHistoryScreen> createState() =>
      _ProgressHistoryScreenState();
}

class _ProgressHistoryScreenState extends ConsumerState<ProgressHistoryScreen> {
  bool _showDemo = false;

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(progressHistoryProvider);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text('Progress', style: Theme.of(context).textTheme.headlineSmall),
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
    );
  }

  Widget _history(BuildContext context, ProgressHistoryData data) {
    final records = _showDemo ? data.demoRecords : data.normalRecords;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Normal progress · all history',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Eligible recorded time: ${_duration(data.summary.creditedSeconds)}',
                ),
                Text(
                  'Completed sessions: ${data.summary.completedSessionCount}',
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Demo records are excluded. Goal outcome does not change credited time.',
                ),
              ],
            ),
          ),
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
            AppButton(
              label: 'Refresh history',
              variant: AppButtonVariant.secondary,
              onPressed: () => ref.invalidate(progressHistoryProvider),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          _showDemo ? 'Demo history · rehearsal only' : 'Personal history',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          _showDemo ? 'Demo records never contribute to normal progress.' : 'Recent records, newest first. The summary covers all eligible history.',
        ),
        const SizedBox(height: AppSpacing.lg),
        if (records.isEmpty)
          Text(
            data.nextPageToken != null
                ? 'No ${_showDemo ? 'demo' : 'normal'} records in loaded pages. Load more to check older history.'
                : _showDemo
                ? 'No demo records.'
                : 'No recorded sessions yet.',
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
              'Personal goal',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              record.goalText.trim().isEmpty
                  ? 'No goal text recorded.'
                  : record.goalText,
              key: ValueKey('progress-goal-${record.recordId}'),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Session: ${record.sessionId}'),
            Text('Ended: $date (local time)'),
            Text('Recorded time: ${_duration(record.creditedSeconds)}'),
            Text('Timer: $timer'),
            Text(
              'Goal: ${record.goalOutcome == GoalOutcome.completed ? 'Completed' : 'Unfinished'}',
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
