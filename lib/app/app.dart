import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/theme/app_theme.dart';
import 'app_mode.dart';
import '../features/study/data/study_providers.dart';
import 'router.dart';

class StudyMatesApp extends ConsumerWidget {
  const StudyMatesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(appModeProvider);
    if (mode == AppMode.connected) ref.watch(studyLeaseKeeperProvider);
    return MaterialApp.router(
      title: 'StudyMates',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      routerConfig: ref.watch(appRouterProvider),
      builder: (context, child) {
        if (mode == AppMode.connected &&
            const String.fromEnvironment('STUDYMATES_EMULATOR_HOST').isEmpty) {
          // Normal Android app bars keep their own status-bar safe area.
          return child ?? const SizedBox.shrink();
        }
        return Column(
          children: [
            Material(
              color: AppColors.softAccent,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      switch (mode) {
                        AppMode.preview => 'UI Preview • Local sample data',
                        AppMode.connected =>
                          const String.fromEnvironment(
                                'STUDYMATES_EMULATOR_HOST',
                              ).isNotEmpty
                              ? 'Local backend • Test accounts and data'
                              : 'Connected • StudyMates',
                        AppMode.foundation => 'Foundation only • Not connected',
                      },
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: AppColors.primary),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ],
        );
      },
    );
  }
}
