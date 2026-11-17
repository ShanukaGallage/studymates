import 'package:material_ui/material_ui.dart';

import '../../../../core/models/completion_record.dart';
import '../../../../core/theme/app_theme.dart';
import 'progress_dashboard.dart';

String progressDuration(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final remainder = seconds % 60;
  return [
    if (hours > 0) '${hours}h',
    '${minutes}m',
    if (remainder > 0) '${remainder}s',
  ].join(' ');
}

String _localDate(DateTime value) {
  final date = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)} ${two(date.hour)}:${two(date.minute)}';
}

String _timer(CompletionRecord record) => switch (record.timerStatus) {
  TimerCompletionStatus.completed => 'Completed',
  TimerCompletionStatus.endedEarly => 'Ended early',
  TimerCompletionStatus.cancelled => 'Cancelled',
};

class ProgressSessionRow extends StatelessWidget {
  const ProgressSessionRow({super.key, required this.record});
  final CompletionRecord record;

  Future<void> _details(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .85,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Session details',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close session details',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                record.isDemo ? 'Demo session' : 'Study session',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(
                record.goalText.trim().isEmpty
                    ? 'No goal text recorded.'
                    : record.goalText,
                key: ValueKey('progress-goal-${record.recordId}'),
              ),
              const SizedBox(height: 12),
              Text(_localDate(record.endedAt)),
              Text(
                'Recorded time: ${progressDuration(record.creditedSeconds)}',
              ),
              Text('Timer: ${_timer(record)}'),
              Text(
                'Goal: ${record.goalOutcome == GoalOutcome.completed ? 'Completed' : 'Unfinished'}',
              ),
              const SizedBox(height: 16),
              SelectableText('Session: ${record.sessionId}'),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: progressPanelBorder),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      key: ValueKey('progress-record-${record.recordId}'),
      onTap: () => _details(context),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 48,
              decoration: const BoxDecoration(
                color: AppColors.softAccent,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_stories_outlined,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.isDemo ? 'Demo session' : 'Study session',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _localDate(record.endedAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        progressDuration(record.creditedSeconds),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (record.timerStatus != TimerCompletionStatus.completed)
                        _Status(label: _timer(record)),
                      if (record.goalOutcome == GoalOutcome.unfinished)
                        const _Status(label: 'Goal unfinished'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: AppColors.secondaryText),
          ],
        ),
      ),
    ),
  );
}

class _Status extends StatelessWidget {
  const _Status({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.softAccent,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: AppColors.text),
    ),
  );
}
