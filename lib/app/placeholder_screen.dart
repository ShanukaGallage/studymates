import 'package:material_ui/material_ui.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/app_card.dart';
import '../core/widgets/state_views.dart';

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.message,
  });
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AppSpacing.lg),
    children: [
      Text(title, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: AppSpacing.sm),
      const Text('Find your people. Learn together.'),
      const SizedBox(height: AppSpacing.xl),
      AppCard(
        child: EmptyView(title: '$title placeholder', message: message),
      ),
    ],
  );
}
