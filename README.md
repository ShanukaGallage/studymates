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

- `lib/main_preview.dart`: labelled local UI samples without Firebase. Home,
  Discover, classrooms, demo sessions, history and scanner remain independent.
- `lib/main.dart`: Firebase-backed accounts, profiles, communities, rooms, atomic
  seating, immutable shared schedules, current-user session return, invitations
  and private completion history. Deploy the checked-in Firestore rules/indexes
  before production use; local implementation does not prove deployed configuration.
- `--dart-define=STUDYMATES_EMULATOR_HOST=127.0.0.1`: explicitly labelled local
  backend with real Firebase SDK operations against shared emulator data. Debug
  Android permits cleartext only to localhost/emulator addresses.
- App access requires authenticated UID plus its matching persisted profile.
  No fixture repository substitutes for a backend failure.
- See [demo runbook](docs/demo-runbook.md) for setup, deployment prerequisites,
  credit policy, two-phone checks and the five-minute rehearsal sequence.

## Try account and feature integration

```bash
flutter run -t lib/main.dart          # Existing Firebase Android configuration
flutter run -t lib/main_preview.dart  # Explicit fixtures, no Firebase required
```

Account mode: signed out → login/signup → missing profile → setup → Home; open
Profile to edit the display name or use the toolbar to sign out. Profile save is
observed from Firestore before access is granted. Errors remain errors, never fake
signed-out identities or sample profiles. Return navigation accepts only known
local account destinations. No invitation-link contract is implemented yet.

Before live account verification, Poojani must confirm email/password sign-in is
enabled and access to `users/{uid}` is restricted to its authenticated owner in
`studymates-dev`. Deployed rules have not been inspected; this checkout contains
no Firestore rules file. No backend configuration or rules were deployed here.

Preview mode: open Progress to view sample history and the separate demo view.
Preview data's sample/empty/loading/error-once controls also configure history;
Reset resets its repository. Use the scanner toolbar icon to capture a QR or enter
text manually, then return to the same tab. Camera access starts only on opening
capture; its route observer stops the camera when covered.

The integration tests use fake identity/profile streams and a fake camera. They
cover profile-based access, stale-user data rejection, redirects, sign-out, startup
retry, Progress navigation and camera lifecycle through the real app router.
Live account writes and physical camera capture require separate device testing.

Integration verification (16 November 2026): formatting, `flutter analyze`, all
**146 tests**, and ARM64 debug APK builds for both entry points passed. No Android
device was connected for this integration pass, so phone checks of the new account,
history and scanner flows remain pending. Earlier classroom checks below apply
only to that earlier milestone.

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
- Select a seat and save a goal to enable **Start · preview**. It opens a local
  45-second focus / 15-second break demo with end confirmation and goal review. **Invite · preview** likewise
  explains the future QR/code step without creating an invitation.
- **Leave room preview** confirms before clearing an existing draft. Navigating
  back out of the page also discards the local draft. Tab switches retain it.
  Losing subgroup membership, changing/resetting scenarios, or restarting clears it.
- The component gallery demonstrates all six states, including the sample
  “yours” state. Selection in the room only becomes “selected,” never “yours.”

The room now uses the [classroom design](docs/design/room-classroom.html): six
illustrated desk cards in two columns, a green classroom header, occupant names
and explicit seat states. Cards stack into one column below 280 logical pixels
of available width or above 150% body-text scaling. Names and controls wrap;
the page scrolls vertically. Original desk/avatar art is painted in Flutter,
separate from labels and interaction; no external assets or dependencies were added.
The `RoomScene` constructor, seat models and callbacks remain unchanged for M3.
This is still a local preview, not a synchronized room. The mockup's live
connection, host and focus samples are not connected application behavior.

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

Classroom update: formatting, analysis and all **61 tests** passed, including
responsive desk cards at 320px with 200% text and the existing selection/retry,
semantics and goal-sheet checks. The new failure-action color pair also passed
the contrast check. A Flutter render of all six states was visually inspected.
`flutter run -d 704285f1 -t lib/main_preview.dart` built and launched on the
23129RAA4G / Android 15 phone. The first build downloaded SDK Platform 34 and
native dependencies. On 16 November, the unlocked phone passed the Discover →
IoT → ESP32 → First Sensor Project walkthrough: two-column classroom rendering,
scrolling to all six seats, local seat selection and goal entry/save with the
keyboard open were checked. Selection remained explicitly local, not a reservation.
TalkBack and large-system-text review on the physical phone remain pending;
large-text layout is covered by the widget tests above.

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

