import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/community_models.dart';
import '../../../core/models/room_models.dart';
import '../../communities/data/membership_repository.dart';
import 'room_repository.dart';
import 'seat_claim_result.dart';

/// Firestore adapter for the currently proposed room document layout.
///
/// The paths and serialized fields mirror the existing M3 models and the
/// proposal in docs/contracts.md. They remain provisional until M2 approves
/// the schema and matching security rules. Seat claims are deliberately not
/// performed here: they require the trusted callable integration.
final class FirestoreLiveRoomRepository implements LiveRoomRepository {
  FirestoreLiveRoomRepository({
    required MembershipRepository membershipRepository,
    required this.currentUserId,
    RoomDocumentStore? documentStore,
    FirebaseFirestore? firestore,
    DateTime Function()? clock,
  }) : _membership = membershipRepository,
       _documents =
           documentStore ??
           _FirestoreRoomDocumentStore(firestore ?? FirebaseFirestore.instance),
       _clock = clock ?? DateTime.now;

  static const roomsCollection = 'rooms';
  static const seatsCollection = 'seats';
  static const subgroupsCollection = 'subgroups';

  final MembershipRepository _membership;
  final String? Function() currentUserId;
  final RoomDocumentStore _documents;
  final DateTime Function() _clock;

  String _subgroupPath(String subgroupId) =>
      '$subgroupsCollection/${_segment(subgroupId, 'subgroupId')}';

  String _roomsPath(String subgroupId) =>
      '${_subgroupPath(subgroupId)}/$roomsCollection';

  String _roomPath(String subgroupId, String roomId) =>
      '${_roomsPath(subgroupId)}/${_segment(roomId, 'roomId')}';

  String _seatsPath(String subgroupId, String roomId) =>
      '${_roomPath(subgroupId, roomId)}/$seatsCollection';

  @override
  Future<RoomSnapshot> createRoom({
    required String subgroupId,
    required String title,
  }) async {
    final normalizedSubgroupId = subgroupId.trim();
    final normalizedTitle = title.trim();
    if (normalizedSubgroupId.isEmpty || normalizedTitle.isEmpty) {
      throw const RoomRepositoryException(RoomRepositoryError.invalidData);
    }
    _segment(normalizedSubgroupId, 'subgroupId');
    final uid = currentUserId()?.trim();
    if (uid == null || uid.isEmpty) {
      throw const RoomRepositoryException(
        RoomRepositoryError.permissionDenied,
      );
    }

    try {
      // MembershipRepository requires the parent SIG ID. The M2 rules keep a
      // subgroup's parent immutable; eligibility is re-read in the transaction.
      final subgroup = await _documents.getDocument(
        _subgroupPath(normalizedSubgroupId),
      );
      if (subgroup == null) {
        throw const RepositoryException(RepositoryError.notFound);
      }
      final sigId = _requiredString(subgroup, 'sigId');
      final roomId = _documents.newRoomId(_roomsPath(normalizedSubgroupId));
      _segment(roomId, 'roomId');
      final nowUtc = _clock().toUtc();
      final room = RoomSnapshot(
        roomId: roomId,
        subgroupId: normalizedSubgroupId,
        title: normalizedTitle,
        createdBy: uid,
        hostUid: uid,
        status: RoomStatus.waiting,
        createdAt: nowUtc,
        updatedAt: nowUtc,
      );

      final eligibility = await _documents.runTransaction(
        (transaction, firestoreTransaction) async {
          final membership = await _membership
              .verifyRoomEligibilityInTransaction(
                transaction: firestoreTransaction,
                sigId: sigId,
                subgroupId: normalizedSubgroupId,
              );
          if (membership != MembershipCheckResult.member) return membership;

          // M2 completes all four membership reads above before the first write.
          transaction.set(_roomPath(normalizedSubgroupId, roomId),
              RoomFirestoreCodec.serializeRoom(room));
          for (var number = 1; number <= 6; number++) {
            final seat = SeatState(
              seatId: 'seat-$number',
              status: SeatStatus.available,
            );
            transaction.set(
              '${_seatsPath(normalizedSubgroupId, roomId)}/${seat.seatId}',
              RoomFirestoreCodec.serializeSeat(seat),
            );
          }
          return membership;
        },
      );

      switch (eligibility) {
        case MembershipCheckResult.member:
          return room;
        case MembershipCheckResult.nonMember:
          throw const RoomRepositoryException(
            RoomRepositoryError.membershipRequired,
          );
        case MembershipCheckResult.permissionDenied:
          throw const RoomRepositoryException(
            RoomRepositoryError.permissionDenied,
          );
        case MembershipCheckResult.unavailable:
          throw const RoomRepositoryException(RoomRepositoryError.unavailable);
      }
    } on RoomRepositoryException {
      rethrow;
    } on RepositoryException {
      rethrow;
    } on FirebaseException catch (error) {
      throw _roomError(error);
    } on FormatException {
      throw const RoomRepositoryException(RoomRepositoryError.unavailable);
    } on ArgumentError {
      throw const RoomRepositoryException(RoomRepositoryError.invalidData);
    }
  }

