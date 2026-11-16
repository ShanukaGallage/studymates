import 'package:material_ui/material_ui.dart';

/// Secondary explanations stay available without competing with the task.
class AppDetails extends StatelessWidget {
  const AppDetails({
    super.key,
    required this.title,
    required this.children,
    this.icon = Icons.info_outline,
  });
  final String title;
  final List<Widget> children;
  final IconData icon;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    maintainState: true,
    tilePadding: const EdgeInsets.symmetric(horizontal: 8),
    childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
    expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
    leading: Icon(icon),
    title: Text(title),
    children: children,
  );
}

/// Keeps text and controls comfortable in wide windows, with no fixed height.
class AppContentWidth extends StatelessWidget {
  const AppContentWidth({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: child,
    ),
  );
}
