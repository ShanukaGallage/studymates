import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../core/models/completion_record.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import 'progress_dashboard.dart';

DateTime studyDay(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

Map<DateTime, int> studySecondsByDay(
  Iterable<CompletionRecord> records,
  int year,
) {
  final totals = <DateTime, int>{};
  final seen = <String>{};
  for (final record in records) {
    if (!seen.add(record.recordId)) continue;
    final day = studyDay(record.endedAt);
    if (day.year != year) continue;
    totals.update(
      day,
      (value) => value + record.creditedSeconds,
      ifAbsent: () => record.creditedSeconds,
    );
  }
  return totals;
}

int studyIntensity(int seconds) => switch (seconds) {
  <= 0 => 0,
  < 1800 => 1,
  < 7200 => 2,
  < 14400 => 3,
  _ => 4,
};

const _shades = [
  Color(0xFFF0EDF6),
  Color(0xFFDCD1FA),
  Color(0xFFB39BE8),
  Color(0xFF8767D4),
  AppColors.primary,
];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Year scope is independent of the page's period filter. Only one month grid
/// is shown, with 48dp minimum day targets and an exact-date alternative.
class StudyYearHeatmap extends StatefulWidget {
  const StudyYearHeatmap({
    super.key,
    required this.records,
    required this.hasMore,
    required this.now,
    this.isDemo = false,
  });
  final List<CompletionRecord> records;
  final bool hasMore, isDemo;
  final DateTime now;
  @override
  State<StudyYearHeatmap> createState() => _StudyYearHeatmapState();
}

class _StudyYearHeatmapState extends State<StudyYearHeatmap> {
  late int _year, _month;
  late DateTime _selected;
  bool _expanded = false;
  final _scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    _year = widget.now.year;
    _month = widget.now.month;
    _selected = studyDay(widget.now);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _changeYear(int year) {
    setState(() {
      _year = year;
      _month = 1;
      _selected = DateTime(year);
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _changeMonth(int? month) {
    if (month == null) return;
    setState(() {
      _month = month;
      final first = DateTime(_year, month);
      if (!first.isAfter(studyDay(widget.now))) _selected = first;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _chooseDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selected,
      firstDate: DateTime(_year),
      lastDate: _year == widget.now.year
          ? studyDay(widget.now)
          : DateTime(_year, 12, 31),
    );
    if (picked != null && mounted) {
      setState(() {
        _selected = picked;
        _month = picked.month;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final totals = studySecondsByDay(
      widget.records.where((r) => r.isDemo == widget.isDemo),
      _year,
    );
    final today = studyDay(widget.now);
    final activeDays = totals.entries
        .where((e) => !e.key.isAfter(today) && e.value > 0)
        .length;
    final totalSeconds = totals.entries
        .where((e) => !e.key.isAfter(today))
        .fold<int>(0, (sum, e) => sum + e.value);
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: progressPanelBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            expanded: _expanded,
            child: InkWell(
              key: const ValueKey('study-calendar-toggle'),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_outlined,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Study calendar',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            '$_year · $activeDays active ${activeDays == 1 ? 'day' : 'days'}${widget.hasMore ? ' · Partial history' : ''}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                  ],
                ),
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Previous study year',
                        onPressed: _year > 1970
                            ? () => _changeYear(_year - 1)
                            : null,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: Text(
                          '$_year',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Next study year',
                        onPressed: _year < widget.now.year
                            ? () => _changeYear(_year + 1)
                            : null,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  Text(
                    '${_duration(totalSeconds)} in $_year',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.hasMore
                        ? 'Partial year · Load more history for older activity.'
                        : 'All history loaded · Local dates',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: const InputDecoration(labelText: 'Month'),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        key: const ValueKey('study-calendar-month'),
                        value: _month,
                        isExpanded: true,
                        items: [
                          for (var i = 1; i <= 12; i++)
                            DropdownMenuItem(
                              value: i,
                              child: Text(_months[i - 1]),
                            ),
                        ],
                        onChanged: _changeMonth,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _monthCalendar(totals, today),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < _shades.length; i++)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _shades[i],
                                border: Border.all(
                                  color: AppColors.secondaryText,
                                  width: .5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              ['0', '<30m', '30m–<2h', '2–<4h', '4h+'][i],
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AppButton(
                    label: 'Inspect a study day',
                    variant: AppButtonVariant.secondary,
                    onPressed: _chooseDay,
                  ),
                  const SizedBox(height: 8),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      '${_date(_selected)}: ${_duration(totals[_selected] ?? 0)}${widget.hasMore ? ' in loaded records (incomplete)' : ''}',
                      key: const ValueKey('study-calendar-selected-day'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _monthCalendar(
    Map<DateTime, int> totals,
    DateTime today,
  ) => LayoutBuilder(
    builder: (context, constraints) {
      final offset = DateTime(_year, _month).weekday - 1;
      final days = DateTime(_year, _month + 1, 0).day;
      final weeks = (offset + days + 6) ~/ 7;
      final cell = math.max(
        math.max(48.0, MediaQuery.textScalerOf(context).scale(14) * 2.4),
        constraints.maxWidth / 7,
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (cell * 7 > constraints.maxWidth)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Swipe to see all weekdays',
                style: TextStyle(color: AppColors.secondaryText),
              ),
            ),
          Scrollbar(
            controller: _scroll,
            thumbVisibility: cell * 7 > constraints.maxWidth,
            child: SingleChildScrollView(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  width: cell * 7,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          for (final day in [
                            'Mon',
                            'Tue',
                            'Wed',
                            'Thu',
                            'Fri',
                            'Sat',
                            'Sun',
                          ])
                            SizedBox(
                              width: cell,
                              height: cell,
                              child: Center(
                                child: Text(
                                  day,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ),
                        ],
                      ),
                      for (var week = 0; week < weeks; week++)
                        Row(
                          children: [
                            for (var weekday = 0; weekday < 7; weekday++)
                              Builder(
                                builder: (context) {
                                  final index = week * 7 + weekday - offset;
                                  if (index < 0 || index >= days) {
                                    return SizedBox.square(dimension: cell);
                                  }
                                  final date = DateTime(
                                    _year,
                                    _month,
                                    index + 1,
                                  );
                                  final future = date.isAfter(today);
                                  final seconds = totals[date] ?? 0;
                                  final color = future
                                      ? AppColors.background
                                      : _shades[studyIntensity(seconds)];
                                  final darkRatio =
                                      (color.computeLuminance() + .05) /
                                      (AppColors.text.computeLuminance() + .05);
                                  final whiteRatio =
                                      1.05 / (color.computeLuminance() + .05);
                                  final foreground = darkRatio >= 4.5
                                      ? AppColors.text
                                      : whiteRatio >= 4.5
                                      ? Colors.white
                                      : Colors.black;
                                  final label =
                                      '${_date(date)}: ${future ? 'future date' : '${_duration(seconds)}${widget.hasMore ? ', loaded records only' : ''}'}';
                                  return Semantics(
                                    label: label,
                                    button: true,
                                    enabled: !future,
                                    selected: _selected == date,
                                    excludeSemantics: true,
                                    child: Tooltip(
                                      message: label,
                                      child: InkWell(
                                        key: ValueKey(
                                          'study-calendar-day-${_date(date)}',
                                        ),
                                        onTap: future
                                            ? null
                                            : () => setState(
                                                () => _selected = date,
                                              ),
                                        child: SizedBox.square(
                                          dimension: cell,
                                          child: Padding(
                                            padding: const EdgeInsets.all(3),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: color,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: _selected == date
                                                      ? AppColors.primary
                                                      : progressPanelBorder,
                                                  width: _selected == date
                                                      ? 2
                                                      : .5,
                                                ),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  '${date.day}',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        color: foreground,
                                                      ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

String _date(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
String _duration(int seconds) =>
    '${seconds ~/ 3600}h ${(seconds % 3600) ~/ 60}m ${seconds % 60}s';