## Study-session UI preview

From Discover → IoT → ESP32 → First Sensor Project, join the sample communities,
select an available seat, save a goal and tap **Start · preview**. The full-screen
flow hides tab navigation while studying. Wait for focus/break completion or end
early, mark the goal outcome, then review the summary. Return to the room or open
sample Progress; no completion is written and history totals remain unchanged.

Expand **Session preview controls** for connection interruption, seat-unavailable
and one-shot summary failure/retry. These are UI simulations. The display derives
phases from M3's existing UTC timestamp calculator, with an injectable clock for
tests; it does not implement participation credit or backend session operations.
The 45/15 split is a preview fixture, pending confirmation for live demo timing.

Session UI verification (16 November 2026): formatting, analysis and all **164
tests** passed, including UTC phase changes, early-end confirmation, failure/retry,
connection recovery, goal outcome, room-start handoff and 320px/200% text layout.
The preview APK built and launched on the Android 15 phone. The device showed its
lock screen during automated inspection; Shanuka subsequently reported the
session flow was working on the phone. This is a user-reported visual check. No live session, seat admission or completion persistence was tested.

## Lavender Home

Home now follows the approved lavender/purple visual direction, with a focus card,
community list and study shortcuts. Preview memberships update Home and Discover
together. Account Home uses the saved profile and explicitly identifies community
services as pending. No active session, progress totals or AI features are invented.
See `docs/design/design-system.md` for the updated shared palette and spacing.

Lavender Home verification: analysis and all **231 tests** passed after the newly
merged membership and seat-policy changes. Home tests cover membership updates,
community navigation, loading/retry and 320px large text; contrast checks cover
hero text and the new accent surfaces. A Flutter render with Roboto was inspected.
The earlier Home APK launched, but the phone disconnected before the final
provider fix could be installed; final on-device review remains pending.

Progress overview now uses pastel summary cards, local day/week/month/all-time
filters, a seven-day study-time chart and a goal-outcome ring. Charts/filter results
use loaded pages only; the normal all-history summary stays independent. Demo
records remain separate. Analysis and all **258 tests** passed; a Flutter render
was visually checked. Android verification of this dashboard is pending.

The Progress study-year heatmap shows daily credited time with purple intensity,
a full-year overview, scrollable calendar, year navigation and day inspection.
It uses loaded records, clearly marks incomplete history and updates on paging.
Future dates are blank; demo activity stays separate. Complete annual coverage
without paging requires a future current-user daily-aggregate repository method.
Heatmap verification: analysis and all **260 tests** passed, including leap-day,
year boundaries, duplicate records, intensity thresholds, demo exclusion and
large-text date inspection. The ARM64 preview APK built successfully. Physical
phone review of the heatmap remains pending.

Discover now has a responsive community-card grid, category/membership badges,
subgroup counts and All communities / My communities filters combined with search.
Analysis and all **261 tests** passed; the 390px Flutter render was inspected.
Final on-device visual verification of the Discover refresh remains pending.

## Connected demo implementation checkpoint

Shanuka is covering Aradhana's backend/integration work for the demo. The new
`features/study/data` adapters reuse M2 membership transactions, M3 seat policy
and active-session model, and M4 invitation/history consumers. Seat release and
renewal accept an expected claim ID. The foreground app renews a valid seat every
30 seconds. Session phase boundaries derive from a server-recorded start. Stable
per-user/session completion IDs prevent duplicate writes; demo credit is separate.

Firebase rules enforce paired claims, membership, private goals/history and bounded
credit. `functions/` supplies trusted membership-leave cleanup and host transfer.
The Firebase CLI currently has no authorized account; no production deployment
was performed. Earlier milestone notes below/above are historical checkpoints.

Connected verification (16 November): formatting and analysis passed; **262 Flutter
tests** passed. The Android real-SDK integration test passed on 23129RAA4G /
Android 15 using two emulator identities: conflicting claims, cross-room seat
exclusion, renewal, invitation revocation, shared schedules, revalidation, stable
completion retry and private history. Firestore rule tests passed for authorization,
completion credit bounds, demo isolation and simultaneous claims. Trusted cleanup
tests passed for seat release, host transfer and repeat execution. This is evidence
for the local backend, not a production deployment or a two-physical-phone rehearsal.

