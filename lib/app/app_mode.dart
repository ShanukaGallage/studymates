import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppMode { foundation, preview }

// PreviewScope explicitly injects local repositories; foundation stays disconnected.
final appModeProvider = Provider<AppMode>((ref) => AppMode.foundation);
