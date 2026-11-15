# StudyMates

Android study-community app: find your people, learn together. The assignment
requires a **five-minute live Android demonstration**, with no report,
presentation or formal rubric. These repository notes support development only.

## Toolchain and setup

Verified on 15 November 2026: **Flutter 3.50.0 stable / Dart 3.14.0**.
Use the same Flutter version and retain `pubspec.lock`.

```bash
git clone https://github.com/ShanukaGallage/studymates.git
cd studymates
flutter pub get
flutter doctor -v
flutter devices
flutter run -t lib/main_preview.dart
```

Select an Android device when prompted; with multiple devices use
`flutter run -d <android-device-id> -t lib/main_preview.dart`.
Enable USB debugging and authorize the computer on a physical phone, or start
an Android emulator. No Firebase configuration is needed for this milestone.

## Entry points and current scope

- `lib/main_preview.dart`: labelled **UI Preview / Local sample data**. Discover
  uses in-memory community/room repositories; the other three tabs remain placeholders.
- `lib/main.dart`: labelled **Foundation only / Not connected**. All four tabs
  remain placeholders, with no preview services or development routes.
- No authentication, Firestore, live rooms, QR scanning or session history exists.
- Riverpod owns repository bindings, catalog state and router lifecycle. go_router
  keeps Discover selected for SIG, subgroup and room detail routes and retains
  tab stacks. Unknown routes/IDs have recovery actions.
- Initial models, membership rules and repository operations are documented in
  [contracts](docs/contracts.md); M2/M3 review is pending before backend integration.

## Try the community preview

```bash
flutter run -t lib/main_preview.dart
```

1. Open Discover, search for IoT, then Explore IoT.
2. Join SIG → Open ESP32 → Join subgroup → Preview First Sensor Project.
3. Try the six-seat room scene. Tap an available seat; it becomes selected after
   a brief local pending state. No seat has been reserved.
4. Go back and leave the SIG. Its subgroup memberships clear too. Switching tabs
   preserves local membership; restarting the app resets it.
5. Inspect the full Sensor Study Club, empty Quiet Electronics Lab, Programming /
   Flutter, Dart basics with no rooms, and the long-title Design SIG with no subgroups.

The palette icon opens the component gallery. The sliders icon opens **Preview
data**: sample, empty, loading and error-once states, plus reset. Loading remains
until you select another scenario; Retry recovers from error-once. Switching
scenarios resets membership. These tools are separate from product navigation.

## Try the room presentation

After joining ESP32, open First Sensor Project. Its three sample occupants match
its room summary. Available seats are interactive; occupied seats are disabled.
Tap a selected seat to clear it, or select another. The selection never changes
sample occupancy or grants access to a live room.

- Save/edit a local goal (1–160 characters after trimming); Cancel preserves the
  prior goal. The sheet scrolls above the keyboard and supports larger text.
- Expand **Preview controls**, enable the next selection conflict, then tap an
  available seat. Retry that seat after the simulated error.
- Select a seat and save a goal to enable **Start · preview**. It explains the
  future session step; it does not start a timer. **Invite · preview** likewise
  explains the future QR/code step without creating an invitation.
- **Leave room preview** confirms before clearing an existing draft. Navigating
  back out of the page also discards the local draft. Tab switches retain it.
  Losing subgroup membership, changing/resetting scenarios, or restarting clears it.
- The component gallery demonstrates all six states, including the sample
  “yours” state. Selection in the room only becomes “selected,” never “yours.”

The room is drawn in Flutter with separate desk/avatar/interaction layers; no
external artwork, font downloads or new dependencies were added. It is a layout
prototype ready for later artwork and live room data, not a synchronized room.

Material 3 uses the existing `material_ui` package (locked at 1.11.0), whose
installed source supplies the Material widgets used by the starter. Keep these
imports consistent; no package changes were needed. Theme/spacing tokens live
in `lib/core/theme`; reusable controls live in `lib/core/widgets`.

## Checks and manual review

```bash
dart format lib test
flutter analyze
flutter test
flutter run -t lib/main_preview.dart
# Optional preview APK:
flutter build apk --debug -t lib/main_preview.dart
```

Foundation checkpoint: `a9bde2b` (`first UI build`); the working tree was clean
before this milestone. Shanuka confirmed the foundation runs correctly on a phone.
Verified phone: model **23129RAA4G**, **Android 15 (API 35)**;
Android build **AQ3A.240829.003**, confirmed by Shanuka.
Foundation analysis and all eight tests passed again before implementation.

Automated checks cover navigation, membership consistency/parent requirements,
search, missing IDs, empty/loading/error recovery, sample occupancy and narrow
large-text layouts, alongside the original component tests. The prior community
APK built, installed and launched on Android 15 (the display was dozing during
visual inspection). The room milestone adds target-size/activation, semantic
labels/actions, pending/conflict/retry, goal validation/cancel, keyboard layout
and timer-disposal checks. No Android device was connected during room work;
phone runtime and TalkBack review of the room remain pending.

Room milestone verification: formatting and analysis passed; the full suite passed
**21 tests**, and the seven room tests passed again after the visual badge fix.
A rendered scene was inspected with text/icon fonts loaded. The ARM64 debug APK
built successfully at `build/app/outputs/flutter-apk/app-debug.apk`:

```bash
flutter build apk --debug --target-platform android-arm64 -t lib/main_preview.dart
```

The earlier general APK build stalled and was stopped; this successful build is
specifically for the ARM64 demo phone, not a universal architecture build.

On Android inspect all four tabs, selected navigation state, gallery/back,
validation, password visibility, loading/disabled controls and Retry. Try large
system text, narrow portrait/landscape, keyboard open and TalkBack. Confirm the
mode label stays visible. Gallery feedback is local and does not save anything.

## Four-member team and work plans

All four members have reported successfully running the app on their devices.
Before parallel feature work, confirm everyone has the same published preview
commit; the latest local community/room changes still need review and publication.

Read the [common four-member plan](docs/team/00-common-plan.md), then your guide:

| Member | Ownership | Guide |
|---|---|---|
| M1 — Shanuka | Shared UI, room/session presentation, navigation, integration and release | [Step-by-step plan](docs/team/01-shanuka-ui-integration.md) |
| M2 — Poojani | Firebase, accounts, profiles, communities and shared-contract coordination | [Step-by-step plan](docs/team/02-poojani-accounts-communities.md) |
| M3 — Aradhana | Live rooms, seating, sessions, completion writes and invitation services | [Step-by-step plan](docs/team/03-aradhana-rooms-sessions.md) |
| M4 — Sandali | Camera/manual invitations and read-only history/progress | [Step-by-step plan](docs/team/04-sandali-invites-progress.md) |

These are proposed assignments using the supplied name order. Availability and the
demo deadline are still unspecified, so the plans use completion gates rather than
calendar promises. Each member implements their feature screens using the shared
components. Shared-file ownership, contract handoffs, blockers and Codex task
prompts are included in the guides.

The four-member common plan supersedes the original five-member allocations.
Keep the two original StudyMates guides as design/product background; do not
repeat their completed startup tasks. The five-minute demo requires no slides,
report or formal rubric. Current implementation status remains documented above.
