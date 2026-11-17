import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_theme.dart';
import 'progress_dashboard.dart';

String progressPeriodLabel(ProgressPeriod period) => switch (period) {
  ProgressPeriod.day => 'Day',
  ProgressPeriod.week => 'Week',
  ProgressPeriod.month => 'Month',
  ProgressPeriod.allTime => 'All time',
};

class ProgressPeriodControl extends StatelessWidget {
  const ProgressPeriodControl({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final ProgressPeriod value;
  final ValueChanged<ProgressPeriod> onChanged;

  @override
  Widget build(BuildContext context) => ProgressSegments<ProgressPeriod>(
    values: ProgressPeriod.values,
    value: value,
    label: progressPeriodLabel,
    onChanged: onChanged,
    wrapForLargeText: true,
  );
}

/// Equal-sized 48dp controls; four filters become two rows at large text sizes.
class ProgressSegments<T> extends StatelessWidget {
  const ProgressSegments({
    super.key,
    required this.values,
    required this.value,
    required this.label,
    required this.onChanged,
    this.wrapForLargeText = false,
  });
  final List<T> values;
  final T value;
  final String Function(T) label;
  final ValueChanged<T> onChanged;
  final bool wrapForLargeText;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns =
          wrapForLargeText &&
              constraints.maxWidth < 480 &&
              MediaQuery.textScalerOf(context).scale(16) > 22
          ? 2
          : values.length;
      return Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: const Color(0xFFC5B8DF)),
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var start = 0; start < values.length; start += columns)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final item in values.skip(start).take(columns))
                      Expanded(
                        child: Semantics(
                          selected: item == value,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 12,
                              ),
                              shape: const RoundedRectangleBorder(),
                              foregroundColor: item == value
                                  ? Colors.white
                                  : AppColors.text,
                              backgroundColor: item == value
                                  ? AppColors.primary
                                  : Colors.transparent,
                            ),
                            onPressed: () => onChanged(item),
                            child: Text(
                              label(item),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      );
    },
  );
}
