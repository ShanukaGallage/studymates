import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/room_scene_models.dart';

// Explicit preview binding; a future room stream can supply these display inputs.
// No fixture fallback is provided to a connected app.
final roomSceneSeatsProvider = Provider.family<List<RoomSeat>, String>(
  (ref, id) =>
      throw StateError('No room scene source configured. Use PreviewScope.'),
);
