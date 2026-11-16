import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppMode { foundation, preview, connected }

// Entry points select connected services or explicit local preview repositories.
final appModeProvider = Provider<AppMode>(
  (ref) => AppMode.foundation,
  dependencies: const [],
);
