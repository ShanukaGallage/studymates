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
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/sign_up_screen.dart';
import '../features/auth/presentation/screens/forgot_password_screen.dart';
import '../features/profile/presentation/screens/profile_setup_screen.dart';
import '../features/profile/presentation/screens/profile_view_screen.dart';
import '../features/progress/presentation/screens/progress_history_screen.dart';
import '../features/invites/presentation/screens/invite_scanner_screen.dart';
import '../preview/scanner_preview_screen.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/study/presentation/live_room_screen.dart';
import '../features/common_hall/presentation/common_hall_screen.dart';
import '../features/study/presentation/live_session_screen.dart';
import '../features/invites/presentation/screens/invitation_preview_screen.dart';
import '../features/invites/data/invitation_token.dart';
import '../features/communities/data/firestore_membership_repository.dart';
import '../features/communities/presentation/controllers/community_providers.dart';
import 'account_access.dart';
import 'account_screens.dart';
import 'app_mode.dart';
import 'app_shell.dart';
import 'placeholder_screen.dart';
import '../features/notifications/presentation/notification_screens.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final mode = ref.watch(appModeProvider);
  final refresh = ValueNotifier<int>(0);
  if (mode == AppMode.connected) {
    ref.listen(accountAccessProvider, (_, next) => refresh.value++);
  }
  final router = createAppRouter(
    mode: mode,
    refreshListenable: refresh,
    access: mode == AppMode.connected
        ? () => ref.read(accountAccessProvider)
        : null,
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
}, dependencies: [appModeProvider]);

GoRouter createAppRouter({
  required AppMode mode,
  String initialLocation = '/home',
  Listenable? refreshListenable,
  AccountAccess Function()? access,
}) {
  final scannerObserver = RouteObserver<ModalRoute<dynamic>>();
  String authPath(BuildContext context, String path) => Uri(
    path: path,
    queryParameters: GoRouterState.of(context).uri.queryParameters,
  ).toString();
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: refreshListenable,
    observers: [scannerObserver],
    redirect: mode == AppMode.connected
        ? (context, state) => accountRedirect(
            access?.call() ?? AccountAccess.loading,
            state.uri,
          )
        : null,
    routes: [
      if (mode != AppMode.foundation) ...[
        GoRoute(
          path: '/notifications',
          builder: (_, _) => const NotificationInboxScreen(),
        ),
        GoRoute(
          path: '/notification-settings',
          builder: (_, _) => const NotificationSettingsScreen(),
        ),
      ],
      if (mode == AppMode.connected) ...[
        GoRoute(path: '/session', builder: (_, _) => const LiveSessionScreen()),
        GoRoute(
          path: '/scan',
          builder: (context, _) => InviteScannerScreen(
            routeObserver: scannerObserver,
            parseQr: InvitationTokenParser.parseQr,
            parseManual: InvitationTokenParser.parseManual,
            onCancel: () => context.go('/discover'),
            onResult: (token) => context.go('/invitation/$token'),
          ),
        ),
        GoRoute(
          path: '/invitation/:token',
          builder: (context, state) => Consumer(
            builder: (context, ref, _) => InvitationPreviewScreen(
              opaqueToken: state.pathParameters['token']!,
              onAdmitted: (preview) => context.go('/rooms/${preview.room.id}'),
              onRequestMembership: (preview) async {
                final membership = ref.read(membershipRepositoryProvider);
                await membership.joinSig(sigId: preview.sig.id);
                await membership.joinSubgroup(
                  sigId: preview.sig.id,
                  subgroupId: preview.subgroup.id,
                );
                ref.invalidate(communityCatalogProvider);
              },
            ),
          ),
        ),
        GoRoute(
          path: '/account-status',
          builder: (_, _) => const AccountStatusScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, _) => LoginScreen(
            onSignUp: () => context.go(authPath(context, '/signup')),
            onForgotPassword: () =>
                context.go(authPath(context, '/reset-password')),
          ),
        ),
        GoRoute(
          path: '/signup',
          builder: (context, _) => SignUpScreen(
            onSignIn: () => context.go(authPath(context, '/login')),
          ),
        ),
        GoRoute(
          path: '/reset-password',
          builder: (context, _) => ForgotPasswordScreen(
            onBackToLogin: () => context.go(authPath(context, '/login')),
          ),
        ),
        GoRoute(
          path: '/profile/setup',
          builder: (context, _) => Consumer(
            builder: (context, ref, _) => ProfileSetupScreen(
              onCancel: () => signOutAccount(context, ref),
            ),
          ),
        ),
        GoRoute(
          path: '/profile/edit',
          builder: (_, _) => const AccountProfileEditScreen(),
        ),
      ],
      if (mode == AppMode.preview) ...[
        GoRoute(
          path: '/preview-scanner',
          builder: (_, _) => const ScannerPreviewScreen(),
        ),
        GoRoute(
          path: '/preview-scanner/capture',
          builder: (context, _) => InviteScannerScreen(
            routeObserver: scannerObserver,
            onResult: (value) => context.canPop()
                ? context.pop(value)
                : context.go('/preview-scanner'),
            onCancel: () => context.canPop()
                ? context.pop()
                : context.go('/preview-scanner'),
          ),
        ),
      ],
      GoRoute(path: '/', redirect: (context, state) => '/home'),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(
          navigationShell: shell,
          showToolbar: !state.uri.path.startsWith('/sigs/'),
        ),
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
                    mode != AppMode.foundation && tab.$1 == 'home'
                        ? HomeScreen(mode: mode)
                        : mode != AppMode.foundation && tab.$1 == 'discover'
                        ? const DiscoverScreen()
                        : mode != AppMode.foundation && tab.$1 == 'progress'
                        ? const ProgressHistoryScreen()
                        : mode == AppMode.connected && tab.$1 == 'profile'
                        ? ProfileViewScreen(
                            onNotifications: () =>
                                context.push('/notification-settings'),
                            onEdit: (_) => context.go('/profile/edit'),
                            onSetUpProfile: () => context.go('/profile/setup'),
                          )
                        : PlaceholderScreen(
                            title: tab.$2,
                            message: mode == AppMode.connected
                                ? 'This study feature is not connected yet. Your account and profile are available in Profile.'
                                : tab.$3,
                          ),
                  ),
                ),
                if (mode != AppMode.foundation && tab.$1 == 'home')
                  GoRoute(
                    path: '/common-hall',
                    name: 'common-hall',
                    pageBuilder: (context, state) =>
                        _tabPage(state, const CommonHallScreen()),
                  ),
                if (mode != AppMode.foundation && tab.$1 == 'discover') ...[
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
                      mode == AppMode.preview
                          ? RoomPreviewScreen(
                              id: state.pathParameters['roomId']!,
                            )
                          : LiveRoomScreen(id: state.pathParameters['roomId']!),
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
            const Text('This page is not available in StudyMates.'),
            const SizedBox(height: 24),
            AppButton(
              label: 'Go to Home',
              onPressed: () => context.go('/home'),
            ),
          ],
        ),
      ),
    ),
  );
}

// The shell owns the Scaffold; each branch page paints its own opaque surface.
Page<void> _tabPage(GoRouterState state, Widget child) =>
    NoTransitionPage<void>(
      key: state.pageKey,
      child: Material(color: AppColors.background, child: child),
    );
