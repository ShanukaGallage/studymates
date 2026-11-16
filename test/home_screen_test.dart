import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:studymates/app/app.dart';
import 'package:studymates/app/app_mode.dart';
import 'package:studymates/features/auth/domain/auth_state.dart';
import 'package:studymates/features/auth/presentation/controllers/auth_providers.dart';
import 'package:studymates/app/router.dart';
import 'package:studymates/core/models/community_models.dart';
import 'package:studymates/features/communities/presentation/controllers/community_providers.dart';
import 'package:studymates/preview/preview_scope.dart';
import 'package:studymates/preview/preview_repositories.dart';

class _HomeIdentity extends AuthStateController {
  @override
  AuthState build() => const AuthState.ready(userId: 'one', displayName: 'One');
  void changeUser(String id) =>
      state = AuthState.ready(userId: id, displayName: id);
}

class _CountingCatalog extends MemoryCommunityRepository {
  int loads = 0;
  @override
  Future<CommunityCatalog> loadCatalog() {
    loads++;
    return super.loadCatalog();
  }
}

void main() {
  test(
    'connected catalog reloads when the authenticated account changes',
    () async {
      final repository = _CountingCatalog();
      final container = ProviderContainer(
        overrides: [
          appModeProvider.overrideWithValue(AppMode.connected),
          authStateProvider.overrideWith(_HomeIdentity.new),
          communityRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        communityCatalogProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await container.read(communityCatalogProvider.future);
      expect(repository.loads, 1);
      (container.read(authStateProvider.notifier) as _HomeIdentity).changeUser(
        'two',
      );
      await container.read(communityCatalogProvider.future);
      expect(repository.loads, 2);
    },
  );

  Future<ProviderContainer> mount(WidgetTester tester) async {
    await tester.pumpWidget(const PreviewScope(child: StudyMatesApp()));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(StudyMatesApp)),
    );
  }

  testWidgets(
    'Home follows shared memberships and opens the existing community route',
    (tester) async {
      final container = await mount(tester);
      expect(find.text('Hello, Alex (sample)'), findsOneWidget);
      expect(find.text('Find your study circle'), findsOneWidget);
      await container
          .read(communityCatalogProvider.notifier)
          .setSigMembership('iot', MembershipState.joined);
      await tester.pumpAndSettle();
      expect(find.text('Find your study circle'), findsNothing);
      await tester.scrollUntilVisible(find.text('IoT'), 150);
      await tester.pumpAndSettle();
      await tester.tap(find.text('IoT'));
      await tester.pumpAndSettle();
      expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        '/sigs/iot',
      );
    },
  );

  testWidgets('Home error retries without inventing empty membership', (
    tester,
  ) async {
    final container = await mount(tester);
    container
        .read(previewScenarioProvider.notifier)
        .select(PreviewScenario.errorOnce);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Could not load your communities.'),
      150,
    );
    expect(find.text('Find your study circle'), findsNothing);
    await tester.ensureVisible(find.text('Retry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Find your study circle'), findsOneWidget);
    container
        .read(previewScenarioProvider.notifier)
        .select(PreviewScenario.loading);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Loading your communities…'), findsOneWidget);
    expect(find.text('Find your study circle'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Home large text at 320px keeps its actions scrollable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final container = await mount(tester);
    await tester.scrollUntilVisible(find.text('Explore communities'), 160);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore communities'));
    await tester.pumpAndSettle();
    expect(
      container.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/discover',
    );
    expect(tester.takeException(), isNull);
  });
}
