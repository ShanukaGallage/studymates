# Sandali — Step 4 invitation handoff

Branch: `feat/sandali-invitation-preview`, created from fetched `origin/main`
at `ffc6311`. Existing progress work remains on `feat/sandali-progress-history`.

## Initial inspection (historical)

The current contracts still list InvitationPreview and invitation services as
future work. Existing scanner code captures raw text only, not a production
invitation. No agreed versioned payload, token resolver, invite fixtures or shared
invite admission interface is implemented in this baseline.

## Original handoff request (historical draft)

Please provide a small merged contract/model/fixture PR before live services:

- Exact versioned QR payload and manual-code format, token length/character/case
  rules, and concrete equivalent QR/manual examples. Define whether URLs are part
  of the format; if so, specify allowed scheme/host/path. Scanning never opens URLs.
- Agree Sandali's parser filename/path and the resolver's input token type.
  Both camera and manual input must produce the same token for the same resolver.
- Read-only invitation preview model and lookup method signature: room identity/
  title, parent SIG/subgroup identities/titles, current eligibility, and expiry.
- Typed invalid, unsupported-version, expired, revoked, full, membership-required
  and unavailable outcomes, distinguishing them from loading/network failures.
- Explicit membership-enrollment consent semantics and the one checked admission
  callback signature/result type. Include a valid preview followed by full-room
  admission to test the race; Sandali must not create a separate join service.
- Non-sensitive fixtures for valid QR/manual equivalence, malformed and unsupported
  payloads, expired/revoked, full, membership-required and unavailable cases.

This is a request for the producer's decisions, not a new API/schema proposal.
Poojani coordinates identity/membership contracts and Shanuka owns route wiring.

## Small implementation slices once the handoff is merged

1. Agreed parser plus independent `invites_*` tests for normalization and rejection.
2. Invitation display/manual code and fixture-backed preview/error UI, with shared
   controls and a standalone preview. QR rendering waits for an explicitly reserved
   dependency slot; qr_flutter is not currently installed.
3. Explicit Join/consent callback, duplicate-action protection and admission race
   handling using the shared operation; fixture tests, analysis and Android review.

No authentication, Firebase integration, invitation issuance or global routing is
part of this step. No production tokens, passwords or personal data go into QR data.

## Navigation requirements to hand to Shanuka

- Preserve the pending opaque token through login and back navigation.
- Resolve/revalidate the invitation again after login and before admission.
- Show room and parent communities before the explicit Join action.
- Register scanner route visibility handling using its existing observer handoff.
- Do not treat fixture admission success as live seat occupancy.

Step 4 implementation is pending the agreed contract. This first slice adds only
this handoff note; no Dart code, shared config, dependencies, commits or pushes.

## Implementation after merged baseline 5221fd7

The earlier contract blocker is resolved. Reused M3's `InvitationTokenParser`,
`InvitationService`, result models/statuses and `FixtureInvitationService` without
changing them. No second parser or admission service is introduced.

- Canonical QR: `studymates://invite/v1/ABCDEFGHJK23MNPQ`.
- Manual example: `abcd-efgh-jk23-mnpq`.
- Parser accepts 16 uppercase characters from A-H, J-K, M-N, P-Z and 2-9; manual
  normalization removes ASCII spaces/hyphens and uppercases ASCII letters only.
- QR parsing remains strict: arbitrary links, noncanonical spelling, unsupported
  versions, extra segments/query/fragment and disallowed characters are rejected.
- Scanner parser injection happens before raw-capture trimming, so it cannot
  accidentally accept a noncanonical QR by removing whitespace first.

User confirmed a reserved shared dependency slot for QR rendering. Added exactly
`qr_flutter: 4.1.0`; lockfile adds it and transitive `qr` 3.0.3. No existing package
version or Android configuration was changed. Official package reference:
https://pub.dev/packages/qr_flutter . Generation is local/offline.

## Owned presentation files and behavior

`InvitationDisplayScreen(opaqueToken:, roomTitle:, isFixture:)` displays an
already-issued valid token as a QR and grouped manual code. It never issues a
token or includes credentials, personal details or client authority in the QR.
Invalid tokens are not rendered as QR codes.

