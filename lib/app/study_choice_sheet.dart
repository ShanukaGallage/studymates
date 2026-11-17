import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/theme/app_theme.dart';

Future<void> showStudyChoices(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'How would you like to study?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              ListTile(
                key: const ValueKey('study-choice-hall'),
                minVerticalPadding: 16,
                leading: const Icon(
                  Icons.person_outline,
                  color: AppColors.primary,
                ),
                title: const Text('Common Hall'),
                subtitle: const Text('Self-study with your own focus cycle'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.goNamed('common-hall');
                },
              ),
              ListTile(
                key: const ValueKey('study-choice-room'),
                minVerticalPadding: 16,
                leading: const Icon(
                  Icons.groups_outlined,
                  color: AppColors.primary,
                ),
                title: const Text('Study rooms'),
                subtitle: const Text('Find your community and a room'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.go('/discover');
                },
              ),
            ],
          ),
        ),
      ),
    );
