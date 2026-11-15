import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/widgets/app_button.dart';
import '../core/theme/app_theme.dart';
import '../preview/component_gallery.dart';
import '../preview/preview_data_screen.dart';
import '../features/communities/presentation/screens/discover_screen.dart';
import '../features/communities/presentation/screens/community_detail_screens.dart';
import '../features/rooms/presentation/screens/room_preview_screen.dart';
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
                pageBuilder: (context, state) => _tabPage(
                  state,
                  mode == AppMode.preview && tab.$1 == 'discover'
                      ? const DiscoverScreen()
                      : PlaceholderScreen(title: tab.$2, message: tab.$3),
                ),
              ),
              if (mode == AppMode.preview && tab.$1 == 'discover') ...[
                GoRoute(
                  path: '/sigs/:sigId',
                  name: 'sig-detail',
                  pageBuilder: (context, state) => _tabPage(
                    state,
                    SigDetailScreen(id: state.pathParameters['sigId']!),
                  ),
                ),
                GoRoute(
                  path: '/subgroups/:subgroupId',
                  name: 'subgroup-detail',
                  pageBuilder: (context, state) => _tabPage(
                    state,
                    SubgroupDetailScreen(
                      id: state.pathParameters['subgroupId']!,
                    ),
                  ),
                ),
                GoRoute(
                  path: '/rooms/:roomId',
                  name: 'room-preview',
                  pageBuilder: (context, state) => _tabPage(
                    state,
                    RoomPreviewScreen(id: state.pathParameters['roomId']!),
                  ),
                ),
              ],
            ],
          ),
      ],
    ),
    if (mode == AppMode.preview)
      GoRoute(
        path: '/preview-data',
        name: 'preview-data',
        builder: (context, state) => const PreviewDataScreen(),
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

// The shell owns the Scaffold; each branch page paints its own opaque surface.
Page<void> _tabPage(GoRouterState state, Widget child) =>
    NoTransitionPage<void>(
      key: state.pageKey,
      child: Material(color: AppColors.background, child: child),
    );
