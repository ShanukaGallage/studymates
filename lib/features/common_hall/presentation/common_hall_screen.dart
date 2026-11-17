import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_mode.dart';
import '../../../core/models/completion_record.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_details.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/controllers/auth_providers.dart';
import '../../rooms/presentation/widgets/desk_illustration.dart';
import '../../sessions/presentation/widgets/keep_awake_control.dart';
import '../domain/common_hall_models.dart';
import 'common_hall_providers.dart';

class CommonHallScreen extends ConsumerStatefulWidget {
  const CommonHallScreen({super.key});
  @override
  ConsumerState<CommonHallScreen> createState() => _CommonHallScreenState();
}

class _CommonHallScreenState extends ConsumerState<CommonHallScreen> {
  final _goal = TextEditingController();
  Timer? _tick;
  bool _busy = false, _confirming = false;
  String? _error;
  CompletionRecord? _saved;
  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _goal.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || _confirming) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = hallError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _enter() => _run(() async {
    await ref.read(hallBackgroundServiceProvider).prepare();
    final session = await ref
        .read(commonHallRepositoryProvider)
        .enter(goalText: _goal.text);
    if (!mounted) return;
    setState(() => _saved = null);
    await ref.read(hallServiceStateProvider.notifier).start(session);
  });
  Future<void> _finish(HallSession session) async {
    if (_busy || _confirming) return;
    _confirming = true;
    bool completedGoal = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          scrollable: true,
          title: const Text('Finish self-study?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(session.goalText),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Goal completed'),
                value: completedGoal,
                onChanged: (value) =>
                    setDialogState(() => completedGoal = value ?? false),
              ),
              const Text(
                'Save confirmed focus time to Progress and remove your desk. Break time is excluded.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep studying'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Finish and leave'),
            ),
          ],
        ),
      ),
    );
    _confirming = false;
    if (confirmed != true || !mounted) return;
    await _run(() async {
      final background = ref.read(hallBackgroundServiceProvider);
      final saved = await ref
          .read(commonHallRepositoryProvider)
          .finish(
            expectedSessionId: session.sessionId,
            goalOutcome: completedGoal
                ? GoalOutcome.completed
                : GoalOutcome.unfinished,
          );
      if (mounted) setState(() => _saved = saved);
      await background.stop();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(appModeProvider) != AppMode.connected) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          EmptyView(
            title: 'Common Hall',
            message: 'Open the signed-in Android app to use shared desks and background self-study.',
          ),
        ],
      );
    }
    final active = ref.watch(commonHallSessionProvider);
    final participants = ref.watch(commonHallParticipantsProvider);
    final service = ref.watch(hallServiceStateProvider);
    final now = DateTime.now().toUtc();
    return AppContentWidth(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go('/home'),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Home'),
                    ),
                  ),
                  Text(
                    'Common Hall',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text('Your own pace. Good company.'),
                  const SizedBox(height: 16),
                  active.when(
                    loading: () => const LoadingView(
                      message: 'Checking your self-study session…',
                    ),
                    error: (_, _) => ErrorView(
                      message: 'Your hall session could not be loaded.',
                      onRetry: () =>
                          ref.invalidate(commonHallRepositoryProvider),
                    ),
                    data: (session) => session == null
                        ? AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_saved != null) ...[
                                  Text(
                                    '${_duration(_saved!.creditedSeconds)} saved to Progress.',
                                    key: const ValueKey('hall-saved'),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                const Text('25-minute focus · 5-minute break'),
                                const SizedBox(height: 12),
                                AppTextField(
                                  label: 'Study goal (optional)',
                                  controller: _goal,
                                  maxLength: 160,
                                ),
                                const SizedBox(height: 12),
                                AppButton(
                                  label: 'Enter and start studying',
                                  isLoading: _busy,
                                  onPressed: _busy ? null : _enter,
                                ),
                              ],
                            ),
                          )
                        : _sessionPanel(session, now, service),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Text(
                    'Studying together',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          participants.when(
            skipLoadingOnRefresh: false,
            loading: () => const SliverToBoxAdapter(
              child: LoadingView(message: 'Loading the hall…'),
            ),
            error: (_, _) => SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: ErrorView(
                  message: 'The hall could not confirm who is present.',
                  onRetry: () => ref.invalidate(commonHallParticipantsProvider),
                ),
              ),
            ),
            data: (all) {
              final live = all.where((person) => person.isLive(now)).toList();
              return SliverMainAxisGroup(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        '${live.length} ${live.length == 1 ? 'learner' : 'learners'} · ${live.length} ${live.length == 1 ? 'desk' : 'desks'}',
                        key: const ValueKey('hall-desk-count'),
                      ),
                    ),
                  ),
                  if (live.isEmpty)
                    const SliverPadding(
                      padding: EdgeInsets.all(16),
                      sliver: SliverToBoxAdapter(
                        child: EmptyView(
                          title: 'Be the first to study',
                          message: 'Enter the hall and your desk appears here.',
                        ),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                    sliver: SliverList.builder(
                      itemCount: live.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _HallDesk(
                          person: live[index],
                          yours:
                              live[index].userId ==
                              ref.read(authStateProvider).userId,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _sessionPanel(
    HallSession session,
    DateTime now,
    AsyncValue<void> service,
  ) {
    final live = session.isLive(now);
    final timing = HallTiming(
      startsAt: session.startsAt,
      now: live ? now : session.confirmedAt,
    );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            session.goalText,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Text(
            live
                ? timing.isBreak
                      ? 'Take a break'
                      : 'Focus time'
                : 'Connection ended',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            '${timing.remainingSeconds ~/ 60}:${(timing.remainingSeconds % 60).toString().padLeft(2, '0')}',
            style: Theme.of(context).textTheme.headlineLarge,
            key: const ValueKey('hall-countdown'),
          ),
          Text(
            'Cycle ${timing.completedCycles + 1} · ${timing.completedCycles} cycles done',
          ),
          Text('${_duration(timing.creditedSeconds)} focus time'),
          if (!live)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Save the last confirmed time, then enter again to continue.',
              ),
            ),
          if (service.hasError)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(hallError(service.error!)),
            ),
          if (live && service.hasError)
            TextButton(
              onPressed: _busy || service.isLoading
                  ? null
                  : () => _run(
                      () => ref
                          .read(hallServiceStateProvider.notifier)
                          .start(session),
                    ),
              child: const Text('Retry background timer'),
            ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Finish and leave',
            isLoading: _busy,
            onPressed: _busy ? null : () => _finish(session),
          ),
          const AppDetails(
            title: 'Study options',
            children: [
              Text(
                'Focus and breaks continue while your phone is locked. Tap the ongoing notification to return.',
              ),
              KeepAwakeControl(),
            ],
          ),
        ],
      ),
    );
  }
}

class _HallDesk extends StatelessWidget {
  const _HallDesk({required this.person, required this.yours});
  final HallParticipant person;
  final bool yours;
  @override
  Widget build(BuildContext context) => AppCard(
    key: ValueKey('hall-desk-${person.userId}'),
    child: Row(
      children: [
        SizedBox(width: 88, child: DeskIllustration(avatarId: person.avatarId)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                person.displayName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                yours ? 'Your desk' : 'Studying',
                style: const TextStyle(color: AppColors.secondaryText),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

String _duration(int seconds) =>
    '${seconds ~/ 3600}h ${(seconds % 3600) ~/ 60}m ${seconds % 60}s';
