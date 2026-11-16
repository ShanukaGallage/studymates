import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:studymates/core/theme/app_theme.dart';
import 'package:studymates/features/invites/data/invitation_service.dart';
import 'package:studymates/features/invites/data/invitation_token.dart';
import 'package:studymates/features/invites/presentation/controllers/invitation_providers.dart';
import 'package:studymates/features/invites/presentation/screens/invitation_display_screen.dart';
import 'package:studymates/features/invites/presentation/screens/invitation_preview_screen.dart';
import 'package:studymates/preview/invitation_fixtures.dart';
import 'package:studymates/preview/invites_flow_fixtures.dart';
import 'package:studymates/preview/invites_flow_preview.dart';

class _Service extends InvitesFlowFixtureService {
  _Service([super.scenario = InvitesFlowScenario.valid]);
  int admissions = 0;
  bool? consent;
  Completer<InvitationAdmissionResult>? gate;
  @override
  Future<InvitationAdmissionResult> admitInvitation({
    required String opaqueToken,
    required bool membershipConsentGranted,
  }) {
    admissions++;
    consent = membershipConsentGranted;
    return gate?.future ??
        super.admitInvitation(
          opaqueToken: opaqueToken,
          membershipConsentGranted: membershipConsentGranted,
        );
  }
}

