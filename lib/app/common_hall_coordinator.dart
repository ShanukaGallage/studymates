import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/presentation/controllers/auth_providers.dart';
import '../features/common_hall/domain/common_hall_models.dart';
import '../features/common_hall/presentation/common_hall_providers.dart';
import '../features/progress/presentation/controllers/progress_history_controller.dart';
import 'router.dart';

/// App-wide ownership of notification navigation and service restoration, rather
/// than a timer tied to a disposable hall screen. Background work stays native.
final commonHallCoordinatorProvider = Provider<void>((ref) {
  final background = ref.watch(hallBackgroundServiceProvider);
  Future<void> restore(HallSession session) async {
    if (!session.isLive(DateTime.now()) ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    try {
      await ref.read(hallServiceStateProvider.notifier).start(session);
    } catch (_) {
      /* The hall shows a retryable service error. */
    }
  }

  ref.listen(commonHallSessionProvider, (previous, next) {
    if (next case AsyncData(value: final session)) {
      if (session == null) {
        if (previous?.asData?.value != null) {
          ref.invalidate(progressHistoryProvider);
        }
        unawaited(background.stop().catchError((_) {}));
      } else if (previous?.asData?.value?.sessionId != session.sessionId) {
        unawaited(restore(session));
      }
    }
  }, fireImmediately: true);
  ref.listen(authStateProvider.select((auth) => auth.userId), (_, user) {
    if (user == null) unawaited(background.stop().catchError((_) {}));
  });
  final removeListener = background.listenForOpen(
    () {
      if (ref.mounted && ref.read(authStateProvider).userId != null) {
        ref.read(appRouterProvider).go('/common-hall');
      }
    },
    onInterrupted: () {
      if (ref.mounted) {
        ref.read(hallServiceStateProvider.notifier).interrupted();
      }
    },
  );
  final observer = _HallLifecycle(() {
    final active = ref.read(commonHallSessionProvider).asData?.value;
    if (active != null) unawaited(restore(active));
  });
  WidgetsBinding.instance.addObserver(observer);
  ref.onDispose(() {
    removeListener();
    WidgetsBinding.instance.removeObserver(observer);
  });
}, dependencies: [progressHistoryProvider, appRouterProvider]);

class _HallLifecycle extends WidgetsBindingObserver {
  _HallLifecycle(this.resume);
  final VoidCallback resume;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) resume();
  }
}
