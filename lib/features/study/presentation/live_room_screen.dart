import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/controllers/auth_providers.dart';
import '../../rooms/data/seat_claim_result.dart';
import '../../rooms/presentation/widgets/goal_sheet.dart';
import '../../rooms/presentation/widgets/room_scene.dart';
import '../../rooms/presentation/widgets/room_scene_models.dart';
import '../data/firestore_study_repository.dart';
import '../../invites/presentation/screens/invitation_display_screen.dart';
import '../data/firestore_invitation_service.dart';

class LiveRoomScreen extends ConsumerStatefulWidget {
  const LiveRoomScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<LiveRoomScreen> createState() => _LiveRoomScreenState();
}

class _LiveRoomScreenState extends ConsumerState<LiveRoomScreen> {
  late Future<Map<String, dynamic>> _location;
  bool _busy = false, _demo = true;
  String _goal = '', _message = '';
  int? _pendingSeat;
  Timer? _tick;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _roomStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _seatsStream;
  @override
  void initState() {
    super.initState();
    _load();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _load() {
    final repo = ref.read(studyRepositoryProvider);
    _location = repo.locator(widget.id).then((place) {
      _roomStream = repo.watchRoomDocument(place['subgroupId'], widget.id);
      _seatsStream = repo.watchSeatDocuments(place['subgroupId'], widget.id);
      return place;
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = '';
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(
          () => _message = error is StudyFailure ? error.message : 'Could not confirm the operation. Check your connection and retry.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _pendingSeat = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _location,
    builder: (context, location) {
      if (location.hasError) {
        return ErrorView(
          message: 'Room unavailable.',
          onRetry: () => setState(_load),
        );
      }
      if (!location.hasData) return const LoadingView(message: 'Opening room…');
      final subgroup = location.data!['subgroupId'] as String;
      final repo = ref.read(studyRepositoryProvider);
      final user = ref.watch(authStateProvider).userId;
      return StreamBuilder(
        stream: _roomStream,
        builder: (context, roomSnapshot) {
          if (roomSnapshot.hasError) {
            return ErrorView(
              message: 'Room connection failed.',
              onRetry: () => setState(_load),
            );
          }
          final room = roomSnapshot.data?.data();
          if (room == null) return const LoadingView(message: 'Loading room…');
          return StreamBuilder(
            stream: _seatsStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ErrorView(
                  message: 'Seat updates unavailable.',
                  onRetry: () => setState(_load),
                );
              }
              if (!snapshot.hasData) {
                return const LoadingView(message: 'Loading seats…');
              }
              final cached =
                  snapshot.data!.metadata.isFromCache ||
                  roomSnapshot.data!.metadata.isFromCache;
              final documents = snapshot.data!.docs;
              final own = documents
                  .where((d) => d.data()['userId'] == user)
                  .firstOrNull
                  ?.data();
              final ownValid =
                  own != null &&
                  time(own['leaseExpiresAt']).isAfter(DateTime.now().toUtc());
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextButton(
                    onPressed: () => context.go('/subgroups/$subgroup'),
                    child: const Text('Back to subgroup'),
                  ),
                  Text(
                    room['title'],
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    room['hostUid'] == user
                        ? 'You host this room'
                        : 'Shared study room',
                  ),
                  if (cached)
                    const Text(
                      'Connection unverified. Showing cached seats; actions are disabled.',
                    ),
                  if (own != null && !ownValid)
                    const Text(
                      'Your lease expired. Release the old seat, then choose again.',
                    ),
                  const SizedBox(height: 16),
                  RoomScene(
                    selectionEnabled: !_busy && !cached,
                    seats: [
                      for (var number = 1; number <= 6; number++)
                        _seat(number, documents, user),
                    ],
                    onSeatTap: (number) => _run(() async {
                      _pendingSeat = number;
                      final result = await repo.claimSeat(
                        subgroupId: subgroup,
                        roomId: widget.id,
                        seatId: 'seat-$number',
                      );
                      if (result is SeatClaimFailed) {
                        throw StudyFailure(
                          'Seat not confirmed: ${result.failure.name}. Try another seat or retry.',
                        );
                      }
                    }),
                  ),
                  if (_message.isNotEmpty)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _message,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(_goal.isEmpty ? 'Set one small study goal.' : _goal),
                  AppButton(
                    label: 'Set study goal',
                    variant: AppButtonVariant.secondary,
                    onPressed: _busy
                        ? null
                        : () async {
                            final goal = await showPreviewGoalSheet(
                              context,
                              _goal,
                            );
                            if (mounted && goal != null) {
                              setState(() => _goal = goal);
                            }
                          },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('60-second demo cycle'),
                    subtitle: const Text(
                      '45s focus + 15s break. Demo credit stays outside normal totals.',
                    ),
                    value: _demo,
                    onChanged: _busy ? null : (v) => setState(() => _demo = v),
                  ),
                  AppButton(
                    label: room['hostUid'] == user
                        ? 'Start or join shared cycle'
                        : 'Join current cycle',
                    isLoading: _busy,
                    onPressed: !cached && ownValid && _goal.isNotEmpty
                        ? () => _run(() async {
                            await repo.beginSession(
                              subgroup: subgroup,
                              room: widget.id,
                              seat: own['seatId'],
                              claimId: own['claimId'],
                              goal: _goal,
                              demo: _demo,
                            );
                            if (context.mounted) context.push('/session');
                          })
                        : null,
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    label: 'Show room invitation',
                    variant: AppButtonVariant.secondary,
                    onPressed: _busy || cached
                        ? null
                        : () => _run(() async {
                            final token = await ref
                                .read(firestoreInvitationServiceProvider)
                                .issue(subgroup, widget.id);
                            if (context.mounted) {
                              Navigator.of(context, rootNavigator: true).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => InvitationDisplayScreen(
                                    opaqueToken: token,
                                    roomTitle: room['title'],
                                  ),
                                ),
                              );
                            }
                          }),
                  ),
                  if (own != null) ...[
                    const SizedBox(height: 12),
                    AppButton(
                      label: 'Release my seat',
                      variant: AppButtonVariant.secondary,
                      onPressed: _busy || cached
                          ? null
                          : () => _run(() async {
                              await repo.releaseRoomSeat(
                                subgroup: subgroup,
                                room: widget.id,
                                seat: own['seatId'],
                                claimId: own['claimId'],
                              );
                            }),
                    ),
                  ],
                ],
              );
            },
          );
        },
      );
    },
  );
  RoomSeat _seat(
    int number,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String? user,
  ) {
    final data = docs.where((d) => d.id == 'seat-$number').firstOrNull?.data();
    if (data == null) {
      return RoomSeat(
        number: number,
        status: RoomSeatStatus.failed,
      );
    }
    if (number == _pendingSeat) {
      return RoomSeat(
        number: number,
        status: RoomSeatStatus.pending,
      );
    }
    final occupied =
        data['status'] == 'occupied' &&
        time(data['leaseExpiresAt']).isAfter(DateTime.now().toUtc());
    return RoomSeat(
      number: number,
      status: occupied
          ? (data['userId'] == user
                ? RoomSeatStatus.yours
                : RoomSeatStatus.occupied)
          : RoomSeatStatus.available,
      occupant: occupied
          ? SeatOccupant(
              name: data['displayName'] ?? 'Study mate',
              avatarId: data['avatarId'] ?? 'default',
            )
          : null,
    );
  }
}
