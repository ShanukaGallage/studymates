import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'notification_providers.dart';

class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(notificationSnapshotProvider).asData?.value;
    final uid = ref.watch(notificationUserProvider);
    final count = snapshot?.userId == uid ? snapshot?.unread ?? 0 : 0;
    return Semantics(
      label: count > 0
          ? '$count unread notifications'
          : 'No unread notifications',
      child: IconButton(
        tooltip: 'Notifications',
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        visualDensity: VisualDensity.standard,
        onPressed: () => context.push('/notifications'),
        icon: Badge(
          isLabelVisible: count > 0,
          label: Text(count > 9 ? '9+' : '$count'),
          child: const Icon(Icons.notifications_outlined),
        ),
      ),
    );
  }
}
