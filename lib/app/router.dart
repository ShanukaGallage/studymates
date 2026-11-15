import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/widgets/app_button.dart';
import '../preview/component_gallery.dart';
import 'app_mode.dart';
import 'app_shell.dart';
import 'placeholder_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = createAppRouter(mode: ref.watch(appModeProvider));
  ref.onDispose(router.dispose);
  return router;
});

GoRouter createAppRouter({
  required AppMode mode,
  String initialLocation = '/home',
}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(path: '/', redirect: (context, state) => '/home'),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(navigationShell: shell),
      branches: [
        for (final tab in const [
          (
            'home',
            'Home',
            'Your joined communities and study shortcuts will appear here. No account is connected.',
          ),
          (
            'discover',
            'Discover',
            'Community discovery and membership are planned. No live groups are loaded.',
          ),
          (
            'progress',
            'Progress',
            'Session history and recorded time are planned. No study records are loaded.',
          ),
          (
            'profile',
            'Profile',
            'Profile setup and account settings are planned. You are not signed in.',
          ),
        ])
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/${tab.$1}',
                name: tab.$1,
                builder: (context, state) =>
                    PlaceholderScreen(title: tab.$2, message: tab.$3),
              ),
            ],
          ),
      ],
    ),
    if (mode == AppMode.preview)
      GoRoute(
        path: '/components',
        name: 'components',
        builder: (context, state) => const ComponentGallery(),
      ),
  ],
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: const Text('Page not found')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'This page is not available in the StudyMates foundation.',
          ),
          const SizedBox(height: 24),
          AppButton(label: 'Go to Home', onPressed: () => context.go('/home')),
        ],
      ),
    ),
  ),
);