Reconciled main checkpoint: retained PR #25 membership retry fixes and PR #26/#31
TypeScript room helpers/tests and alternative room adapter; restored the tested
connected application and lavender UI from `Shanuka/conflict_resolving`. Backend
dependencies are no longer tracked. Analysis, **278 Flutter tests**, **35 backend
tests**, membership/room/session rules and trusted cleanup emulator checks passed.
The hosted-Firebase ARM64 debug APK built. Production deployment still requires
Firebase CLI authentication and a project plan supporting Cloud Functions.

## Room capacity and visibility

Connected room creation asks for 2–40 desks and Public or Private. Public rooms
are open to eligible subgroup members; private rooms remain discoverable with a
lock label and ask for an invitation code before admission. Hosts/creators enter
their own rooms directly. Previously admitted members may return. Existing rooms
remain public with six desks. Private room codes are entered after opening the
room, or through the existing scanner/invitation flow. Invite expiry/revocation
blocks new admissions; membership checks continue for all seat operations.

Redeploy rules before installing this update:

```bash
npm exec --yes --package firebase-tools -- firebase deploy \
  --project studymates-dev --only firestore:rules
```

Capacity/privacy verification: analysis and **281 Flutter tests** passed. The
expanded Android integration test passed against Firebase emulators, including
40-desk creation, desk-40 claim, private direct-entry denial and verified-code
admission. Rules tests cover capacity bounds, unknown/out-of-range desks, private
seat reads, forged grants, expired/revoked/other-room invitations and token privacy.
Membership rules and trusted cleanup regressions also passed. Hosted rules have
not been redeployed by this task; repeat the two-phone rehearsal after deployment.

## Spark-compatible membership leave

Leave SIG/subgroup no longer waits for a Cloud Function. `SparkMembershipCleanup`
ends only the current user's related participation, releases their seat and closes
rooms they host in the departure scope before membership finalization. Their goal
is recorded as unfinished; credit follows existing server-validated focus rules.
It cannot transfer hosting or edit another user's participation. SIG ownership
transfer/closure and subgroup cascade still use M2's membership protocol.

Deploy current rules, then use Discover → **Finish pending leave requests** to
recover an earlier timed-out departure. This may also finish owner departures
after their SIG has already closed. Foreground errors preserve the retry path.
Deploy only `firestore:rules,firestore:indexes` on Spark; Functions are optional.

Leave verification: analysis is clean and **283 Flutter tests** passed. Firestore
membership/security regressions passed. On the Xiaomi 23129RAA4G (Android 15),
the connected integration test passed against Firebase emulators, including
subgroup departure, SIG departure, seat release, hosted-room closure and cleanup
retry. Hosted rules still require deployment and a two-account rehearsal.

## Invitation sharing and screen sleep

Live room invitations offer **Share invitation** through the Android share sheet,
including the manual code and entry instructions. Preview fixtures cannot be
shared. The selectable code remains available if sharing fails. Sharing does not
reserve a seat, bypass membership, or configure Android deep links.

The connected session screen offers **Keep screen awake**, off by default. It
applies only while that screen is visible and the app is foregrounded, and releases
on departure or completion. It does not run background work or extend seat leases.
Packages: `share_plus` and `wakelock_plus`; existing dependencies remain pinned.

Verification: formatting, analysis and 286 Flutter tests passed; the normal Android
debug APK built successfully. The native integration test passed on the Xiaomi
23129RAA4G (Android 15): screen-awake is off initially, enables on selection and
releases after leaving. Manually check the invitation share sheet and screen-awake
background/resume behavior. First builds may install SDK Platform 35 and CMake
through Gradle.

## Branded launch

Android launch themes use lavender in both system light/dark modes, with an
original book-and-two-learners vector emblem and Android 12+ splash resources.
`lib/app/startup_splash.dart` continues the branding while Firebase initializes:
gentle entrance, tagline and loading indicator, with no artificial delay. Startup
errors still show Retry. Preview remains Firebase-free and shares the native
launch artwork. Narrow/landscape layouts and 200% text scaling are tested.
