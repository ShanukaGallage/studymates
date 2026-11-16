import 'package:cloud_firestore/cloud_firestore.dart';

import '../../study/data/firestore_study_repository.dart';
import 'spark_membership_cleanup.dart';

/// Read only the current account's requests and matching membership. A completed
/// cleanup can still be actionable when finalization was interrupted.
class PendingLeaveRecovery {
  PendingLeaveRecovery(this.study);
  final FirestoreStudyRepository study;

  Stream<int> watchActionableCount() async* {
    final user = study.uid;
    final requests = study.db
        .collection('membershipCleanupRequests')
        .where('userId', isEqualTo: user);
    await for (final snapshot in requests.snapshots()) {
      final actionable = await Future.wait(
        snapshot.docs.map((doc) async {
          final request = doc.data();
          if (request['status'] != 'pending' &&
              request['status'] != 'completed') {
            return false;
          }
          final scope = request['scope'];
          final id = scope == 'sig' ? request['sigId'] : request['subgroupId'];
          if (id is! String || (scope != 'sig' && scope != 'subgroup')) {
            return false;
          }
          final member = await study.db
              .doc('${scope == 'sig' ? 'sigs' : 'subgroups'}/$id/members/$user')
              .get(const GetOptions(source: Source.server));
          return isActionableLeaveRequest(
            user: user,
            requestId: doc.id,
            request: request,
            membership: member.data(),
          );
        }),
      );
      if (study.currentUid() != user) return;
      yield actionable.where((value) => value).length;
    }
  }

  Future<int> recover() => SparkMembershipCleanup(study).resumeAll();
}

bool isActionableLeaveRequest({
  required String user,
  required String requestId,
  required Map<String, dynamic> request,
  required Map<String, dynamic>? membership,
}) =>
    request['userId'] == user &&
    (request['status'] == 'pending' || request['status'] == 'completed') &&
    membership?['status'] == 'removalPending' &&
    membership?['removalRequestId'] == requestId;