`InvitationPreviewScreen(opaqueToken:, onAdmitted:, onRequestMembership:,
isFixture:)` consumes `invitationServiceProvider`. This provider deliberately
throws when unconfigured; it never injects fixtures on a backend error.
`invitationPreviewProvider(token)` performs the shared resolver call and rejects
malformed opaque tokens locally. Resolution does not join a room.

Preview shows room, SIG, subgroup and descriptive occupancy before explicit Join.
Invalid, expired/revoked, full, unavailable and network failure are distinct from
loading/ready states. Join delegates only to `admitInvitation`, guards repeated
taps and terminal success, and reports a full-room race without claiming admission.
Uncertain admission/network failures require explicit recheck before another
attempt. Idempotent production writes still belong to M3; UI guarding alone does
not provide exactly-once server admission.

Membership-required preview requests explicit named-community consent, then
invokes the supplied membership callback. The checkbox never enrolls anyone or
bypasses membership checks. After that callback, the resolver is called again;
Join is available only when the resulting preview is ready. With no membership
callback, the action is disabled and navigation guidance is shown. The eventual
Join passes the captured consent to the shared admission method.

Late admission/membership results are ignored after disposal or token changes.
An admitted callback is never called for full/error/membership outcomes. Fixtures
explicitly label their admitted result as not a live seat reservation.

`InviteScannerScreen` keeps its existing raw-spike behavior by default. Supply
both `parseQr: InvitationTokenParser.parseQr` and
`parseManual: InvitationTokenParser.parseManual` for the invitation flow. Both
return the same opaque token through `onResult`, only after camera shutdown.
Malformed input does not consume the interaction. Existing route/lifecycle
cleanup is retained. Main router/raw scanner preview are unchanged.

## Standalone fixture preview and phone checklist

```powershell
flutter run -d <device-id> -t lib/preview/invites_flow_preview.dart
```

For the previously problematic Android 17 emulator only, the temporary diagnostic
option `--no-enable-impeller` can be used; no renderer manifest change is made.

1. Display invitation QR and code. Scan it on another device, or type the displayed
   code. Expect the same room/SIG/subgroup; no admission before Join.
2. Join the valid fixture: see the explicit fixture-only admitted result once.
3. Select invalid, expired, revoked, fullRoom or unavailable: no Join action.
4. Membership-required: no Join before consent plus the separate fixture membership
   callback and successful revalidation. Missing callback cannot enroll anyone.
5. Full after preview: valid preview, then Join returns full. Recheck shows full.
6. Lookup error once: Retry resolves. Join error once: recheck, then retry Join.
7. Long room/community names: narrow portrait/landscape and large text stay
   scrollable. Loading scenario stays loading until a different fixture is selected.
8. Scanner: reject arbitrary links, whitespace-wrapped QR and v2 payloads; accept
   the canonical v1 QR and normalized manual code exactly once.

`invites_flow_fixtures.dart` delegates admission to M3's fixture and adds only
UI scenarios: room-full race, network errors, held loading, long names and explicit
fixture membership. No Firebase, production enrollment or room write is performed.

## Concrete handoff for Shanuka

- Register the existing RouteObserver on the Navigator presenting the scanner.
- Supply both parsers; interpret `onResult` as an opaque token and open the new
  preview screen. Do not route that token through the old unverified raw-result UI.
- Preserve that token through login/back; invalidate/reload the preview after
  login or membership changes. Request membership through M2's agreed operation
  after explicit consent. Do not treat consent as authorization.
- Inject the agreed InvitationService via invitationServiceProvider. Only use
  the fixture service in explicitly labelled preview mode.
- On admitted, navigate using preview.room.id through the shared room path;
  do not call another join/claim method. On uncertain failures, rely on M3's
  checked/idempotent production method and revalidate before retry.
- Existing app routes, account guards, central preview bindings and the pending
  invitation-through-login integration were not changed by this feature slice.

These are Step 4 presentation/fixture changes. Production invitation lookup,
admission, identity and real memberships await Step 5 integration. No commits,
pushes or backend deployment have been performed for this implementation.

## Verification — 16 November 2026