  @override
  Future<List<RoomSnapshot>> listRoomSnapshots(String subgroupId) async {
    try {
      final documents = await _documents.listCollection(_roomsPath(subgroupId));
      return List.unmodifiable(documents.map(RoomFirestoreCodec.deserializeRoom));
    } on FirebaseException catch (error) {
      throw _roomError(error);
    } on FormatException {
      throw const RoomRepositoryException(RoomRepositoryError.unavailable);
    }
  }

  @override
  Future<RoomSnapshot?> getRoomSnapshot(String roomId) async {
    try {
      final document = await _documents.getRoomById(roomId);
      return document == null ? null : RoomFirestoreCodec.deserializeRoom(document);
    } on FirebaseException catch (error) {
      throw _roomError(error);
    } on FormatException {
      throw const RoomRepositoryException(RoomRepositoryError.unavailable);
    }
  }

  @override
  Future<List<RoomSummary>> listRooms(String subgroupId) async {
    final rooms = await listRoomSnapshots(subgroupId);
    try {
      return List.unmodifiable(
        await Future.wait(
          rooms.map((room) async {
            final seats = _validatedSeats(
              await _documents.listCollection(
                _seatsPath(room.subgroupId, room.roomId),
              ),
            );
            return _summary(room, seats);
          }),
        ),
      );
    } on FirebaseException catch (error) {
      throw _roomError(error);
    } on FormatException {
      throw const RoomRepositoryException(RoomRepositoryError.unavailable);
    } on ArgumentError {
      throw const RoomRepositoryException(RoomRepositoryError.unavailable);
    }
  }

  @override
  Future<RoomSummary?> getRoom(String id) async {
    final room = await getRoomSnapshot(id);
    if (room == null) return null;
    try {
      final seats = _validatedSeats(
        await _documents.listCollection(_seatsPath(room.subgroupId, room.roomId)),
      );
      return _summary(room, seats);
    } on FirebaseException catch (error) {
      throw _roomError(error);
    } on FormatException {
      throw const RoomRepositoryException(RoomRepositoryError.unavailable);
    } on ArgumentError {
      throw const RoomRepositoryException(RoomRepositoryError.unavailable);
    }
  }

  @override
  Stream<List<RoomSnapshot>> watchRooms(String subgroupId) => _mapStreamErrors(
    _documents
        .watchCollection(_roomsPath(subgroupId))
        .map(
          (documents) => List.unmodifiable(
            documents.map(RoomFirestoreCodec.deserializeRoom),
          ),
        ),
  );

  @override
  Stream<RoomSnapshot?> watchRoom(String roomId) => _mapStreamErrors(
    _documents.watchRoomById(roomId).map(
      (document) => document == null
          ? null
          : RoomFirestoreCodec.deserializeRoom(document),
    ),
  );

  @override
  Stream<List<SeatState>> watchSeats(String roomId) => _mapStreamErrors(
    Stream.multi((sink) {
      var generation = 0;
      StreamSubscription<RoomSnapshot?>? roomSubscription;
      StreamSubscription<List<Map<String, dynamic>>>? seatsSubscription;
      var cancelled = false;

      void bindRoom(RoomSnapshot? room) {
        final currentGeneration = ++generation;
        final previous = seatsSubscription;
        seatsSubscription = null;
        unawaited(() async {
          await previous?.cancel();
          if (cancelled || currentGeneration != generation) return;
          if (room == null) {
            sink.addError(const RoomRepositoryException(
              RoomRepositoryError.unavailable,
            ));
            return;
          }
          seatsSubscription = _documents
              .watchCollection(_seatsPath(room.subgroupId, room.roomId))
              .listen(
                (documents) {
                  try {
                    sink.add(_validatedSeats(documents));
                  } on FormatException {
                    sink.addError(const RoomRepositoryException(
                      RoomRepositoryError.unavailable,
                    ));
                  } on ArgumentError {
                    sink.addError(const RoomRepositoryException(
                      RoomRepositoryError.unavailable,
                    ));
                  }
                },
                onError: (Object error, StackTrace stackTrace) => sink.addError(
                  _roomError(error),
                  stackTrace,
                ),
              );
        }());
      }

      roomSubscription = watchRoom(roomId).listen(
        bindRoom,
        onError: (Object error, StackTrace stackTrace) =>
            sink.addError(error, stackTrace),
      );
      sink.onCancel = () async {
        cancelled = true;
        generation++;
        await roomSubscription?.cancel();
        await seatsSubscription?.cancel();
      };
    }),
  );

