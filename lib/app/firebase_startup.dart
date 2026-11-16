import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/state_views.dart';
import '../firebase_options.dart';
import 'app.dart';
import 'app_mode.dart';

final firebaseBootstrapProvider = FutureProvider<void>((ref) async {
  if (!Firebase.apps.any((app) => app.name == '[DEFAULT]')) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}, retry: (count, error) => null);

class FirebaseStartup extends ConsumerWidget {
  const FirebaseStartup({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(firebaseBootstrapProvider)
      .when(
        data: (_) => ProviderScope(
          overrides: [appModeProvider.overrideWithValue(AppMode.connected)],
          child: const StudyMatesApp(),
        ),
        loading: () =>
            _startupPage(const LoadingView(message: 'Starting StudyMates…')),
        error: (_, _) => _startupPage(
          ErrorView(
            message: 'StudyMates could not connect to its account services.',
            onRetry: () => ref.invalidate(firebaseBootstrapProvider),
          ),
        ),
      );
}

Widget _startupPage(Widget child) => MaterialApp(
  title: 'StudyMates',
  debugShowCheckedModeBanner: false,
  theme: AppTheme.light,
  home: Scaffold(
    body: SafeArea(
      child: ListView(padding: const EdgeInsets.all(24), children: [child]),
    ),
  ),
);
