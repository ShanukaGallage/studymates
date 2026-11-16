import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'app_mode.dart';
import 'account_screens.dart';
import '../core/theme/app_theme.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'StudyMates',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800),
        ),
        toolbarHeight: 56,
        actions: [
          if (ref.watch(appModeProvider) == AppMode.connected)
            IconButton(
              tooltip: 'Scan invitation',
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: () => context.push('/scan'),
            ),
          if (ref.watch(appModeProvider) == AppMode.connected &&
              navigationShell.currentIndex == 3)
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
              onPressed: () => signOutAccount(context, ref),
            ),
          if (ref.watch(appModeProvider) == AppMode.preview)
            IconButton(
              tooltip: 'Scanner preview',
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: () => context.push('/preview-scanner'),
            ),

          if (ref.watch(appModeProvider) == AppMode.preview)
            IconButton(
              tooltip: 'Preview data',
              icon: const Icon(Icons.tune),
              onPressed: () => context.push('/preview-data'),
            ),
          if (ref.watch(appModeProvider) == AppMode.preview)
            IconButton(
              tooltip: 'Component gallery',
              icon: const Icon(Icons.palette_outlined),
              onPressed: () => context.push('/components'),
            ),
        ],
      ),
      body: SafeArea(child: navigationShell),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            label: 'Progress',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
