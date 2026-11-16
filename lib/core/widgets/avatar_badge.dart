import 'package:material_ui/material_ui.dart';

import '../models/profile_photo.dart';

class AvatarBadge extends StatelessWidget {
  const AvatarBadge({
    super.key,
    required this.name,
    this.photo,
    this.size = 48,
  });
  final String name;
  final ProfilePhoto? photo;
  final double size;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final words = trimmed.split(RegExp(r'\s+'));
    final initials = trimmed.isEmpty
        ? '?'
        : '${words.first.characters.first}${words.length > 1 ? words.last.characters.first : ''}'
              .toUpperCase();
    final colors = Theme.of(context).colorScheme;
    Widget initialsAvatar() => Container(
      constraints: BoxConstraints(minWidth: size, minHeight: size),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Text(
          initials,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(color: colors.onPrimaryContainer),
        ),
      ),
    );
    return Semantics(
      label: trimmed.isEmpty ? 'Avatar' : 'Avatar for $trimmed',
      image: true,
      child: ExcludeSemantics(
        child: photo == null
            ? initialsAvatar()
            : ClipOval(
                child: Image.memory(
                  photo!.bytes,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  cacheWidth: ProfilePhoto.maxDimension,
                  cacheHeight: ProfilePhoto.maxDimension,
                  errorBuilder: (_, _, _) => initialsAvatar(),
                ),
              ),
      ),
    );
  }
}
