import 'package:material_ui/material_ui.dart';

class AvatarBadge extends StatelessWidget {
  const AvatarBadge({super.key, required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: trimmed.isEmpty ? 'Avatar' : 'Avatar for $trimmed',
      image: true,
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Text(
            trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: colors.onPrimaryContainer),
          ),
        ),
      ),
    );
  }
}
