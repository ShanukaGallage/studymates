import 'package:material_ui/material_ui.dart';

import '../../../../core/models/completion_record.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';

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

/// Annual view of the supplied history pages. Never implies complete coverage
/// while pagination remains. Future cells are blank, not zero-study days.
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
  late int _year;
  late DateTime _selected;
  final _scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    _year = widget.now.year;
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
      _selected = DateTime(year);
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
    if (picked != null && mounted) setState(() => _selected = picked);
  }

  @override
  Widget build(BuildContext context) {
    final totals = studySecondsByDay(
      widget.records.where((r) => r.isDemo == widget.isDemo),
      _year,
    );
    final today = studyDay(widget.now);
    final first = DateTime(_year);
    final offset = first.weekday - 1;
    // Use UTC only for calendar length; local DateTime constructors handle cells.
    final days = DateTime.utc(_year + 1).difference(DateTime.utc(_year)).inDays;
    final weeks = (offset + days + 6) ~/ 7;
    final totalSeconds = totals.entries
        .where((e) => !e.key.isAfter(today))
        .fold<int>(0, (sum, e) => sum + e.value);
    final activeDays = totals.entries
        .where((e) => !e.key.isAfter(today) && e.value > 0)
        .length;
    final selectedSeconds = totals[_selected] ?? 0;
    final incomplete = widget.hasMore
        ? 'Partial year · Load more history for older activity.'
        : 'All history loaded · Local dates';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.isDemo ? 'Demo study year' : 'Your study year',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                tooltip: 'Previous study year',
                onPressed: _year > 1970 ? () => _changeYear(_year - 1) : null,
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
            '$activeDays active days · ${_duration(totalSeconds)}${widget.hasMore ? ' in loaded records' : ''}',
          ),
          const SizedBox(height: 8),
          Text(incomplete, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          Semantics(
            label: 'Full year study intensity overview. Use Inspect a study day for exact values.',
            child: ExcludeSemantics(
              child: SizedBox(
                height: 70,
                child: CustomPaint(
                  painter: _YearOverview(
                    year: _year,
                    days: days,
                    offset: offset,
                    weeks: weeks,
                    totals: totals,
                    today: today,
                  ),
                ),
              ),
            ),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text('Jan'), Text('Dec')],
          ),
          const SizedBox(height: 16),
          const Text('Swipe months to explore · Mon–Sun'),
          const SizedBox(height: 12),
          Scrollbar(
            controller: _scroll,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var month = 1; month <= 12; month++)
                      Padding(
                        padding: EdgeInsets.only(right: month == 12 ? 0 : 12),
                        child: _monthCalendar(context, month, totals, today),
                      ),
                  ],
                ),
              ),
            ),
          ),
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
              '${_date(_selected)}: ${_duration(selectedSeconds)}${widget.hasMore ? ' in loaded records (incomplete)' : ''}',
            ),
          ),
        ],
      ),
    );
  }

  Widget _monthCalendar(
    BuildContext context,
    int month,
    Map<DateTime, int> totals,
    DateTime today,
  ) {
    final offset = DateTime(_year, month).weekday - 1;
    final days = DateTime(_year, month + 1, 0).day;
    final weeks = (offset + days + 6) ~/ 7;
    return SizedBox(
      width: weeks * 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _months[month - 1],
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var week = 0; week < weeks; week++)
                Column(
                  children: [
                    for (var row = 0; row < 7; row++)
                      Builder(
                        builder: (context) {
                          final index = week * 7 + row - offset;
                          if (index < 0 || index >= days) {
                            return const SizedBox(width: 16, height: 16);
                          }
                          final date = DateTime(_year, month, index + 1);
                          final future = date.isAfter(today);
                          final seconds = totals[date] ?? 0;
                          return Semantics(
                            label:
                                '${_date(date)}: ${future ? 'future date' : '${_duration(seconds)}${widget.hasMore ? ', loaded records only' : ''}'}',
                            child: Container(
                              width: 12,
                              height: 12,
                              margin: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: future
                                    ? Colors.transparent
                                    : _shades[studyIntensity(seconds)],
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(
                                  color: future
                                      ? AppColors.softAccent
                                      : const Color(0xFFBCB4CF),
                                  width: .5,
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
        ],
      ),
    );
  }
}

String _date(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
String _duration(int seconds) =>
    '${seconds ~/ 3600}h ${(seconds % 3600) ~/ 60}m ${seconds % 60}s';

class _YearOverview extends CustomPainter {
  const _YearOverview({
    required this.year,
    required this.days,
    required this.offset,
    required this.weeks,
    required this.totals,
    required this.today,
  });
  final int year, days, offset, weeks;
  final Map<DateTime, int> totals;
  final DateTime today;
  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width / weeks;
    final height = size.height / 7;
    for (var i = 0; i < days; i++) {
      final date = DateTime(year, 1, i + 1);
      final cell = i + offset;
      final rect = Rect.fromLTWH(
        (cell ~/ 7) * width + .5,
        (cell % 7) * height + 1,
        (width - 1).clamp(.5, width),
        height - 2,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(1)),
        Paint()
          ..color = date.isAfter(today)
              ? AppColors.background
              : _shades[studyIntensity(totals[date] ?? 0)],
      );
    }
  }

  @override
  bool shouldRepaint(_YearOverview old) => true;
}
