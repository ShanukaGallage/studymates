import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../sessions/data/active_session_providers.dart';
import '../data/firestore_study_repository.dart';

class ActiveSessionCard extends ConsumerStatefulWidget {
  const ActiveSessionCard({super.key});
  @override
  ConsumerState<ActiveSessionCard> createState() => _ActiveSessionCardState();
}

class _ActiveSessionCardState extends ConsumerState<ActiveSessionCard> {
  bool _busy = false;
  String? _error;
  @override
  Widget build(BuildContext context) => ref
      .watch(currentUserActiveSessionProvider)
      .when(
        loading: () => const Text('Checking active session…'),
        error: (_, _) => AppCard(
          child: Column(
            children: [
              const Text('Active session lookup unavailable.'),
              AppButton(
                label: 'Retry session lookup',
                onPressed: () =>
                    ref.invalidate(activeSessionRepositoryProvider),
              ),
              TextButton(
                onPressed: () => context.push('/session'),
                child: const Text('Open session recovery'),
              ),
            ],
          ),
        ),
        data: (session) => session == null
            ? const SizedBox.shrink()
            : AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      session.isDemo
                          ? 'Your demo session'
                          : 'Your active session',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(session.roomTitle),
                    Text(session.goalText),
                    if (_error != null) Text(_error!),
                    AppButton(
                      label: 'Return to session',
                      isLoading: _busy,
                      onPressed: () async {
                        setState(() {
                          _busy = true;
                          _error = null;
                        });
                        try {
                          final result = await ref
                              .read(studyRepositoryProvider)
                              .revalidateSession();
                          if (context.mounted && result != null) {
                            context.push('/session');
                          }
                        } catch (error) {
                          if (mounted) {
                            setState(
                              () => _error = error is StudyFailure
                                  ? error.message
                                  : 'Connection unavailable. Retry.',
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                    ),
                    TextButton(
                      onPressed: () => context.push('/session'),
                      child: const Text('Review or end participation'),
                    ),
                  ],
                ),
              ),
      );
}
