import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:studymates/app/app.dart';
import 'package:studymates/app/app_mode.dart';
import 'package:studymates/app/router.dart';
import 'package:studymates/core/models/community_models.dart';
import 'package:studymates/core/theme/app_theme.dart';
import 'package:studymates/features/auth/domain/auth_state.dart';
import 'package:studymates/features/auth/presentation/controllers/auth_providers.dart';
import 'package:studymates/features/communities/data/pending_leave_recovery.dart';
import 'package:studymates/features/communities/presentation/controllers/community_providers.dart';
import 'package:studymates/features/communities/presentation/controllers/discovery_connection_provider.dart';
import 'package:studymates/features/communities/presentation/controllers/pending_leave_providers.dart';
import 'package:studymates/features/profile/presentation/controllers/profile_providers.dart';
import 'package:studymates/features/sessions/data/active_session_providers.dart';
import 'package:studymates/features/study/data/study_providers.dart';
import 'package:studymates/preview/preview_repositories.dart';

class _Identity extends AuthStateController {
  @override
  AuthState build() =>
      const AuthState.ready(userId: 'preview-user-1', displayName: 'Learner');
}

class _Recovery extends Fake implements PendingLeaveRecovery {
  int calls = 0;
  final gate = Completer<int>();
  @override
  Future<int> recover() {
    calls++;
    return gate.future;
  }
}

void main() {
  Future<ProviderContainer> mount(
    WidgetTester tester, {
    MemoryCommunityRepository? repository,
    Stream<int> Function()? pending,
    Stream<bool> Function()? connection,
    _Recovery? recovery,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appModeProvider.overrideWithValue(AppMode.connected),
          authStateProvider.overrideWith(_Identity.new),
          currentProfileProvider.overrideWith(
            (ref) => Stream.value(
              UserProfile(id: 'preview-user-1', displayName: 'Learner'),
            ),
          ),
          communityRepositoryProvider.overrideWithValue(
            repository ?? MemoryCommunityRepository(),
          ),
          currentUserActiveSessionProvider.overrideWith(
            (ref) => const AsyncData(null),
          ),
          studyLeaseKeeperProvider.overrideWith((ref) {}),
          pendingLeaveCountProvider.overrideWith(
            (ref) => pending?.call() ?? Stream.value(0),
          ),
          discoveryConnectionProvider.overrideWith(
            (ref) => connection?.call() ?? Stream.value(true),
          ),
          if (recovery != null)
            pendingLeaveRecoveryProvider.overrideWithValue(recovery),
        ],
        child: const StudyMatesApp(),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(StudyMatesApp)),
    );
    container.read(appRouterProvider).go('/discover');
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('normal header, QR, selected navigation and Profile sign-out', (
    tester,
  ) async {
    await mount(tester);
    expect(find.text('Connected • StudyMates'), findsNothing);
    expect(find.byTooltip('Scan invitation'), findsOneWidget);
    expect(find.byTooltip('Sign out'), findsNothing);
    expect(find.text('Find your next study circle'), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    expect(
      Theme.of(tester.element(find.byType(NavigationBar)))
          .navigationBarTheme
          .indicatorColor,
      AppColors.softAccent,
    );
    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Sign out'), findsOneWidget);
  });

  testWidgets(
    'search combines with tabs; result count and clear action stay synchronized',
    (tester) async {
      final repository = MemoryCommunityRepository();
      await repository.setSigMembership('iot', MembershipState.joined);
      await mount(tester, repository: repository);
      expect(find.text('3 communities'), findsOneWidget);
      expect(find.text('Joined'), findsOneWidget);
      expect(find.text('Technology · 1 subgroup'), findsOneWidget);
      final all = tester.getSize(
        find.widgetWithText(TextButton, 'All communities'),
      );
      final mine = tester.getSize(
        find.widgetWithText(TextButton, 'My communities'),
      );
      expect(all.width, mine.width);
      expect(all.height, greaterThanOrEqualTo(48));
      await tap(tester, find.text('My communities'));
      expect(find.text('1 community'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'programming');
      await tester.pumpAndSettle();
      expect(find.text('0 communities'), findsOneWidget);
      expect(find.text('No matches'), findsOneWidget);
      await tap(tester, find.text('All communities'));
      expect(find.text('1 community'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('community-card-programming')),
        findsOneWidget,
      );
      await tap(tester, find.byTooltip('Clear search'));
      expect(find.text('3 communities'), findsOneWidget);
      expect(find.byTooltip('Clear search'), findsNothing);
    },
  );

  testWidgets(
    'whole card and Open/Explore preserve existing detail routes; Create opens existing form',
    (tester) async {
      final repository = MemoryCommunityRepository();
      await repository.setSigMembership('iot', MembershipState.joined);
      final container = await mount(tester, repository: repository);
      await tap(tester, find.byKey(const ValueKey('create-community')));
      expect(find.text('Create a SIG'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Description'), findsOneWidget);
      await tap(tester, find.text('Cancel'));
      await tap(tester, find.byKey(const ValueKey('community-card-iot')));
      expect(container.read(appRouterProvider).state.uri.path, '/sigs/iot');
      container.read(appRouterProvider).go('/discover');
      await tester.pumpAndSettle();
      await tap(
        tester,
        find.descendant(
          of: find.byKey(const ValueKey('community-card-iot')),
          matching: find.text('Open'),
        ),
      );
      expect(container.read(appRouterProvider).state.uri.path, '/sigs/iot');
      container.read(appRouterProvider).go('/discover');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(TextField),
        -250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'programming');
      await tester.pumpAndSettle();
      await tap(tester, find.text('Explore'));
      expect(
        container.read(appRouterProvider).state.uri.path,
        '/sigs/programming',
      );
    },
  );

  testWidgets(
    'pending link appears only for actionable count and recovery prevents duplicate submission',
    (tester) async {
      final changes = StreamController<int>.broadcast();
      addTearDown(changes.close);
      var count = 0;
      final recovery = _Recovery();
      await mount(
        tester,
        pending: () async* {
          yield count;
          yield* changes.stream;
        },
        recovery: recovery,
      );
      expect(find.byKey(const ValueKey('pending-leave-link')), findsNothing);
      count = 1;
      changes.add(count);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('pending-leave-link')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('pending-leave-link')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('pending-leave-link')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(recovery.calls, 1);
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const ValueKey('pending-leave-link')),
            )
            .onPressed,
        isNull,
      );
      count = 0;
      recovery.gate.complete(1);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('pending-leave-link')), findsNothing);
    },
  );

  testWidgets(
    'connection notice appears when unverified and clears on fresh server data',
    (tester) async {
      final changes = StreamController<bool>.broadcast();
      addTearDown(changes.close);
      await mount(
        tester,
        connection: () async* {
          yield true;
          yield* changes.stream;
        },
      );
      expect(find.byTooltip('Retry connection'), findsNothing);
      changes.add(false);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Retry connection'), findsOneWidget);
      changes.add(true);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Retry connection'), findsNothing);
    },
  );

  testWidgets(
    'single-column cards and equal tabs handle 320px with 200 percent text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await mount(tester);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('community-card-design')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      final card = tester.getSize(
        find.byKey(const ValueKey('community-card-design')),
      );
      expect(card.width, 288);
      expect(
        find.text(
          'Design for accessible and inclusive everyday learning experiences',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Search communities'),
        -250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
