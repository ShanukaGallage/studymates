import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:studymates/app/app.dart';
import 'package:studymates/app/router.dart';
import 'package:studymates/core/models/community_models.dart';
import 'package:studymates/features/communities/presentation/controllers/community_providers.dart';
import 'package:studymates/preview/preview_scope.dart';

void main() {
  testWidgets(
    'joined filter, shared memberships and search compose without losing state',
    (tester) async {
      await tester.pumpWidget(const PreviewScope(child: StudyMatesApp()));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(StudyMatesApp)),
      );
      container.read(appRouterProvider).go('/discover');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('My communities'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('My communities'));
      await tester.pumpAndSettle();
      expect(find.text('Your study circle starts here'), findsOneWidget);
      await container
          .read(communityCatalogProvider.notifier)
          .setSigMembership('iot', MembershipState.joined);
      await tester.pumpAndSettle();
      expect(find.text('Explore IoT'), findsOneWidget);
      expect(find.text('Explore Programming'), findsNothing);
      await tester.ensureVisible(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Programming');
      await tester.pumpAndSettle();
      expect(find.text('No matches'), findsOneWidget);
      await tester.ensureVisible(find.text('All communities'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All communities'));
      await tester.pumpAndSettle();
      expect(find.text('Explore Programming'), findsOneWidget);
      expect(find.text('Explore IoT'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
