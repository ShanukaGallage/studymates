import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:studymates/features/invites/presentation/screens/room_invitations_screen.dart';
import 'package:studymates/features/study/data/firestore_invitation_service.dart';

class _Invitations implements FirestoreInvitationService {
  final changes = StreamController<RoomInvitation>.broadcast();
  bool fail = false;
  int revocations = 0;
  RoomInvitation current = RoomInvitation(
    token: 'ABCDEFGHJK23MNPQ',
    expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
    revoked: false,
  );
  @override
  Stream<RoomInvitation?> watchInvitation(String token) async* {
    yield current;
    yield* changes.stream;
  }

  @override
  Future<void> revokeInvitation(String token) async {
    revocations++;
    if (fail) throw StateError('offline');
    markRevoked();
  }

  void markRevoked() {
    current = RoomInvitation(
      token: current.token,
      expiresAt: current.expiresAt,
      revoked: true,
    );
    changes.add(current);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<_Invitations> open(WidgetTester tester) async {
    final service = _Invitations();
    addTearDown(service.changes.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firestoreInvitationServiceProvider.overrideWithValue(service),
        ],
        child: const MaterialApp(
          home: ManagedInvitationScreen(
            token: 'ABCDEFGHJK23MNPQ',
            roomTitle: 'Study room',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return service;
  }

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'revocation requires confirmation and failed request remains retryable',
    (tester) async {
      final service = await open(tester);
      expect(find.byType(QrImageView), findsOneWidget);
      await tap(tester, 'Revoke invitation');
      expect(service.revocations, 0);
      await tap(tester, 'Keep code');
      expect(service.revocations, 0);
      service.fail = true;
      await tap(tester, 'Revoke invitation');
      await tap(tester, 'Revoke code');
      expect(
        find.textContaining('Revocation could not be confirmed'),
        findsOneWidget,
      );
      expect(find.byType(QrImageView), findsOneWidget);
      service.fail = false;
      await tap(tester, 'Revoke invitation');
      await tap(tester, 'Revoke code');
      expect(find.text('Invitation revoked'), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('Share invitation'), findsNothing);
    },
  );

  testWidgets(
    'remote revocation immediately removes the displayed QR and sharing',
    (tester) async {
      final service = await open(tester);
      service.markRevoked();
      await tester.pumpAndSettle();
      expect(find.text('Invitation revoked'), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('Share invitation'), findsNothing);
    },
  );
}
