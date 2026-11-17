import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_details.dart';
import '../../../core/widgets/state_views.dart';
import '../domain/study_notification.dart';
import 'notification_providers.dart';

void _back(BuildContext context, String fallback) =>
    context.canPop() ? context.pop() : context.go(fallback);

class NotificationInboxScreen extends ConsumerWidget {
  const NotificationInboxScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'Notifications',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      leading: IconButton(
        tooltip: 'Back',
        icon: const Icon(Icons.arrow_back),
        onPressed: () => _back(context, '/home'),
      ),
      actions: [
        IconButton(
          tooltip: 'Notification settings',
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => context.push('/notification-settings'),
        ),
      ],
    ),
    body: SafeArea(
      child: AppContentWidth(
        child: ref
            .watch(notificationSnapshotProvider)
            .when(
              skipLoadingOnReload: false,
              skipLoadingOnRefresh: false,
              loading: () => const Center(
                child: LoadingView(message: 'Loading notifications…'),
              ),
              error: (_, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: ErrorView(
                  message: 'Notifications could not be loaded.',
                  onRetry: () => ref.invalidate(notificationSnapshotProvider),
                ),
              ),
              data: (snapshot) {
                if (snapshot.userId != ref.watch(notificationUserProvider)) {
                  return const LoadingView(message: 'Loading notifications…');
                }
                final notice = ref.watch(notificationNoticeProvider);
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: snapshot.items.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (snapshot.preview)
                            const _Notice(
                              'Preview only · No device alerts are sent.',
                            ),
                          if (notice != null) _Notice(notice),
                          if (!snapshot.available)
                            const EmptyView(
                              title: 'Android notifications',
                              message: 'Open the Android app to manage device notifications.',
                            )
                          else if (snapshot.items.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: EmptyView(
                                title: 'You’re all caught up',
                                message: 'Focus, break and recovery alerts will appear here.',
                              ),
                            )
                          else ...[
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                Text(
                                  'Recent study alerts',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                TextButton(
                                  onPressed: () async {
                                    try {
                                      await ref
                                          .read(
                                            notificationSnapshotProvider
                                                .notifier,
                                          )
                                          .markAllRead();
                                    } catch (_) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Could not mark alerts as read. Try again.',
                                                ),
                                              ),
                                            );
                                      }
                                    }
                                  },
                                  child: const Text('Mark all read'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      );
                    }
                    final item = snapshot.items[index - 1];
                    final alert = item.alert;
                    final local = alert.at.toLocal();
                    final labels = MaterialLocalizations.of(context);
                    final date =
                        '${labels.formatShortDate(local)} · ${labels.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppCard(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          minVerticalPadding: 12,
                          leading: Icon(switch (alert.kind) {
                            StudyAlertKind.focusFinished =>
                              Icons.coffee_outlined,
                            StudyAlertKind.breakFinished =>
                              Icons.timer_outlined,
                            StudyAlertKind.recovery => Icons.wifi_off_outlined,
                            StudyAlertKind.reminder =>
                              Icons.event_available_outlined,
                            StudyAlertKind.test =>
                              Icons.notifications_active_outlined,
                          }, color: AppColors.primary),
                          title: Text(
                            alert.title,
                            style: TextStyle(
                              fontWeight: item.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w800,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(alert.body),
                                const SizedBox(height: 8),
                                Text(
                                  '$date${item.isRead ? '' : ' · Unread'}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => ref
                              .read(notificationServiceProvider)
                              .taps
                              .add(alert),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
      ),
    ),
  );
}

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsState();
}

