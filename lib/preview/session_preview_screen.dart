import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../core/models/completion_record.dart';
import '../core/widgets/app_button.dart';
import '../features/sessions/data/session_timing.dart';
import '../features/sessions/presentation/widgets/session_views.dart';

/// Local UI harness. Never writes completions or claims a server-side seat.
class SessionPreviewScreen extends StatefulWidget {
  const SessionPreviewScreen({
    super.key,
    required this.roomTitle,
    required this.seat,
    required this.goal,
    this.now,
  });
  final String roomTitle, goal;
  final int seat;
  final DateTime Function()? now;

  @override
  State<SessionPreviewScreen> createState() => _SessionPreviewScreenState();
}

class _SessionPreviewScreenState extends State<SessionPreviewScreen> {
  late final DateTime _start;
  Timer? _ticker, _saveTimer;
  DateTime? _ended;
  bool _allowExit = false;
  bool _confirming = false, _reconnecting = false, _seatLost = false;
  bool _failSave = false,
      _saving = false,
      _saveFailed = false,
      _summary = false;
  GoalOutcome _outcome = GoalOutcome.unfinished;
  DateTime get _now => (widget.now?.call() ?? DateTime.now()).toUtc();
  int get _elapsed =>
      ((_ended ?? _now).difference(_start).inSeconds).clamp(0, 60);
  SessionTiming get _timing => calculateSessionTiming(
    nowUtc: _ended ?? _now,
    startsAt: _start,
    focusEndsAt: _start.add(const Duration(seconds: 45)),
    breakEndsAt: _start.add(const Duration(seconds: 60)),
  ) as SessionTiming;

  @override
  void initState() {
    super.initState();
    _start = _now;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_ended == null) {
        setState(() {
          if (_timing.phase == SessionPhase.completed) {
            _ended = _start.add(const Duration(seconds: 60));
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _saveTimer?.cancel();
    super.dispose();
  }

  Future<void> _end() async {
    if (_confirming || _saving) return;
    if (_summary) {
      Navigator.pop(context, false);
      return;
    }
    _confirming = true;
    final leaving = _ended != null;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          leaving ? 'Discard preview summary?' : 'End preview session?',
        ),
        content: Text(
          leaving
              ? 'Return to the room without this local summary. Nothing has been saved to Progress.'
              : 'Review your goal and elapsed time next. This preview will not save a completion or change Progress.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(leaving ? 'Keep reviewing' : 'Keep studying'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(leaving ? 'Discard and return' : 'End preview'),
          ),
        ],
      ),
    );
    _confirming = false;
    if (!mounted || confirmed != true) return;
    if (leaving) {
      setState(() => _allowExit = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.pop(context, false);
    } else {
      setState(() => _ended = _now);
    }
  }

  void _review() {
    if (_saving) return;
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() {
        _saving = false;
        if (_failSave) {
          _saveFailed = true;
          _failSave = false;
        } else {
          _summary = true;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _summary || _allowExit,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _end();
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Study session · preview'),
        leading: IconButton(
          onPressed: _saving ? null : _end,
          tooltip: 'End or return',
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('LOCAL DEMO • 45s focus + 15s break'),
            const Text(
              'No seat reservation, synchronization or saved progress.',
            ),
            const SizedBox(height: 16),
            if (_summary) ...[
              SessionSummaryView(
                goal: widget.goal,
                elapsedSeconds: _elapsed,
                timerStatus: _timing.phase == SessionPhase.completed
                    ? TimerCompletionStatus.completed
                    : TimerCompletionStatus.endedEarly,
                goalOutcome: _outcome,
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Return to room',
                onPressed: () => Navigator.pop(context, false),
              ),
              AppButton(
                label: 'View sample Progress',
                variant: AppButtonVariant.secondary,
                onPressed: () => Navigator.pop(context, true),
              ),
            ] else ...[
              SessionView(
                roomTitle: widget.roomTitle,
                seat: widget.seat,
                goal: widget.goal,
                timing: _timing,
                elapsedSeconds: _elapsed,
              ),
              if (_reconnecting)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Simulated reconnecting. The display clock continues; participation and credit are unverified.',
                  ),
                ),
              if (_seatLost)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Simulated seat unavailable. This preview has ended; return to the room to choose again.',
                  ),
                ),
              const SizedBox(height: 16),
              if (_ended == null)
                AppButton(label: 'End session', onPressed: _end)
              else ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('I completed my goal'),
                  subtitle: const Text(
                    'Goal outcome is separate from timer completion.',
                  ),
                  value: _outcome == GoalOutcome.completed,
                  onChanged: _saving
                      ? null
                      : (value) => setState(
                          () => _outcome = value
                              ? GoalOutcome.completed
                              : GoalOutcome.unfinished,
                        ),
                ),
                if (_saveFailed)
                  const Text(
                    'Simulated save failed. Your local summary is retained. Retry does not write to history.',
                  ),
                AppButton(
                  label: _saveFailed
                      ? 'Retry preview summary'
                      : 'Review preview summary',
                  isLoading: _saving,
                  onPressed: _reconnecting ? null : _review,
                ),
                if (_reconnecting)
                  const Text(
                    'Restore the simulated connection below to review.',
                  ),
              ],
              const SizedBox(height: 16),
              ExpansionTile(
                key: const PageStorageKey('session-preview-controls'),
                title: const Text('Session preview controls'),
                children: [
                  SwitchListTile(
                    title: const Text('Simulate connection interruption'),
                    value: _reconnecting,
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _reconnecting = value),
                  ),
                  SwitchListTile(
                    title: const Text('Fail next summary attempt'),
                    value: _failSave,
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _failSave = value),
                  ),
                  AppButton(
                    label: 'Simulate seat unavailable',
                    variant: AppButtonVariant.secondary,
                    onPressed: _ended != null
                        ? null
                        : () => setState(() {
                            _seatLost = true;
                            _ended = _now;
                          }),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
