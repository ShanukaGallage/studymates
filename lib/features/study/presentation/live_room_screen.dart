import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_details.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/controllers/auth_providers.dart';
import '../../sessions/data/active_session_providers.dart';
import '../../rooms/data/seat_claim_result.dart';
import '../../rooms/presentation/widgets/goal_sheet.dart';
import '../../rooms/presentation/widgets/room_scene.dart';
import '../../rooms/presentation/widgets/room_scene_models.dart';
import '../data/firestore_study_repository.dart';
import 'room_cycle_panel.dart';
import 'seat_recovery_card.dart';
import '../data/room_host_coordinator.dart';
import '../../invites/presentation/screens/room_invitations_screen.dart';
import '../../invites/data/invitation_token.dart';
import '../../invites/data/invitation_service.dart';
import '../data/firestore_invitation_service.dart';

class LiveRoomScreen extends ConsumerStatefulWidget {
  const LiveRoomScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<LiveRoomScreen> createState() => _LiveRoomScreenState();
}

class _LiveRoomScreenState extends ConsumerState<LiveRoomScreen> {
  late Future<Map<String, dynamic>> _location;
  bool _busy = false, _demo = false, _accessGranted = false;
  final _invitation = TextEditingController();
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
    _accessGranted = false;
    _location = repo.locator(widget.id).then((place) async {
      final room = await repo.getRoomSnapshot(widget.id);
      if (room == null) throw const StudyFailure('Room no longer exists.');
      _accessGranted = await repo.canAccessRoom(room);
      if (_accessGranted) {
        await repo.maintainRoomHost(place['subgroupId'], widget.id);
      }
      _roomStream = repo.watchRoomDocument(place['subgroupId'], widget.id);
      _seatsStream = repo.watchSeatDocuments(place['subgroupId'], widget.id);
      return place;
    });
  }

  @override
  void dispose() {
    _invitation.dispose();
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
      final currentSession = ref
          .watch(currentUserActiveSessionProvider)
          .asData
          ?.value;
      return AppContentWidth(
        child: StreamBuilder(
          stream: _roomStream,
          builder: (context, roomSnapshot) {
            if (roomSnapshot.hasError) {
              return ErrorView(
                message: 'Room connection failed.',
                onRetry: () => setState(_load),
              );
            }
            final room = roomSnapshot.data?.data();
            if (room == null) {
              return const LoadingView(message: 'Loading room…');
            }
            if (!_accessGranted) {
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Icon(Icons.lock_outline, size: 48),
                  Text(
                    room['title'],
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const Text(
                    'Enter an invitation code to join this private room.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _invitation,
                    decoration: const InputDecoration(
                      labelText: 'Invitation code',
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  if (_message.isNotEmpty)
                    Semantics(liveRegion: true, child: Text(_message)),
                  const SizedBox(height: 16),
                  AppButton(
                    label: 'Verify invitation and join',
                    isLoading: _busy,
                    onPressed: () => _run(() async {
                      final token = InvitationTokenParser.parseManual(
                        _invitation.text,
                      );
                      if (token == null) {
                        throw const StudyFailure(
                          'Enter a valid 16-character invitation code.',
                        );
                      }
                      final service = ref.read(
                        firestoreInvitationServiceProvider,
                      );
                      final preview = await service.resolveInvitation(token);
                      if (preview.preview?.room.id != widget.id ||
                          preview.preview?.room.subgroupId != subgroup) {
                        throw const StudyFailure(
                          'This invitation is invalid, expired, or belongs to another room.',
                        );
                      }
                      if (preview.status ==
                          InvitationPreviewStatus.membershipRequired) {
                        throw const StudyFailure(
                          'Join this community and subgroup first, then retry the invitation.',
                        );
                      }
                      final result = await service.admitInvitation(
                        opaqueToken: token,
                        membershipConsentGranted: false,
                      );
                      if (result.status != InvitationAdmissionStatus.admitted) {
                        throw StudyFailure(
                          'Admission not confirmed: ${result.status.name}.',
                        );
                      }
                      if (mounted) setState(() => _accessGranted = true);
                    }),
                  ),
                  TextButton(
                    onPressed: () => context.go('/subgroups/$subgroup'),
                    child: const Text('Back to subgroup'),
                  ),
                ],
              );
            }
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
                final hostName =
                    documents
                            .where((d) => d.data()['userId'] == room['hostUid'])
                            .firstOrNull
                            ?.data()['displayName']
                        as String?;
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
                          : hostName == null
                          ? 'Host is not seated'
                          : 'Host: $hostName',
                    ),
                    Text(
                      '${room['capacity'] ?? 6} desks · ${room['isPrivate'] == true ? 'Private room' : 'Public room'}',
                    ),
                    if (cached)
                      const Text(
                        'Offline · Showing saved seats. Reconnect to make changes.',
                      ),
                    if (own != null && !ownValid)
                      const Text(
                        'Your seat expired. Release it to choose again.',
                      ),
                    const SizedBox(height: 16),
                    RoomCyclePanel(
                      subgroup: subgroup,
                      room: widget.id,
                      sessionId: room['sessionId'] as String?,
                    ),
                    SeatRecoveryCard(roomId: widget.id),
                    if (currentSession?.roomId != widget.id) ...[
                      const SizedBox(height: 16),
                      if (_goal.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(_goal),
                        ),
                      AppButton(
                        label: _goal.isEmpty ? 'Set study goal' : 'Edit goal',
                        variant: AppButtonVariant.secondary,
                        onPressed: _busy
                            ? null
                            : () async {
                                final goal = await showPreviewGoalSheet(
                                  context,
                                  _goal,
                                  preview: false,
                                );
                                if (mounted && goal != null) {
                                  setState(() => _goal = goal);
                                }
                              },
                      ),
                      if (_demo && room['hostUid'] == user)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Demo selected · 60 seconds · Excluded from Progress',
                          ),
                        ),
                      AppButton(
                        label: room['hostUid'] == user
                            ? 'Start / join cycle'
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
                    ],
                    const SizedBox(height: 16),
                    Text(
                      ownValid ? 'Classroom' : 'Choose a desk',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    RoomScene(
                      selectionEnabled: !_busy && !cached,
                      seats: [
                        for (
                          var number = 1;
                          number <= (room['capacity'] as int? ?? 6);
                          number++
                        )
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
                            result.failure == SeatClaimFailure.hallSessionActive
                                ? 'Finish your Common Hall session before taking a room desk. Use + to return to the hall.'
                                : result.failure ==
                                      SeatClaimFailure.alreadySeated
                                ? 'You already have a reserved seat or unfinished session. Use the recovery controls above before choosing another desk.'
                                : 'Seat not confirmed: ${result.failure.name}. Try another seat or retry.',
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
                    const SizedBox(height: 12),
                    AppDetails(
                      title: 'Room options',
                      icon: Icons.tune,
                      children: [
                        if (room['hostUid'] == user) ...[
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('60-second demo cycle'),
                            subtitle: const Text(
                              '45s focus + 15s break · Excluded from Progress',
                            ),
                            value: _demo,
                            onChanged: _busy || room['hostUid'] != user
                                ? null
                                : (v) => setState(() => _demo = v),
                          ),
                        ],
                        const SizedBox(height: 12),
                        AppButton(
                          label: 'Show room invitation',
                          variant: AppButtonVariant.secondary,
                          onPressed:
                              _busy ||
                                  cached ||
                                  (room['isPrivate'] == true &&
                                      room['createdBy'] != user &&
                                      room['hostUid'] != user)
                              ? null
                              : () => _run(() async {
                                  final token = await ref
                                      .read(firestoreInvitationServiceProvider)
                                      .issue(subgroup, widget.id);
                                  if (context.mounted) {
                                    Navigator.of(
                                      context,
                                      rootNavigator: true,
                                    ).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => ManagedInvitationScreen(
                                          token: token,
                                          roomTitle: room['title'],
                                        ),
                                      ),
                                    );
                                  }
                                }),
                        ),
                        if (room['hostUid'] == user ||
                            room['createdBy'] == user) ...[
                          const SizedBox(height: 12),
                          AppButton(
                            label: 'Manage invitations',
                            variant: AppButtonVariant.secondary,
                            onPressed: _busy || cached
                                ? null
                                : () =>
                                      Navigator.of(
                                        context,
                                        rootNavigator: true,
                                      ).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => RoomInvitationsScreen(
                                            subgroup: subgroup,
                                            room: widget.id,
                                            title: room['title'],
                                          ),
                                        ),
                                      ),
                          ),
                        ],
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
                    ),
                    AppDetails(
                      title: 'How rooms work',
                      children: [
                        const Text(
                          'One seat per person. Release your desk before moving to another.',
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'The longest-seated eligible learner takes over when the host leaves. After a disconnection, handover waits for the host’s seat to expire.',
                        ),
                        if (ownValid)
                          TextButton(
                            onPressed: _busy || cached
                                ? null
                                : () => _run(
                                    () => repo.maintainRoomHost(
                                      subgroup,
                                      widget.id,
                                    ),
                                  ),
                            child: const Text('Check host handover'),
                          ),
                      ],
                    ),
                  ],
                );
              },
            );
          },
        ),
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
        isPreview: false,
        status: RoomSeatStatus.failed,
      );
    }
    if (number == _pendingSeat) {
      return RoomSeat(
        number: number,
        isPreview: false,
        status: RoomSeatStatus.pending,
      );
    }
    final occupied =
        data['status'] == 'occupied' &&
        time(data['leaseExpiresAt']).isAfter(DateTime.now().toUtc());
    return RoomSeat(
      number: number,
      isPreview: false,
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