  /// Claims are not written directly by this client repository. Until M2's
  /// trusted callable is configured, admission is unavailable.
  @override
  Future<SeatClaimResult> claimSeat({
    required String subgroupId,
    required String roomId,
    required String seatId,
  }) async => const SeatClaimFailed(SeatClaimFailure.unavailable);

  List<SeatState> _validatedSeats(List<Map<String, dynamic>> documents) {
    final seats = documents.map(RoomFirestoreCodec.deserializeSeat).toList();
    return validateSeatCollection(seats);
  }

  RoomSummary _summary(RoomSnapshot room, List<SeatState> seats) =>
      RoomSummary(
        id: room.roomId,
        subgroupId: room.subgroupId,
        title: room.title,
        occupiedSeats: seats
            .where((seat) => seat.status == SeatStatus.occupied)
            .length,
      );

  Stream<T> _mapStreamErrors<T>(Stream<T> source) => source.transform(
    StreamTransformer<T, T>.fromHandlers(
      handleError: (error, stackTrace, sink) =>
          sink.addError(_roomError(error), stackTrace),
    ),
  );
}

/// Provisional codec: field names follow the current M3 models. M2 must approve
/// these persisted names, timestamp encoding and absent-versus-null semantics.
abstract final class RoomFirestoreCodec {
  static Map<String, dynamic> serializeRoom(RoomSnapshot room) => {
    'roomId': room.roomId,
    'subgroupId': room.subgroupId,
    'title': room.title,
    'createdBy': room.createdBy,
    'hostUid': room.hostUid,
    'status': room.status.name,
    'createdAt': Timestamp.fromDate(room.createdAt.toUtc()),
    'updatedAt': Timestamp.fromDate(room.updatedAt.toUtc()),
  };

  static RoomSnapshot deserializeRoom(Map<String, dynamic> data) {
    final createdAt = _date(data, 'createdAt');
    final updatedAt = _date(data, 'updatedAt');
    return RoomSnapshot(
      roomId: _requiredString(data, 'roomId'),
      subgroupId: _requiredString(data, 'subgroupId'),
      title: _requiredString(data, 'title'),
      createdBy: _requiredString(data, 'createdBy'),
      hostUid: _requiredString(data, 'hostUid'),
      status: _roomStatus(data['status']),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static Map<String, dynamic> serializeSeat(SeatState seat) => {
    'seatId': seat.seatId,
    'status': seat.status.name,
    'userId': seat.userId,
    'claimedAt': _timestamp(seat.claimedAt),
    'leaseExpiresAt': _timestamp(seat.leaseExpiresAt),
    'lastRenewedAt': _timestamp(seat.lastRenewedAt),
  };

  static SeatState deserializeSeat(Map<String, dynamic> data) => SeatState(
    seatId: _requiredString(data, 'seatId'),
    status: _seatStatus(data['status']),
    userId: _optionalString(data, 'userId'),
    claimedAt: _optionalDate(data, 'claimedAt'),
    leaseExpiresAt: _optionalDate(data, 'leaseExpiresAt'),
    lastRenewedAt: _optionalDate(data, 'lastRenewedAt'),
  );

  static String _requiredString(Map<String, dynamic> data, String field) {
    final value = data[field];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Missing or invalid $field.');
    }
    return value;
  }

  static String? _optionalString(Map<String, dynamic> data, String field) {
    final value = data[field];
    if (value == null) return null;
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Invalid $field.');
    }
    return value;
  }

  static DateTime _date(Map<String, dynamic> data, String field) =>
      _optionalDate(data, field) ?? (throw FormatException('Missing $field.'));

  static DateTime? _optionalDate(Map<String, dynamic> data, String field) {
    final value = data[field];
    if (value == null) return null;
    if (value is Timestamp) return value.toDate().toUtc();
    if (value is DateTime) return value.toUtc();
    throw FormatException('Invalid $field timestamp.');
  }

  static Timestamp? _timestamp(DateTime? value) =>
      value == null ? null : Timestamp.fromDate(value.toUtc());

