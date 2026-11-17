import '../../../core/models/completion_record.dart';
import '../domain/common_hall_models.dart';

abstract interface class CommonHallRepository {
  Stream<HallSession?> watchCurrentSession();
  Stream<List<HallParticipant>> watchParticipants();
  Future<HallSession?> getCurrentSession();
  Future<HallSession> enter({required String goalText});
  Future<HallSession> renew(String expectedSessionId);
  Future<CompletionRecord> finish({
    required String expectedSessionId,
    required GoalOutcome goalOutcome,
  });
}

class HallFailure implements Exception {
  const HallFailure(this.message);
  final String message;
  @override
  String toString() => message;
}
