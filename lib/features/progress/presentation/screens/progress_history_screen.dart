import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_details.dart';
import '../controllers/progress_history_controller.dart';
import '../widgets/progress_status_view.dart';
import '../widgets/progress_dashboard.dart';
import '../widgets/progress_controls.dart';
import '../widgets/progress_session_row.dart';
import '../widgets/study_year_heatmap.dart';

class ProgressHistoryScreen extends ConsumerStatefulWidget {
  const ProgressHistoryScreen({super.key});
  @override
  ConsumerState<ProgressHistoryScreen> createState() =>
      _ProgressHistoryScreenState();
}

class _ProgressHistoryScreenState extends ConsumerState<ProgressHistoryScreen> {
  bool _showDemo = false;
  ProgressPeriod _period = ProgressPeriod.allTime;

  void _about() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: const Text('About your progress'),
      content: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'All-time totals cover all Normal sessions, regardless of the period or Normal/Demo filters. Demo time is excluded. Sessions completed counts completed timers; goal outcomes are separate.',
          ),
          SizedBox(height: 12),
          Text(
            'The study-time chart shows the last seven local dates within the selected period. Goal outcomes and session history use loaded records in the selected period.',
          ),
          SizedBox(height: 12),
          Text(
            'The study calendar uses its selected year and the chosen Normal/Demo history, independently of the period filter. Dates follow your local time; weeks start Monday. Load more history for older activity.',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(progressHistoryProvider);
    return SafeArea(
      child: AppContentWidth(
        child: CustomScrollView(
          key: const PageStorageKey('progress-scroll'),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Progress',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'About your progress',
                              onPressed: _about,
                              icon: const Icon(Icons.info_outline),
                            ),
                            IconButton(
                              tooltip: 'Refresh history',
                              onPressed: () =>
                                  ref.invalidate(progressHistoryProvider),
                              icon: const Icon(Icons.refresh),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ProgressPeriodControl(
                      value: _period,
                      onChanged: (period) => setState(() => _period = period),
                    ),
                    const SizedBox(height: 12),
                    ProgressSegments<bool>(
                      values: const [false, true],
                      value: _showDemo,
                      label: (demo) => demo ? 'Demo' : 'Normal',
                      onChanged: (demo) => setState(() => _showDemo = demo),
                    ),
                    if (_showDemo)
                      Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Demo data · Excluded from Normal totals',
                          style: TextStyle(color: AppColors.primary),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            history.when(
              skipLoadingOnRefresh: false,
              skipLoadingOnReload: false,
              loading: () =>
                  const SliverToBoxAdapter(child: ProgressStatusView.loading()),
              error: (_, _) => SliverToBoxAdapter(
                child: ProgressStatusView.error(
                  onRetry: () => ref.invalidate(progressHistoryProvider),
                ),
              ),
              data: (data) => _history(data),
            ),
          ],
        ),
      ),
    );
  }

  Widget _history(ProgressHistoryData data) {
    final source = _showDemo ? data.demoRecords : data.normalRecords;
    final now = DateTime.now();
    final records = filterProgressRecords(source, _period, now);
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      sliver: SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'All-time totals',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Normal sessions · Demo excluded',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                ProgressTotals(
                  time: progressDuration(data.summary.creditedSeconds),
                  count: data.summary.completedSessionCount,
                ),
                const SizedBox(height: 16),
                ProgressActivity(
                  records: source,
                  period: _period,
                  now: now,
                  hasMore: data.nextPageToken != null,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          DecoratedSliver(
            decoration: progressPanelDecoration(),
            sliver: SliverPadding(
              padding: const EdgeInsets.all(12),
              sliver: SliverMainAxisGroup(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Session history',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Newest first · ${progressPeriodLabel(_period)}${data.nextPageToken != null ? ' · Partial history' : ''}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        if (records.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              data.nextPageToken != null
                                  ? 'No ${_showDemo ? 'demo' : 'normal'} records in loaded pages. Load more to check older history.'
                                  : _showDemo
                                  ? 'No demo records.'
                                  : _period == ProgressPeriod.allTime
                                  ? 'No recorded sessions yet.'
                                  : 'No loaded records in this period.',
                            ),
                          ),
                      ],
                    ),
                  ),
                  SliverList.builder(
                    itemCount: records.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ProgressSessionRow(record: records[index]),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (data.pageError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Semantics(
                              liveRegion: true,
                              child: const Text(
                                'Could not load more history. Your loaded records and summary are still shown.',
                              ),
                            ),
                          ),
                        if (data.nextPageToken != null) ...[
                          const SizedBox(height: 8),
                          AppButton(
                            label: data.pageError == null
                                ? 'Load more history'
                                : 'Retry loading more',
                            isLoading: data.isLoadingMore,
                            onPressed: () => ref
                                .read(progressHistoryProvider.notifier)
                                .loadNextPage(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: StudyYearHeatmap(
                key: ValueKey(_showDemo),
                records: source,
                hasMore: data.nextPageToken != null,
                now: now,
                isDemo: _showDemo,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
