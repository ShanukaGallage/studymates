// SDK query/snapshot interfaces are faked only to exercise the real reader.
// ignore_for_file: subtype_of_sealed_class

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studymates/features/communities/data/membership_repository.dart';
import 'package:studymates/features/study/data/firestore_study_repository.dart';

// In-memory Firestore query double: runs the actual reader's ordering, cursor,
// path and limit against data. It does not prove deployed indexes/security rules.
class _Db extends Fake implements FirebaseFirestore {
  final rows = <String, List<_Doc>>{};
  Completer<void>? gate;
  final reads = <String>[];

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Query(this, path);
}

class _Doc extends Fake implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _Doc(this.id, this.value);
  @override
  final String id;
  final Map<String, dynamic> value;
  @override
  Map<String, dynamic> data() => value;
}

class _Snapshot extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  _Snapshot(this.docs);
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
}

class _Query extends Fake implements CollectionReference<Map<String, dynamic>> {
  _Query(
    this.db,
    this.path, {
    this.orders = const [],
    this.after,
    this.maximum,
  });
  final _Db db;
  @override
  final String path;
  final List<(Object, bool)> orders;
  final List<Object?>? after;
  final int? maximum;

  @override
  Query<Map<String, dynamic>> orderBy(Object field, {bool descending = false}) {
    return _Query(
      db,
      path,
      orders: [...orders, (field, descending)],
      after: after,
      maximum: maximum,
    );
  }

  @override
  Query<Map<String, dynamic>> limit(int count) {
    return _Query(db, path, orders: orders, after: after, maximum: count);
  }

  @override
  Query<Map<String, dynamic>> startAfter(Iterable<Object?> values) {
    return _Query(
      db,
      path,
      orders: orders,
      after: values.toList(),
      maximum: maximum,
    );
  }

  Object value(_Doc doc, Object field) =>
      field == FieldPath.documentId ? doc.id : doc.value[field]!;

  int compare(Object a, Object b) => a is Timestamp
      ? a.compareTo(b as Timestamp)
      : (a as String).compareTo(b as String);

  int compareDocs(_Doc a, _Doc b) {
    for (final (field, descending) in orders) {
      final result = compare(value(a, field), value(b, field));
      if (result != 0) return descending ? -result : result;
    }
    return 0;
  }

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    expect(options?.source, Source.server);
    db.reads.add(path);
    final docs = [...db.rows[path] ?? <_Doc>[]]..sort(compareDocs);
    final cursor = after;
    final filtered = cursor == null
        ? docs
        : docs.where((doc) {
            expect(cursor.length, orders.length);
            for (var i = 0; i < orders.length; i++) {
              final (field, descending) = orders[i];
              var result = compare(value(doc, field), cursor[i]!);
              if (descending) result = -result;
              if (result != 0) return result > 0;
            }
            return false;
          }).toList();
    await db.gate?.future;
    return _Snapshot(filtered.take(maximum ?? filtered.length).toList());
  }
}

class _Membership extends Fake implements MembershipRepository {}

List<_Doc> _records(String user, int count) => List.generate(count, (i) {
  final id = 'record-${i.toString().padLeft(3, '0')}';
  // IDs are inverse chronological; 40 equal timestamps span a 30-row boundary.
  final timestamp = i < 40
      ? Timestamp(1800000000, 123456789)
      : Timestamp(1900000000 + i, 987654321);
  return _Doc(id, {
    'recordId': id,
    'sessionId': id,
    'userId': user,
    'goalText': 'Read',
    'endedAt': timestamp,
    'creditedSeconds': i + 1,
    'timerStatus': i.isEven ? 'completed' : 'endedEarly',
    'goalOutcome': 'unfinished',
    'isDemo': i % 7 == 0,
  });
});