  static RoomStatus _roomStatus(Object? value) => switch (value) {
    'waiting' => RoomStatus.waiting,
    'active' => RoomStatus.active,
    'completed' => RoomStatus.completed,
    'closed' => RoomStatus.closed,
    _ => throw const FormatException('Invalid room status.'),
  };

  static SeatStatus _seatStatus(Object? value) => switch (value) {
    'available' => SeatStatus.available,
    'occupied' => SeatStatus.occupied,
    _ => throw const FormatException('Invalid seat status.'),
  };
}

/// Persistence seam used by tests. Production implementation below delegates
/// to Cloud Firestore; it does not define additional persisted fields.
abstract interface class RoomDocumentStore {
  String newRoomId(String roomsPath);
  Future<Map<String, dynamic>?> getDocument(String path);
  Future<Map<String, dynamic>?> getRoomById(String roomId);
  Future<List<Map<String, dynamic>>> listCollection(String path);
  Stream<Map<String, dynamic>?> watchRoomById(String roomId);
  Stream<List<Map<String, dynamic>>> watchCollection(String path);
  Future<T> runTransaction<T>(
    Future<T> Function(RoomWriteTransaction transaction, Transaction firestoreTransaction)
    action,
  );
}

abstract interface class RoomWriteTransaction {
  void set(String path, Map<String, dynamic> data);
}

final class _FirestoreRoomDocumentStore implements RoomDocumentStore {
  _FirestoreRoomDocumentStore(this._firestore);
  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _document(String path) =>
      _firestore.doc(path);

  @override
  String newRoomId(String roomsPath) => _firestore.collection(roomsPath).doc().id;

  @override
  Future<Map<String, dynamic>?> getDocument(String path) async =>
      (await _document(path).get()).data();

  @override
  Future<Map<String, dynamic>?> getRoomById(String roomId) async {
    final matches = await _firestore
        .collectionGroup(FirestoreLiveRoomRepository.roomsCollection)
        .where('roomId', isEqualTo: roomId)
        .limit(2)
        .get();
    if (matches.docs.length > 1) {
      throw const FormatException('Room ID is not globally unique.');
    }
    return matches.docs.isEmpty ? null : matches.docs.single.data();
  }

  @override
  Future<List<Map<String, dynamic>>> listCollection(String path) async =>
      (await _firestore.collection(path).get()).docs
          .map((document) => document.data())
          .toList(growable: false);

  @override
  Stream<Map<String, dynamic>?> watchRoomById(String roomId) => _firestore
      .collectionGroup(FirestoreLiveRoomRepository.roomsCollection)
      .where('roomId', isEqualTo: roomId)
      .limit(2)
      .snapshots()
      .map((snapshot) {
        if (snapshot.docs.length > 1) {
          throw const FormatException('Room ID is not globally unique.');
        }
        return snapshot.docs.isEmpty ? null : snapshot.docs.single.data();
      });

  @override
  Stream<List<Map<String, dynamic>>> watchCollection(String path) =>
      _firestore.collection(path).snapshots().map(
        (snapshot) => snapshot.docs
            .map((document) => document.data())
            .toList(growable: false),
      );

  @override
  Future<T> runTransaction<T>(
    Future<T> Function(RoomWriteTransaction transaction, Transaction firestoreTransaction)
    action,
  ) => _firestore.runTransaction(
    (transaction) => action(
      _FirestoreRoomWriteTransaction(_firestore, transaction),
      transaction,
    ),
  );
}

final class _FirestoreRoomWriteTransaction implements RoomWriteTransaction {
  _FirestoreRoomWriteTransaction(this._firestore, this._transaction);
  final FirebaseFirestore _firestore;
  final Transaction _transaction;

  @override
  void set(String path, Map<String, dynamic> data) => _transaction.set(
    _firestore.doc(path),
    data,
  );
}

String _segment(String value, String field) {
  if (value.trim().isEmpty || value.contains('/')) {
    throw ArgumentError.value(value, field, 'Must be a non-empty path segment.');
  }
  return value;
}

String _requiredString(Map<String, dynamic> data, String field) {
  final value = data[field];
  if (value is! String || value.trim().isEmpty) {
    throw const FormatException('Malformed subgroup document.');
  }
  return value;
}

RoomRepositoryException _roomError(Object error) {
  if (error is RoomRepositoryException) return error;
  if (error is FirebaseException &&
      (error.code == 'permission-denied' || error.code == 'unauthenticated')) {
    return const RoomRepositoryException(RoomRepositoryError.permissionDenied);
  }
  return const RoomRepositoryException(RoomRepositoryError.unavailable);
}
