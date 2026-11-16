import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app/firebase_startup.dart';

void main() => runApp(const ProviderScope(child: FirebaseStartup()));
