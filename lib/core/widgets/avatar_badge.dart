import 'package:material_ui/material_ui.dart';

class AvatarBadge extends StatelessWidget {
  const AvatarBadge({super.key, required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final words = trimmed.split(RegExp(r'\s+'));
    final initials = trimmed.isEmpty
        ? '?'
        : '${words.first.characters.first}${words.length > 1 ? words.last.characters.first : ''}'
              .toUpperCase();
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
            initials,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: colors.onPrimaryContainer),
          ),
        ),
      ),
    );
  }
}