class _NotificationSettingsState
    extends ConsumerState<NotificationSettingsScreen> {
  bool _busy = false;
  String? _error;
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not update notifications. Check Android notification settings and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(NotificationPreferences settings) => _run(
    () => ref.read(notificationSnapshotProvider.notifier).settings(settings),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'Notification settings',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      leading: IconButton(
        tooltip: 'Back',
        icon: const Icon(Icons.arrow_back),
        onPressed: () => _back(context, '/profile'),
      ),
    ),
    body: SafeArea(
      child: AppContentWidth(
        child: ref
            .watch(notificationSnapshotProvider)
            .when(
              skipLoadingOnReload: false,
              skipLoadingOnRefresh: false,
              loading: () => const Center(
                child: LoadingView(message: 'Loading settings…'),
              ),
              error: (_, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: ErrorView(
                  message: 'Notification settings could not be loaded.',
                  onRetry: () => ref.invalidate(notificationSnapshotProvider),
                ),
              ),
              data: (snapshot) {
                if (snapshot.userId != ref.watch(notificationUserProvider)) {
                  return const LoadingView(message: 'Loading settings…');
                }
                final settings = snapshot.settings;
                final enabled = snapshot.available && !_busy;
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (snapshot.preview)
                      const _Notice(
                        'Preview only · Settings stay in this preview. No device alerts are sent.',
                      ),
                    if (!snapshot.available)
                      const _Notice(
                        'Device notifications are available in the signed-in Android app.',
                      ),
                    if (snapshot.available &&
                        !snapshot.allowed &&
                        !snapshot.preview)
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Allow notifications to receive study alerts. Your inbox still keeps local study alerts.',
                            ),
                            const SizedBox(height: 12),
                            AppButton(
                              label: 'Allow notifications',
                              isLoading: _busy,
                              onPressed: enabled
                                  ? () => _run(() async {
                                      final allowed = await ref
                                          .read(
                                            notificationSnapshotProvider
                                                .notifier,
                                          )
                                          .enable();
                                      if (!allowed && mounted) {
                                        setState(
                                          () => _error = 'Notifications are blocked. Enable StudyMates notifications in Android Settings.',
                                        );
                                      }
                                    })
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      'Study alerts',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    AppCard(
                      child: Column(
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Focus and break alerts'),
                            subtitle: const Text(
                              'Once when a Common Hall phase changes',
                            ),
                            value: settings.cycles,
                            onChanged: enabled
                                ? (value) =>
                                      _save(settings.copyWith(cycles: value))
                                : null,
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Session recovery alerts'),
                            subtitle: const Text(
                              'When your study connection needs attention',
                            ),
                            value: settings.recovery,
                            onChanged: enabled
                                ? (value) =>
                                      _save(settings.copyWith(recovery: value))
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Daily reminder',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    AppCard(
                      child: Column(
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Remind me to study'),
                            value: settings.dailyReminder,
                            onChanged: enabled
                                ? (value) => _run(() async {
                                    if (value &&
                                        !snapshot.allowed &&
                                        !snapshot.preview) {
                                      final allowed = await ref
                                          .read(
                                            notificationSnapshotProvider
                                                .notifier,
                                          )
                                          .enable();
                                      if (!allowed) {
                                        if (mounted) {
                                          setState(
                                            () => _error = 'Allow notifications before enabling reminders.',
                                          );
                                        }
                                        return;
                                      }
                                    }
                                    await ref
                                        .read(
                                          notificationSnapshotProvider.notifier,
                                        )
                                        .settings(
                                          settings.copyWith(
                                            dailyReminder: value,
                                          ),
                                        );
                                  })
                                : null,
                          ),
                          if (settings.dailyReminder)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.schedule),
                              title: const Text('Reminder time'),
                              subtitle: Text(
                                '${MaterialLocalizations.of(context).formatTimeOfDay(
                                  TimeOfDay(hour: settings.hour, minute: settings.minute),
                                  alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
                                )} · Device local time',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: enabled
                                  ? () async {
                                      final time = await showTimePicker(
                                        context: context,
                                        initialTime: TimeOfDay(
                                          hour: settings.hour,
                                          minute: settings.minute,
                                        ),
                                      );
                                      if (time != null && mounted) {
                                        await _save(
                                          settings.copyWith(
                                            hour: time.hour,
                                            minute: time.minute,
                                          ),
                                        );
                                      }
                                    }
                                  : null,
                            ),
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Reminders arrive around your chosen time; Android may delay them to save battery.',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Sound and vibration',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    AppCard(
                      child: Column(
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Sound'),
                            value: settings.sound,
                            onChanged: enabled
                                ? (value) =>
                                      _save(settings.copyWith(sound: value))
                                : null,
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Vibration'),
                            value: settings.vibration,
                            onChanged: enabled
                                ? (value) =>
                                      _save(settings.copyWith(vibration: value))
                                : null,
                          ),
                          const Text(
                            'The ongoing countdown stays quiet. Android notification settings and Do Not Disturb can override alerts.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    AppButton(
                      label: snapshot.preview
                          ? 'Add preview notification'
                          : 'Send test notification',
                      variant: AppButtonVariant.secondary,
                      isLoading: _busy,
                      onPressed: enabled
                          ? () => _run(() async {
                              await ref
                                  .read(notificationSnapshotProvider.notifier)
                                  .test();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      snapshot.preview
                                          ? 'Preview notification added to your inbox.'
                                          : 'Test notification sent.',
                                    ),
                                  ),
                                );
                              }
                            })
                          : null,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Settings and recent study alerts are saved only on this device. No email notifications.',
                    ),
                    const SizedBox(height: 32),
                  ],
                );
              },
            ),
      ),
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: AppCard(child: Text(message)),
  );
}