- `flutter pub get`: passed, only the approved QR-rendering additions in lockfile.
- Changed Dart files formatted; `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub test/invites_flow_test.dart test/invites_scanner_screen_test.dart`:
  all 23 tests passed. This includes production-parser scanner injection while
  preserving the original raw-capture/app-scanner regression coverage.
- Full `flutter test --no-pub`: 212 passed, five failed in other-owner tests below.
  Reproduced exactly those same five failures on an untouched archive of HEAD
  baseline `5221fd7`, resolving that copy's own dependencies in a temporary folder.
  No baseline/shared tests were edited to hide failures.
- Debug APK for `lib/preview/invites_flow_preview.dart` built successfully and ran
  on Android 17 emulator `emulator-5554`, using the existing temporary Impeller
  opt-out. No Android config change. Existing Firebase/KGP warnings were emitted.
- Inspected QR/manual display screenshot `%TEMP%/invites-display.png`, typed
  `abcd-efgh-jk23-mnpq`, inspected room/SIG/subgroup preview screenshot
  `%TEMP%/invites-preview.png`, and pressed Join. The explicit fixture-only admitted
  message appeared and Join was removed. No real seat, account or membership
  operation was invoked.
- Fresh phone-camera decoding of the new v1 QR, all physical-device error cases,
  and production login/back token preservation are not claimed by these checks.

## Cross-owner failures reproduced on clean main

Run `flutter test --no-pub test/community_preview_test.dart
test/firestore_community_repository_test.dart` on baseline `5221fd7`:

1. `firestore_community_repository_test.dart`: controller provider exposes loading
   state while loading (expected isLoading true, got false).
2. `community_preview_test.dart`: search, join hierarchy, open room, return and
   leave consistently (expected No matches text absent).
3. Same file: deep links, missing IDs and tab restoration use shared routes.
4. Same file: preview scenarios show empty, loading and recoverable errors
   (expected No communities yet text absent).
5. Same file: narrow large-text screens handle long names, empty lists and full
   rooms (expected full-room message absent).

These need Poojani/Shanuka review under community/provider/shared-preview ownership.
They are not fixed in M4's invitation paths. During eventual account integration,
key/recreate the invitation UI/service scope on identity changes so consent and
pending requests from another account cannot carry forward.

Later emulator troubleshooting: UI hierarchy was present but the screenshot was
black and Android reported no focused window/NOT_VISIBLE. Restarting only the
app with software rendering did not recover it. Rebooted emulator-5554 without
wiping data, waited for boot completion, then relaunched with both temporary
`--no-enable-impeller --enable-software-rendering` options. Inspected the launcher
screenshot `%TEMP%/invites-recovered.png` and confirmed Android window focus was
restored. Reboot and renderer flags changed together, so root cause is not
isolated. No app code or Android configuration was changed for this recovery.

## User verification follow-up

The user confirmed the emulator's valid preview/explicit Join, room-full-after-
preview race, consent/membership/revalidation flow, lookup/admission error retries,
and valid manual input plus arbitrary-URL rejection. A user screenshot also shows
long room/community names wrapping in the preview.

On Samsung SM A107F / Android 11 (`R9DMC09WXWJ`), the coding agent inspected the
Step 4 launcher. The user then confirmed scanning the displayed invitation QR.
A subsequent device UI-hierarchy inspection directly showed Review invitation,
ESP32 Study Room, IoT Study Group, ESP32, descriptive occupancy, Join room and
Recheck invitation. This confirms a real-phone camera-to-preview path by user
report plus an observed resulting screen. It does not prove live server admission.
That scan's preview showed 3 of 6 fixture seats; occupancy can change within the
in-memory fixture after earlier test joins and is not a synchronized real room.

The user subsequently confirmed the phone's explicit Join returned the expected
fixture-only admitted result and removed Join. This last outcome is user-reported,
not independently inspected by the agent. Repeated recognition/lifecycle tests
for the new v1 flow are not yet independently observed. Production login/back
token handoff and live services remain outside these fixture checks.

After verification, the user authorized publication in meaningful commits:
approved QR-rendering dependency setup separately from the invitation UI/parser
integration, fixture scenarios and tests. PR review must retain the five clean-main
community failures above as a visible cross-owner issue; no all-tests-green claim
or production admission claim is made.
