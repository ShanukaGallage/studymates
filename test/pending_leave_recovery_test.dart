import 'package:flutter_test/flutter_test.dart';
import 'package:studymates/features/communities/data/pending_leave_recovery.dart';

void main() {
  test('pending and acknowledged-but-unfinalized leaves are actionable; old/completed memberships are not', () {
    bool actionable(
      String status,
      Map<String, dynamic>? membership, {
      String user = 'one',
    }) => isActionableLeaveRequest(
      user: user,
      requestId: 'request',
      request: {'userId': 'one', 'status': status},
      membership: membership,
    );
    final pending = {'status': 'removalPending', 'removalRequestId': 'request'};
    expect(actionable('pending', pending), isTrue);
    expect(actionable('completed', pending), isTrue);
    expect(
      actionable('completed', {
        'status': 'left',
        'removalRequestId': 'request',
      }),
      isFalse,
    );
    expect(actionable('pending', {'status': 'active'}), isFalse);
    expect(
      actionable('pending', {
        'status': 'removalPending',
        'removalRequestId': 'new-request',
      }),
      isFalse,
    );
    expect(actionable('pending', pending, user: 'another-account'), isFalse);
    expect(actionable('pending', null), isFalse);
  });
}
