import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app/app.dart';
import 'app/app_mode.dart';

void main() => runApp(
  ProviderScope(
    overrides: [appModeProvider.overrideWithValue(AppMode.preview)],
    child: const StudyMatesApp(),
  ),
);
