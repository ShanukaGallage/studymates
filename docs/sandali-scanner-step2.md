# Sandali — Step 2 scanner spike

This is standalone capture UI, not a production invitation or room admission flow.
It uses mobile_scanner 7.5.0 and existing shared theme/buttons/text fields. It
does not change shared routing, dependencies, Android configuration or data models.

## Run independently

```powershell
flutter devices
flutter run -d emulator-5554 -t lib/preview/invites_scanner_spike.dart
```

Replace the device ID for a physical Android phone. Open scanner from the launcher.
The camera permission prompt belongs to opening the scanner, not app launch.
Display an externally generated QR containing exactly `STUDYMATES_CAMERA_SPIKE_ONLY`
on another screen. This string is only a test payload.

The launcher pops the scanner through its explicit callback and displays the raw
test result. Cancel returns without a result. Open scanner again for a new
interaction. The layers icon opens a test dialog covering the scanner route.

## Behavior and boundaries

- QR and manual input use one capture gate. Edge whitespace is trimmed; empty,
  over-2048-character and embedded ASCII control-character input is rejected.
  Case and opaque text are preserved. This is raw-input validation only: final
  versioned invitation parsing waits for Aradhana's contract in Step 4.
- Results are claimed synchronously and returned at most once, only after the
  camera stops. Failed shutdown keeps the result pending for explicit retry.
  Scanned links are never opened. No token is logged or sent to a backend.
- Denied permission offers Retry, Android Settings guidance and manual fallback.
  It does not automatically keep requesting a denied permission.
- Route coverage, backgrounding, manual mode and exit stop/release the camera.
  Return/resume restarts only when the screen is active and has no result.
  A result captured just before backgrounding is deferred until active again.
- Camera operations are serialized. The package owns initial startup so its debug
  cleanup finishes before starting; late startup is reconciled with visibility.
  Disposal cleans up in-flight work. System Back also disposes the screen.

## Integration handoff for Shanuka

`InviteScannerScreen` requires `onResult: ValueChanged<String>`, `onCancel:
VoidCallback`, and a `RouteObserver<ModalRoute<dynamic>>` registered on the
Navigator that presents it. Present as a separate route, outside the tab shell;
hidden tabs alone do not send route coverage events. The development launcher
demonstrates callback/observer wiring. No production router changes are included.

## Verification

Independent tests in `invites_scanner_capture_test.dart` and
`invites_scanner_screen_test.dart` cover input validation, repeated capture/manual
races, shutdown ordering/failure retry, leaving during shutdown, permission denial,
manual fallback, route/background lifecycle, cancel/reopen and delayed startup.
Camera widget tests use a fake platform; they do not prove QR hardware decoding.

Android 17 emulator `sdk_gphone64_x86_64`: permission denial/guidance, retry/allow,
virtual camera preview, manual test callback and camera release were exercised.
The test dialog and backgrounding showed no active camera clients after shutdown.
An initial rapid background/resume run produced a black screen and required an
app restart; a later normal-paced resume restored the scanner. Cancel/reopen also
exposed a blank preview during startup testing; startup handling was revised and
is covered by regression tests. Final emulator retest results are recorded below.

Initial implementation checks on 15 November 2026 (before phone testing):

- `flutter analyze --no-pub`: passed, no issues.
- `flutter test --no-pub`: all 46 tests passed (12 scanner-specific tests).
- Scanner-spike debug APK build: passed after the startup revision.
- Final emulator retest was inconclusive: the emulator again displayed a black
  screen and did not respond to taps, including on the launcher before scanning.
  Accessibility output still contained the launcher but input diagnostics reported
  no focused window/NOT_VISIBLE. Restarting only the app did not consistently
  recover it. Android subsequently displayed "Pixel Launcher isn't responding",
  confirming the test environment was also unresponsive outside StudyMates.
  The cause is not established; do not claim the startup revision
  resolves the black-screen observation. Repeat on a responsive emulator and the
  real phone. Do not substitute the earlier emulator results for final acceptance.
- No actual QR decoding was demonstrated on hardware or the emulator. Synthetic
  captures were used in automated tests; manual callback was exercised on emulator.
- No commits or pushes were made during Step 2.

Recovery check later on 15 November 2026: rebooted `emulator-5554` without wiping
data, then ran the scanner with the temporary `--no-enable-impeller` flag. The
launcher and virtual camera preview rendered again, confirmed by screenshot and
active camera client diagnostics. Reboot and renderer choice were changed together,
so this does not isolate the root cause or prove a permanent fix. No Android config
or source change was made for this workaround. Flutter reports the opt-out is
deprecated; use it as a temporary diagnostic only.

```powershell
flutter run -d emulator-5554 -t lib/preview/invites_scanner_spike.dart --no-enable-impeller
```

## Physical-phone results — user confirmed, 15 November 2026

Device output supplied by the user identifies Samsung SM A107F, Android 11
(API 30), device `R9DMC09WXWJ`. The scanner was launched from the local Step 2
working tree. That implementation and its tests are now recorded in commit
`83bdc2a` (`feat(m4): add isolated QR scanner with manual fallback and lifecycle tests`).

The user confirmed the following in chat; these are user-reported results,
not hardware tests directly observed by the coding agent:

- [x] Camera permission allowed and phone camera opened.
- [x] Laptop QR containing `STUDYMATES_CAMERA_SPIKE_ONLY` scanned on the phone;
  expected test callback result displayed.
- [x] Cancel then Open scanner reopened the camera.
- [x] Home then return to the app restored the camera preview.
- [x] Denying camera permission showed guidance and manual input worked.
- [x] Sustained QR view returned once, without repeated callbacks; opening a new
  scanner interaction allowed a fresh scan (user confirmed after the checklist).

The user also supplied emulator screenshots of successful manual result and
camera preview, and confirmed dialog cover/return and Home/resume on emulator.

## Additional phone reliability checks (not yet confirmed)

- [ ] Android Back/reopen restarts the camera safely.
- [ ] Repeated denial and Settings re-enable recover the camera.
- [ ] Submit empty/control-character input; no result; valid input still works.
- [ ] Cover/uncover using layers dialog; camera indicator turns off/on.
- [ ] Lock/unlock and rapid app switches; no stuck camera or black screen.
- [ ] Leave while permission/start is pending; no late callback or retained camera.
- [ ] Narrow screen, landscape, large text and open keyboard remain scrollable.

The core Step 2 scanner path is implemented and the known-QR, cancel/reopen,
Home/resume and denied-permission/manual paths are user-verified on a physical
phone, including sustained QR view without repeated callbacks. The additional
checks above remain unverified.
No production invitation parsing, lookup, authentication or joining is claimed.
The user authorized commit/push after phone verification. Implementation/tests
and this verification note are kept as separate commits; publication is performed
after committing this note. This note does not claim human PR review or merge.
