# Sandali — Step 1: baseline and camera spike plan

Inspection date: 15 November 2026. Local scanner dependency setup is verified;
scanner UI and camera hardware verification remain future work. Sections before
the setup verification update describe the initial inspection, not current status.

## Initial local baseline evidence (historical)

- Branch: `feat/sandali-invitations`.
- Inspected commit: `a9bde2b6a78e5d3884a871adfa49ec1c30c2173f` (`first UI build`).
- Working tree was clean before this note.
- Invites and progress folders contain `.gitkeep` placeholders only.
- Router has four placeholder tabs and preview-only `/components`; no room route.
- The supplied common plan describes newer room/community work absent here.
  Shanuka must identify the published shared baseline before implementation.
- `adb devices -l`: no connected devices. Sandali's Android version and latest
  room-preview execution remain unverified. Do not use Shanuka's device details.
- README specifies Flutter 3.50.0 / Dart 3.14.0; pubspec requires Dart ^3.14.0.
  PATH and local.properties point to a folder named flutter_windows_3.47.5-stable.
  Folder names do not prove installed versions. `flutter --version` did not
  return during inspection; actual SDK compatibility remains unconfirmed.

## Initial dependency proposal (historical)

Ask Shanuka to confirm ordering with Poojani's Firebase dependency PR and reserve
one short slot for `pubspec.yaml`, `pubspec.lock`, and any needed Android config.
No shared config or dependency has been changed in this slice.

- Scanner candidate: `mobile_scanner` 7.5.0. Its tagged pubspec requires Dart
  ^3.7.0 and Flutter >=3.29.0. Resolve against the actual SDK in the reserved slot.
- Its Android source specifies minSdk 23, compileSdk 36 and Java 17. Current app
  uses Flutter-provided SDK values and Java 17; verify the resolved SDK values
  and SDK installation before deciding whether an app config edit is needed.
- Current project declares AGP 9.3.1, Kotlin 2.4.20 and Gradle 9.5.0. These have
  not been build-tested with this candidate. Do not upgrade them speculatively.
- Plugin manifest supplies CAMERA permission and optional camera hardware through
  manifest merging. Inspect merged manifest; avoid redundant permission entries.
  Runtime permission denial still needs screen handling.
- Keep default bundled ML Kit for a spike without first-use model download.
- QR rendering candidate: `qr_flutter` 4.1.0, needed later for invitation display.
  A known QR displayed externally is sufficient for the first scanning proof;
  defer this dependency until display work unless the team reserves both together.
- Neither candidate is in the existing lockfile. Do not add a second camera or
  permission package without a concrete missing capability.

Official references checked:

- https://pub.dev/packages/mobile_scanner
- https://raw.githubusercontent.com/juliansteenbakker/mobile_scanner/v7.5.0/pubspec.yaml
- https://raw.githubusercontent.com/juliansteenbakker/mobile_scanner/v7.5.0/android/build.gradle.kts
- https://raw.githubusercontent.com/juliansteenbakker/mobile_scanner/v7.5.0/android/src/main/AndroidManifest.xml
- https://pub.dev/packages/qr_flutter

## Original implementation sequence (historical)

1. Confirm team baseline, actual SDK, phone Android version and room preview.
2. In the agreed slot, add scanner dependency, resolve lockfile, inspect Android
   requirements, run analysis/tests and build a preview APK. Commit that slice.
3. Step 2: add an isolated scanner screen and test callback in owned presentation
   paths. No global route, authentication, invitation resolution or room admission.
4. Add one-result handling, manual fallback, denial/retry guidance and lifecycle
   handling in focused follow-up commits with independent `invites_*` tests.

Use `STUDYMATES_CAMERA_SPIKE_ONLY` as a known test QR payload. It is not a valid
production invitation. Stop scanning before returning it through the callback;
release the camera when covered, backgrounded or exited. Never open scanned URLs.

## Phone verification record (pending)

- [ ] Team confirms identical baseline SHA.
- [ ] Record Sandali's device model and Android version.
- [ ] Run `flutter run -d <device-id> -t lib/main_preview.dart` on that baseline.
- [ ] Open latest room preview and record the actual route and result.
- [ ] After Step 2, read known QR exactly once; cancel/reopen safely.
- [ ] Deny camera permission; verify retry/settings guidance and manual fallback.
- [ ] Background/resume and cover/uncover scanner; verify camera release/restart.
- [ ] Repeated detections produce one callback per interaction.

Step 1 is still pending baseline agreement, dependency slot and phone evidence.
No camera hardware, Flutter analysis, test suite or APK build passed in this slice.

## Setup verification update — 15 November 2026

This update supersedes the pending local setup findings above. The earlier
inspection is retained as a record of the initial state.

- Shared preview baseline: `9c222c66051706682ab57b7a4b2a90f4b42455c6` from
  `origin/main`. Current local Git history records its merge as `69c8c39`
  (`Merge Shanuka room preview baseline`). There is no pending merge now.
- Scanner dependency commit: `c9f1c55` (`chore(m4): add QR scanner dependency`).
  These commits already existed when this documentation-only update began;
  this update creates no commit and does not establish push or PR status.
- Shanuka's dependency/Android edit approval was supplied by the user.
- Actual installed toolchain: Flutter 3.50.0 stable / Dart 3.14.0.
- Added exact direct dependency `mobile_scanner: 7.5.0`. New transitive lockfile
  entries: `plugin_platform_interface` 2.1.8 and `web` 1.1.2. No existing package
  was upgraded. `qr_flutter` remains deferred until invitation display work.
- No Android source/config edit was needed: Flutter resolves compileSdk 36,
  targetSdk 36 and minSdk 24; existing Java compatibility is 17. The plugin needs
  compileSdk 36 / minSdk 23 / Java 17. The successful APK's merged manifest
  contains CAMERA permission and camera hardware with `required="false"`.
- Default bundled ML Kit retained. No scanner UI or runtime camera flow exists.
- `flutter pub get`: passed.
- `flutter analyze --no-pub`: passed, no issues.
- `flutter test --no-pub`: passed, 34 tests.
- `flutter build apk --debug --no-pub -t lib/main_preview.dart --verbose`:
  passed after dependency-download delays. APK: `build/app/outputs/flutter-apk/app-debug.apk`.
- APK SHA256: `5A6ABDE6376EEF565DAEABD94A0ADA8F1B5C0A5F1C562F31E89D755910D8ED02`.
- Ran the built preview APK on `emulator-5554`, model `sdk_gphone64_x86_64`,
  Android 17. Opened Discover, Explore IoT, Join SIG, Open ESP32, Join subgroup,
  Preview First Sensor Project. The room route `/discover/rooms/first-sensor`
  opened with three sample occupants and three available seats. Inspected the
  screenshot and accessibility hierarchy; this is local sample data only.
- Screenshot captured at `%TEMP%/studymates-room-step1.png` for this session.
- User-supplied screenshots also confirm six seats, three sample occupants and
  Seat 4 selected locally, with the explicit message that no seat was claimed.
  The goal panel still says there is no preview goal and Start is disabled.
  Goal saving and enabled Start behavior were not verified by these screenshots.
- User selected emulator verification for now. Sandali's physical phone model,
  Android version and room-preview run are still pending; camera hardware has
  not been tested.

Local dependency setup and emulator verification are complete. Full team Step 1
closure still requires confirmation of dependency PR review/merge and teammates
pulling the resulting lockfile, plus the physical-phone baseline check. Local
commits are present as recorded above; remote publication and PR status have not
been checked in this documentation-only update. No code, dependency or Android
configuration changes, commits, pushes or merge operations were made in this update.