void main() {
  Future<void> open(
    WidgetTester tester,
    _Service service, {
    ValueChanged<InvitationPreview>? onAdmitted,
    Future<void> Function(InvitationPreview)? membership,
    bool large = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [invitationServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(large ? 2 : 1)),
            child: child!,
          ),
          home: InvitationPreviewScreen(
            opaqueToken: service.token,
            isFixture: true,
            onAdmitted: onAdmitted,
            onRequestMembership: membership,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.pumpAndSettle();
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  testWidgets('QR display and manual code resolve to the same opaque token', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const InvitationDisplayScreen(
          opaqueToken: InvitationFixtures.validToken,
          roomTitle: 'ESP32 room',
          isFixture: true,
        ),
      ),
    );
    expect(find.byType(QrImageView), findsOneWidget);
    final display = tester.widget<InvitationDisplayScreen>(
      find.byType(InvitationDisplayScreen),
    );
    expect(
      InvitationTokenParser.parseQr(display.qrPayload),
      InvitationFixtures.validToken,
    );
    expect(find.text('ABCD-EFGH-JK23-MNPQ'), findsOneWidget);
    expect(
      InvitationTokenParser.parseManual('abcd-efgh-jk23-mnpq'),
      InvitationFixtures.validToken,
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: InvitationDisplayScreen(opaqueToken: 'bad', roomTitle: 'Room'),
      ),
    );
    expect(find.byType(QrImageView), findsNothing);
  });

  testWidgets(
    'preview never auto-joins; repeated Join taps return one admission callback',
    (tester) async {
      final service = _Service()..gate = Completer<InvitationAdmissionResult>();
      var callbacks = 0;
      await open(tester, service, onAdmitted: (_) => callbacks++);
      expect(find.text('ESP32 Study Room'), findsOneWidget);
      expect(find.text('Study group: IoT Study Group'), findsOneWidget);
      expect(find.text('Subgroup: ESP32'), findsOneWidget);
      expect(service.admissions, 0);
      await tester.ensureVisible(find.text('Join room'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Join room'));
      await tester.tap(find.text('Join room'));
      await tester.pump();
      expect(service.admissions, 1);
      service.gate!.complete(
        const InvitationAdmissionResult(InvitationAdmissionStatus.admitted),
      );
      await tester.pumpAndSettle();
      expect(callbacks, 1);
      expect(find.textContaining('No live seat was reserved'), findsOneWidget);
      expect(find.text('Join room'), findsNothing);
    },
  );

  for (final scenario in [
    InvitesFlowScenario.invalid,
    InvitesFlowScenario.expired,
    InvitesFlowScenario.revoked,
    InvitesFlowScenario.fullRoom,
    InvitesFlowScenario.unavailable,
  ]) {
    testWidgets('${scenario.name} cannot join', (tester) async {
      final service = _Service(scenario);
      await open(tester, service);
      expect(find.text('Join room'), findsNothing);
      expect(find.text('Recheck invitation'), findsOneWidget);
      expect(service.admissions, 0);
    });
  }

  testWidgets(
    'membership requires explicit consent, an owner callback and revalidation',
    (tester) async {
      final service = _Service(InvitesFlowScenario.membershipRequired);
      var enrollments = 0;
      await open(
        tester,
        service,
        membership: (preview) async {
          enrollments++;
          await service.completeMembershipForPreview(preview);
        },
      );
      expect(find.text('Join room'), findsNothing);
      await tap(tester, 'Continue to membership');
      expect(enrollments, 0);
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      expect(service.admissions, 0);
      await tap(tester, 'Continue to membership');
      expect(enrollments, 1);
      await tap(tester, 'Join room');
      expect(service.consent, isTrue);
      expect(service.admissions, 1);
    },
  );

  testWidgets('consent alone never joins without a membership callback', (
    tester,
  ) async {
    final service = _Service(InvitesFlowScenario.membershipRequired);
    await open(tester, service);
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tap(tester, 'Continue to membership');
    expect(service.admissions, 0);
    expect(
      find.textContaining('Membership navigation is not connected'),
      findsOneWidget,
    );
  });

  testWidgets(
    'room becomes full after preview without a successful admission',
    (tester) async {
      final service = _Service(InvitesFlowScenario.seatRace);
      var callbacks = 0;
      await open(tester, service, onAdmitted: (_) => callbacks++);
      await tap(tester, 'Join room');
      expect(callbacks, 0);
      expect(find.textContaining('room became full'), findsOneWidget);
      await tap(tester, 'Recheck invitation');
      expect(find.text('Join room'), findsNothing);
      expect(service.admissions, 1);
    },
  );

  testWidgets('lookup error retries and admission error requires recheck', (
    tester,
  ) async {
    await open(tester, _Service(InvitesFlowScenario.networkError));
    expect(
      find.textContaining('Could not check this invitation'),
      findsOneWidget,
    );
    await tap(tester, 'Retry');
    expect(find.text('Join room'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await open(tester, _Service(InvitesFlowScenario.admissionError));
    await tap(tester, 'Join room');
    expect(find.textContaining('Could not confirm admission'), findsOneWidget);
    await tap(tester, 'Recheck invitation');
    await tap(tester, 'Join room');
    expect(
      find.textContaining('Fixture admission returned admitted'),
      findsOneWidget,
    );
  });

  testWidgets('leaving during admission suppresses late callbacks', (
    tester,
  ) async {
    final service = _Service()..gate = Completer<InvitationAdmissionResult>();
    var callbacks = 0;
    await open(tester, service, onAdmitted: (_) => callbacks++);
    await tester.ensureVisible(find.text('Join room'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Join room'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    service.gate!.complete(
      const InvitationAdmissionResult(InvitationAdmissionStatus.admitted),
    );
    await tester.pumpAndSettle();
    expect(callbacks, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long names wrap on 320px screens at twice text size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await open(tester, _Service(InvitesFlowScenario.longText), large: true);
    await tap(tester, 'Join room');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'manual launcher rejects URLs and opens preview without admission',
    (tester) async {
      await tester.pumpWidget(const InvitesFlowPreview());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'https://example.com');
      await tap(tester, 'Preview typed code');
      expect(find.text('Enter a valid 16-character code.'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField),
        ' abcd-efgh-jk23-mnpq ',
      );
      await tap(tester, 'Preview typed code');
      expect(find.text('ESP32 Study Room'), findsOneWidget);
      expect(find.text('Join room'), findsOneWidget);
    },
  );
}
