import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../../../core/models/community_models.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import 'goal_sheet.dart';
import 'room_scene.dart';
import 'room_scene_models.dart';

// Local interaction harness around the reusable RoomScene, not admission logic.
class RoomLobbyPreview extends StatefulWidget {
  const RoomLobbyPreview({
    super.key,
    required this.room,
    required this.seats,
    required this.isMember,
    required this.onLeave,
  });
  final RoomSummary room;
  final List<RoomSeat> seats;
  final bool isMember;
  final VoidCallback onLeave;
  @override
  State<RoomLobbyPreview> createState() => _RoomLobbyPreviewState();
}

class _RoomLobbyPreviewState extends State<RoomLobbyPreview> {
  int? _selected, _pending, _failed;
  bool _failNext = false;
  String _goal = '';
  Timer? _timer;

  @override
  void didUpdateWidget(covariant RoomLobbyPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isMember || oldWidget.room.id != widget.room.id) _clearDraft();
  }

  void _clearDraft() {
    _timer?.cancel();
    _selected = null;
    _pending = null;
    _failed = null;
    _goal = '';
    _failNext = false;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _select(int number) {
    if (!widget.isMember || _pending != null) return;
    final seat = widget.seats
        .where((seat) => seat.number == number)
        .firstOrNull;
    if (seat == null || seat.status != RoomSeatStatus.available) return;
    if (_selected == number) {
      setState(() => _selected = null);
      return;
    }
    final simulateFailure = _failNext;
    setState(() {
      _pending = number;
      _failed = null;
      _failNext = false;
    });
    _timer = Timer(const Duration(milliseconds: 450), () {
      if (!mounted || !widget.isMember) return;
      setState(() {
        _pending = null;
        if (simulateFailure) {
          _failed = number;
        } else {
          _selected = number;
          _failed = null;
        }
      });
    });
  }

  Future<void> _editGoal() async {
    final value = await showPreviewGoalSheet(context, _goal);
    if (mounted && widget.isMember && value != null) {
      setState(() => _goal = value);
    }
  }

  void _explain(String title, String message) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Got it'),
        ),
      ],
    ),
  );

  Future<void> _leave() async {
    if (_goal.isNotEmpty || _selected != null || _pending != null) {
      final leave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Leave room preview?'),
          content: const Text(
            'This clears your local goal and seat selection. No live room is affected.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Stay'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Leave preview'),
            ),
          ],
        ),
      );
      if (leave != true || !mounted) return;
    }
    setState(_clearDraft);
    widget.onLeave();
  }

  @override
  Widget build(BuildContext context) {
    final seats = [
      for (final seat in widget.seats)
        RoomSeat(
          number: seat.number,
          occupant: seat.occupant,
          status: seat.number == _pending
              ? RoomSeatStatus.pending
              : seat.number == _failed
              ? RoomSeatStatus.failed
              : seat.number == _selected
              ? RoomSeatStatus.selected
              : seat.status,
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Room scene preview',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          '${widget.room.occupiedSeats} of ${widget.room.capacity} seats occupied • Sample data',
        ),
        const SizedBox(height: 8),
        const Text(
          'All people shown are samples. Selecting a seat here does not reserve it.',
        ),
        const SizedBox(height: 16),
        RoomScene(
          seats: seats,
          selectionEnabled: widget.isMember && _pending == null,
          onSeatTap: _select,
        ),
        const SizedBox(height: 16),
        if (widget.room.isFull)
          const Text('This sample room is full. No seat is available.'),
        if (!widget.isMember)
          const Text('Join the subgroup to try seat selection and goal entry.'),
        if (_pending != null) const Text('Trying a local preview selection…'),
        if (_failed != null)
          Semantics(
            liveRegion: true,
            child: Text(
              'Simulated conflict at seat $_failed. Tap that seat to retry, or choose another.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (_selected != null)
          Text('Seat $_selected selected locally. No seat has been claimed.'),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Personal goal',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(_goal.isEmpty ? 'No preview goal yet.' : _goal),
              const SizedBox(height: 12),
              AppButton(
                label: _goal.isEmpty ? 'Set preview goal' : 'Edit preview goal',
                variant: AppButtonVariant.secondary,
                onPressed: widget.isMember ? _editGoal : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AppButton(
              label: 'Invite · preview',
              variant: AppButtonVariant.secondary,
              onPressed: () => _explain(
                'Invitation preview',
                'QR invitations and manual codes are a later milestone. No invitation was created.',
              ),
            ),
            AppButton(
              label: 'Start · preview',
              onPressed:
                  widget.isMember &&
                      _selected != null &&
                      _goal.isNotEmpty &&
                      _pending == null
                  ? () => _explain(
                      'Session preview',
                      'Your local seat selection and goal are ready. Shared timing is a later milestone; no session was started.',
                    )
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Select an available seat and save a goal to inspect the Start placeholder.',
        ),
        const SizedBox(height: 16),
        ExpansionTile(
          title: const Text('Preview controls'),
          tilePadding: EdgeInsets.zero,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Simulate next selection conflict'),
              subtitle: const Text(
                'Fails once, then the same seat can be retried. Local UI only.',
              ),
              value: _failNext,
              onChanged: widget.isMember && _pending == null
                  ? (value) => setState(() => _failNext = value)
                  : null,
            ),
            const Text(
              'The component gallery also shows all six seat states, including the sample “yours” state.',
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppButton(
          label: 'Leave room preview',
          variant: AppButtonVariant.secondary,
          onPressed: _leave,
        ),
      ],
    );
  }
}
