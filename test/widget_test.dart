import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:studymates/app/app.dart';
import 'package:studymates/preview/progress_history_fixtures.dart';
import 'package:studymates/features/progress/presentation/controllers/progress_history_controller.dart';
import 'package:studymates/features/communities/presentation/controllers/community_providers.dart';
import 'package:studymates/preview/preview_repositories.dart';
import 'package:studymates/app/app_mode.dart';
import 'package:studymates/app/router.dart';
import 'package:studymates/core/widgets/app_button.dart';
import 'package:studymates/core/widgets/app_text_field.dart';
import 'package:studymates/core/theme/app_theme.dart';

void main() {
  Future<ProviderContainer> mount(
    WidgetTester tester, {
    AppMode mode = AppMode.preview,
    String location = '/home',
    double textScale = 1,
  }) async {
    final router = createAppRouter(mode: mode, initialLocation: location);
    final container = ProviderContainer(
      overrides: [
        appModeProvider.overrideWithValue(mode),
        communityRepositoryProvider.overrideWith(
          (ref) => MemoryCommunityRepository(),
        ),
        appRouterProvider.overrideWithValue(router),
        progressHistoryRepositoryProvider.overrideWith(
          (ref) => ProgressHistoryFixtureRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: const StudyMatesApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('all tabs navigate and direct routes synchronize selection', (
    tester,
  ) async {
    final container = await mount(tester, location: '/progress');
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
    for (final (index, name) in [
      'Home',
      'Discover',
      'Progress',
      'Profile',
    ].indexed) {
      await tester.tap(find.text(name).last);
      await tester.pumpAndSettle();
      expect(
        find.text(
          name == 'Discover'
              ? 'Search communities'
              : name == 'Progress'
              ? 'Eligible recorded time: 1h 5m'
              : '$name placeholder',
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        index,
      );
      expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        '/${name.toLowerCase()}',
      );
    }
    container.read(appRouterProvider).go('/discover');
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
  });

  testWidgets('unknown route recovers to Home', (tester) async {
    await mount(tester, location: '/missing');
    expect(find.text('Page not found'), findsOneWidget);
    await tester.tap(find.text('Go to Home'));
    await tester.pumpAndSettle();
    expect(find.text('Home placeholder'), findsOneWidget);
  });

  testWidgets('normal app labels its status and has no gallery route', (
    tester,
  ) async {
    final container = await mount(tester, mode: AppMode.foundation);
    expect(find.text('Foundation only • Not connected'), findsOneWidget);
    expect(find.byTooltip('Component gallery'), findsNothing);
    container.read(appRouterProvider).go('/components');
    await tester.pumpAndSettle();
    expect(find.text('Page not found'), findsOneWidget);
  });

  testWidgets(
    'preview opens gallery outside tabs and back restores selected tab',
    (tester) async {
      await mount(tester, location: '/profile');
      expect(find.text('UI Preview • Local sample data'), findsOneWidget);
      await tester.tap(find.byTooltip('Component gallery'));
      // Gallery intentionally contains indeterminate loading indicators.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Component gallery'), findsOneWidget);
      expect(find.byType(NavigationBar).hitTestable(), findsNothing);
      await tester.tap(find.byTooltip('Back to preview'));
      await tester.pumpAndSettle();
      expect(find.text('Profile placeholder'), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        3,
      );
    },
  );

  testWidgets(
    'gallery validates inputs, toggles password and retries locally',
    (tester) async {
      await mount(tester);
      await tester.tap(find.byTooltip('Component gallery'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.ensureVisible(find.text('Validate sample'));
      await tester.tap(find.text('Validate sample'));
      await tester.pump();
      expect(find.text('Enter a display name.'), findsOneWidget);
      expect(
        find.text('Use at least 8 characters for this sample.'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(AppTextField).first, 'Shanuka');
      await tester.enterText(find.byType(AppTextField).last, 'sample123');
      expect(
        tester.widget<EditableText>(find.byType(EditableText).last).obscureText,
        isTrue,
      );
      await tester.ensureVisible(find.byTooltip('Show password'));
      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      expect(
        tester.widget<EditableText>(find.byType(EditableText).last).obscureText,
        isFalse,
      );
      await tester.ensureVisible(find.text('Validate sample'));
      await tester.tap(find.text('Validate sample'));
      await tester.pump();
      expect(
        find.text('Sample form is valid. Nothing was saved.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Retry'));
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(
        find.text('Sample retry succeeded. No network request was made.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('loading and disabled buttons cannot submit', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Column(
            children: [
              AppButton(
                label: 'Wait',
                isLoading: true,
                onPressed: () => taps++,
              ),
              const AppButton(label: 'Disabled', onPressed: null),
              AppButton(label: 'Ready', onPressed: () => taps++),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Wait…'));
    await tester.tap(find.text('Disabled'));
    expect(taps, 0);
    await tester.tap(find.text('Ready'));
    expect(taps, 1);
  });

  testWidgets('320px layout supports large text and keyboard insets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await mount(tester, textScale: 2);
    expect(
      MediaQuery.textScalerOf(tester.element(find.text('Home placeholder')))
          .scale(16),
      32,
    );
    for (final name in ['Discover', 'Progress', 'Profile', 'Home']) {
      await tester.tap(find.text(name).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.byTooltip('Component gallery'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(find.byType(AppTextField).first);
    await tester.tap(find.byType(AppTextField).first);
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pump();
    await tester.enterText(
      find.byType(AppTextField).first,
      'A long sample display name',
    );
    await tester.ensureVisible(find.text('Validate sample'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
    await tester.pump();
    await tester.ensureVisible(find.text('Retry'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  test('actual theme text pairs meet 4.5:1 contrast', () {
    final scheme = AppTheme.light.colorScheme;
    for (final pair in [
      (scheme.onPrimary, scheme.primary),
      (scheme.primary, scheme.surface),
      (scheme.onSurface, scheme.surface),
      (scheme.onSurface, AppColors.background),
      (scheme.onSurfaceVariant, scheme.surface),
      (scheme.onSurfaceVariant, AppColors.background),
      (scheme.onPrimaryContainer, scheme.primaryContainer),
      (scheme.error, scheme.surface),
      (scheme.error, scheme.errorContainer), // Failed classroom seat action.
    ]) {
      final a = pair.$1.computeLuminance();
      final b = pair.$2.computeLuminance();
      final ratio = a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
      expect(ratio, greaterThanOrEqualTo(4.5));
    }
  });
}
