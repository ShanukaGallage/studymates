import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppMode { foundation, preview }

// Neither mode has a backend or fake domain repositories yet.
final appModeProvider = Provider<AppMode>((ref) => AppMode.foundation);
