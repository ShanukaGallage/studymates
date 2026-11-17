import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import 'common_hall_providers.dart';

class CommonHallCard extends ConsumerWidget {
  const CommonHallCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(commonHallSessionProvider)
      .when(
        loading: () => const SizedBox.shrink(),
        error: (_, _) => AppCard(
          child: Column(
            children: [
              const Text('Self-study session lookup unavailable.'),
              AppButton(
                label: 'Retry self-study lookup',
                onPressed: () => ref.invalidate(commonHallRepositoryProvider),
              ),
            ],
          ),
        ),
        data: (session) => session == null
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Your self-study session',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(session.goalText),
                      const SizedBox(height: 12),
                      AppButton(
                        label: 'Return to Common Hall',
                        onPressed: () => context.pushNamed('common-hall'),
                      ),
                    ],
                  ),
                ),
              ),
      );
}