void main() {
  late _Db db;
  late String? user;
  late FirestoreStudyRepository repository;
  setUp(() {
    db = _Db();
    user = 'a';
    db.rows['users/a/completions'] = _records('a', 75);
    db.rows['users/b/completions'] = _records('b', 3);
    repository = FirestoreStudyRepository(
      db: db,
      membership: _Membership(),
      currentUid: () => user,
    );
  });

  test(
    'one hour in a room plus two hours self study totals three hours',
    () async {
      Map<String, dynamic> completion(
        String id,
        int seconds, {
        bool demo = false,
      }) => {
        'recordId': id,
        'sessionId': id,
        'userId': 'a',
        'goalText': 'Study',
        'endedAt': Timestamp(1800000000, 0),
        'creditedSeconds': seconds,
        'timerStatus': 'completed',
        'goalOutcome': 'unfinished',
        'isDemo': demo,
      };
      db.rows['users/a/completions'] = [
        _Doc('room-one', completion('room-one', 3600)),
        _Doc('hall-two', completion('hall-two', 7200)),
        _Doc('demo', completion('demo', 60, demo: true)),
      ];
      final summary = await repository.loadCurrentUserSummary();
      expect(summary.creditedSeconds, 10800);
      expect(summary.completedSessionCount, 2);
    },
  );

  test(
    '75 records: newest first, equal timestamp boundary, no gaps or duplicates',
    () async {
      final expected = [...db.rows['users/a/completions']!]
        ..sort((a, b) {
          final byDate = (b.value['endedAt'] as Timestamp).compareTo(
            a.value['endedAt'] as Timestamp,
          );
          return byDate == 0 ? b.id.compareTo(a.id) : byDate;
        });
      final result = <String>[];
      String? token;
      final sizes = <int>[];
      do {
        final page = await repository.loadCurrentUserHistoryPage(
          pageToken: token,
        );
        sizes.add(page.records.length);
        expect(page.records.every((record) => record.userId == 'a'), isTrue);
        result.addAll(page.records.map((record) => record.recordId));
        token = page.nextPageToken;
        expect(sizes.length, lessThanOrEqualTo(3));
      } while (token != null);
      expect(sizes, [30, 30, 15]);
      expect(result, expected.map((doc) => doc.id).toList());
      expect(result.toSet(), hasLength(75));
    },
  );

  test('cursor does not depend on anchor document still existing', () async {
    final page = await repository.loadCurrentUserHistoryPage();
    final anchor = page.records.last.recordId;
    db.rows['users/a/completions']!.removeWhere((doc) => doc.id == anchor);
    final next = await repository.loadCurrentUserHistoryPage(
      pageToken: page.nextPageToken,
    );
    expect(next.records, hasLength(30));
    expect(
      next.records.any(
        (record) => page.records.any((old) => old.recordId == record.recordId),
      ),
      isFalse,
    );
  });

  test('foreign, legacy and malformed cursors fail before a read', () async {
    final token =
        (await repository.loadCurrentUserHistoryPage()).nextPageToken!;
    user = 'b';
    final reads = db.reads.length;
    for (final bad in [token, 'record-030', '%%%']) {
      await expectLater(
        repository.loadCurrentUserHistoryPage(pageToken: bad),
        throwsA(isA<StudyFailure>()),
      );
    }
    expect(db.reads, hasLength(reads));
    final own = await repository.loadCurrentUserHistoryPage();
    expect(own.records, hasLength(3));
    expect(own.records.every((record) => record.userId == 'b'), isTrue);
  });

  test(
    'account changes/sign-out during read cannot publish prior account data',
    () async {
      for (final nextUser in <String?>['b', null]) {
        user = 'a';
        db.gate = Completer<void>();
        final pending = repository.loadCurrentUserHistoryPage();
        final assertion = expectLater(pending, throwsA(isA<StudyFailure>()));
        user = nextUser;
        db.gate!.complete();
        await assertion;
      }
    },
  );

  test('summary stays complete and demo-excluded across pagination', () async {
    final normal = db.rows['users/a/completions']!
        .where((doc) => doc.value['isDemo'] == false)
        .toList();
    final before = await repository.loadCurrentUserSummary();
    final page = await repository.loadCurrentUserHistoryPage();
    expect(page.records.any((record) => record.isDemo), isTrue);
    await repository.loadCurrentUserHistoryPage(pageToken: page.nextPageToken);
    final after = await repository.loadCurrentUserSummary();
    expect(
      after.creditedSeconds,
      normal.fold<int>(
        0,
        (total, doc) => total + (doc.value['creditedSeconds'] as int),
      ),
    );
    expect(
      after.completedSessionCount,
      normal.where((doc) => doc.value['timerStatus'] == 'completed').length,
    );
    expect(after.creditedSeconds, before.creditedSeconds);
    expect(after.completedSessionCount, before.completedSessionCount);
  });
}
