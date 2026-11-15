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

- `lib/main_preview.dart`: labelled **UI Preview**, four placeholder tabs and a
  development component gallery (palette button in the app bar).
- `lib/main.dart`: labelled **Foundation only / Not connected**. Same placeholder
  tabs, without the gallery route. Run with `flutter run -t lib/main.dart`.
- Both entry points are local UI shells. There is no authentication, Firestore,
  live room, QR scanner, session history or fake domain repository yet.
- `/home`, `/discover`, `/progress`, `/profile` use a go_router indexed tab shell.
  `/components` exists only in preview mode. Unknown paths offer Home recovery.
- Riverpod provides app mode and router lifecycle. Feature data will use repository
  providers later; see [contracts](docs/contracts.md).

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

Baseline analysis and counter test passed. Foundation formatting, analysis and
all eight tests also passed; doctor reports no issues and Android
licenses are accepted. No Android device was connected (only Linux and Chrome),
so starter/preview Android execution and phone visual verification are pending.
Demo phone Android versions are not recorded yet. Widget checks cover routing,
mode separation, form validation/password visibility, local retry, button states,
320px layouts with 2× text and simulated keyboard insets, and active text contrast.

On Android inspect all four tabs, selected navigation state, gallery/back,
validation, password visibility, loading/disabled controls and Retry. Try large
system text, narrow portrait/landscape, keyboard open and TalkBack. Confirm the
mode label stays visible. Gallery feedback is local and does not save anything.

## Ownership

| Member | Ownership |
|---|---|
| M1 — Shanuka | UI/design system, navigation, integration and release |
| M2 | Accounts, profiles, Firebase, communities and shared contracts |
| M3 | Rooms, seating, sessions, participation and reconnection |
| M4 | Read-only history/progress; optional milestones |
| M5 | QR invitations and real-phone camera checks |

M2–M5 names remain to be assigned. Read both planning documents in `docs/` for
product direction; this milestone intentionally stops at the UI foundation.
Use small feature branches, review shared-contract changes with their owners,
and have a teammate verify clone-and-run before broad handoff.
