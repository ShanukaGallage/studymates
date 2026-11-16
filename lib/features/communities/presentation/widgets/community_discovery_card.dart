import 'package:material_ui/material_ui.dart';

import '../../../../core/models/community_models.dart';
import '../../../../core/theme/app_theme.dart';

class CommunityDiscoveryCard extends StatelessWidget {
  const CommunityDiscoveryCard({
    super.key,
    required this.community,
    required this.subgroupCount,
    required this.onOpen,
  });
  final SigSummary community;
  final int subgroupCount;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final joined = community.membership == MembershipState.joined;
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: AppColors.primary.withValues(alpha: .18)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked =
                  constraints.maxWidth < 300 ||
                  MediaQuery.textScalerOf(context).scale(16) > 22;
              final details = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    community.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${community.category} · $subgroupCount ${subgroupCount == 1 ? 'subgroup' : 'subgroups'}',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.secondaryText),
                  ),
                  if (joined) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.mintAccent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: Color(0xFF225B3B),
                          ),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Joined',
                              style: TextStyle(color: Color(0xFF225B3B)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
              final action = joined
                  ? FilledButton.tonal(
                      onPressed: onOpen,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(72, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: const Text('Open'),
                    )
                  : OutlinedButton(
                      onPressed: onOpen,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(72, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: const Text('Explore'),
                    );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: stacked
                        ? CrossAxisAlignment.start
                        : CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: stacked ? 48 : 56,
                        height: stacked ? 48 : 56,
                        decoration: BoxDecoration(
                          color: joined
                              ? AppColors.mintAccent
                              : AppColors.softAccent,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          joined
                              ? Icons.groups_rounded
                              : Icons.auto_stories_outlined,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: details),
                      if (!stacked) ...[const SizedBox(width: 12), action],
                    ],
                  ),
                  if (stacked) ...[
                    const SizedBox(height: 12),
                    Align(alignment: Alignment.centerRight, child: action),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
