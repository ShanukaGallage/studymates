# M4 Step 6 — invitation/history rehearsal and edge cases

Review date: 16 November 2026. Reviewed baseline: `234b805`.
This is a feature verification note, not Sandali's private code explanation.
The private study guide/source companion remain locally excluded from Git.

## Status and evidence boundaries

Step 6 is in progress. Automated UI/logic checks and reported hosted happy-path
checks do not replace current connected-mode camera/network testing or a physical
two-phone rehearsal. The reported pair is a Samsung SM A107F / Android 11 phone
and an Android emulator, using different accounts. No backend deployment, rule
change, completion write-policy change or shared route edit was performed here.

### Reported hosted checks before this review

| Check | Evidence/result |
|---|---|
| Shared occupancy | User confirmed phone and emulator show Sithmi/Sandali seats consistently; screenshot shows Desk 02 Yours and Desk 03 occupied. |
| Back to subgroup and return | User confirmed own seat remained. This does not prove survival beyond lease expiry. |
| Shared demo timing | User reported about one second difference. Exact clock skew was not measured. |
| Participation saved | Screenshot shows demo participation saved, 38 credited focus seconds, goal completed and timer completed. |
| Refresh duplicate display | User confirmed one record remained one row after refresh. This does not alone test concurrent finalization. |
| Restart persistence | User confirmed the saved demo record remained after reopening. |
| Account separation | User confirmed emulator's different account did not show phone account's history. Same-device account-switch regression still needs explicit rehearsal. |
| Live QR invitation | User reported emulator QR scanned on phone, then admission and occupied seat visible on emulator. |
| Live manual invitation | User reported completing manual-code preview/admission check after the supplied steps. No independent screenshot of that outcome. |
| Normal history | Not yet confirmed: the tested completion was a demo. Empty normal history is expected for demo-only use. |

### Reproduced and fixed in M4 paths

`invitationPreviewProvider` originally cached membership-sensitive results by token
only. A retained listener showed both failures in new regression tests:

1. Switch from account A to B with A's lookup in flight: no fresh B lookup started.
2. Sign out after a ready result: the provider still reported ready.

The connected-mode provider now watches the current UID, rebuilds its lookup after
identity changes and returns unavailable without a service read when signed out.
Riverpod discards an older lookup's result after that dependency rebuild. Preview
mode keeps explicit fixture behavior and does not require Firebase authentication.
This is provider-level regression coverage, not proof of every in-flight admission
or membership callback across account changes.

Changed production file:
`lib/features/invites/presentation/controllers/invitation_providers.dart`.
Regression tests: `test/invites_account_scope_test.dart`.

## Repeatable connected-device checklist

Use `lib/main.dart`, internet, and two different accounts in the same SIG/subgroup.
Do not use `main_preview.dart` or the emulator-backend define for hosted checks.
Keep both clients foregrounded for seating/timing checks. A phone plus Android
emulator can exercise shared-backend state; QR hardware still uses the phone.

| Check | Actions | Expected | Current evidence |
|---|---|---|---|
| Camera denied | Android Settings → Apps → StudyMates → Permissions → deny Camera; open scanner | Guidance, retry/settings hint and usable manual fallback; no admission | Earlier scanner-spike user report; current integrated rerun pending |
| Permission retry | Grant camera permission and reopen/retry scanner | Camera usable again; no extra returned result | Current integrated rerun pending |
| Background/resume | Open scanner, Home/lock, then return | Camera pauses while away and resumes safely | Automated fake-camera coverage; hosted phone rerun pending |
| Repeated QR | Keep valid QR in view | One return/preview per scanner interaction; no repeated admission | Automated coverage; current integrated phone rerun pending |
| Cancel/reopen | Cancel scanner, open it again | Fresh usable scanner; no late callback | Automated coverage; current integrated phone rerun pending |
| Manual valid | Release guest's active seat, enter displayed code, preview, explicit Join | Same checked admission as QR; both clients show guest's seat | User-reported pass |
| Malformed input | Enter `https://example.com`, then `ABC`; try unsupported QR version | Validation error, no browser launch/admission; valid input can still be tried | Automated coverage; current hosted rerun pending |
| Membership consent | Nonmember previews valid invitation | Named community consent; checkbox alone does not enroll; explicit action and fresh lookup | Fixture coverage; hosted nonmember check pending |
| Full room | Preview/join a legitimately full room | Full guidance, no success callback or extra seat | Fixture coverage; hosted check pending |
| Final-seat race | Guest previews final free seat; other member claims it; guest joins | Admission fails safely; preview never represented a reservation | Fixture coverage; hosted check pending |
| Expired/revoked | Use owner-supplied expired/revoked test invitation | No admission; ask host for a new invitation | Fixture coverage; hosted case needs team-provided token, not manual production data edits |
| Network failure | Turn internet off before lookup/Join/history refresh; restore and retry | Error/recheck; no fake success or fixture fallback; prior valid rows retained for page error | Fixture coverage; hosted phone check pending |
| Normal history | Start a fresh non-demo session, participate, end/save; refresh | Normal record and eligible normal total; early-ended session not a completed count | Pending |
| Demo exclusion | Save demo and inspect both history modes | Demo row separate; normal totals/count unchanged | UI tests; reported demo saved, exact before/after normal totals not recorded |
| Restart | Save, fully close app, reopen same account | Same persisted record | User-reported pass |
| Same-device identity switch | In one app sign out A, sign in B, open history and same invitation token | No A history; lookup for B; no stale ready preview | New invitation regression tests; hosted rerun pending |
| Long text | Long goal/name, narrow screen, 200% text, keyboard shown | Wrapping/scrolling; reachable actions, no overflow | Widget coverage; current phone large-text check pending |

Capture fresh screenshots of: QR display, post-scan preview, shared occupied room,
saved participation, demo-history row and normal-history row. Existing screenshots
in conversation are evidence only for their shown states; no new screenshots were
captured by the coding agent in this pass.

## Cross-owner issue remaining from Step 5

Owner coordination: Shanuka (currently covering M3's connected repository).
`FirestoreStudyRepository.loadCurrentUserHistoryPage` requests 30 records ordered
by document ID, then the M4 controller sorts the loaded subset by `endedAt`.
The screen describes recent/newest-first history, but a newer completion can be
outside that first subset.

Reproduction in an approved test dataset: provide more than 30 completions whose
document IDs do not follow endedAt order. Open history. A newest-by-date record
with a later document ID may appear only after Load more. No extra live records
were created during this review.

Requested handoff: a bounded newest-first query with a stable tie-breaker and
matching opaque cursor/index handling, plus tests with more than 30 records and
equal timestamps. Preserve the separate complete summary, identity checks and
existing model/schema. The shared repository was not edited in this M4 pass.

## Short live explanation

“The scanner returns a validated opaque token. We show the room and communities
before explicit admission through the shared checked seat operation. Personal
history reads the current user's saved completions; demo records stay separate
and loading another page does not recalculate the all-history summary.”

## Automated verification

New regression tests were run against the unchanged provider first: both failed
for the account-switch/sign-out cases above. After the fix:

- Focused suite: **56 tests passed**, covering invitation account scope, capture,
  scanner UI, invitation flow, history controller/screen/status, progress dashboard
  and annual heatmap.
- `flutter analyze --no-pub`: passed, no issues.
- Changed Dart files formatted; `git diff --check`: passed.

Logs are local temporary artifacts: `%TEMP%/sandali-step6-account-before.log`,
`%TEMP%/sandali-step6-tests.log`, `%TEMP%/sandali-step6-analyze.log`.
No claim is made about the entire repository test suite or deployed Firebase rules.
No commit or push was performed during the initial review above.

## Follow-up verification and publication

The following user-reported checks supersede the corresponding pending entries
in the initial checklist. They are manual reports, not automated observations:

- Camera permission denied: manual code still reached preview.
- Permission restored: camera reopened; background/resume worked.
- Invalid URL and short manual code rejected; a valid code remained usable.
- Offline fresh lookup returned an error; reconnect/retry restored Join.
- Repeated recognition opened one preview; cancel/reopen allowed another scan.
- Non-demo participation/history/totals check completed after the supplied steps.
  Exact normal credit/count values were not supplied independently.
- Same-phone sign-out/sign-in: previous account history was not shown.
- Hosted full-room check used a two-desk room with Sandali and Sithmi occupying
  both seats. A third member had no available seat; user subsequently confirmed
  the invitation preview displayed the room-full message. This is not a
  final-seat-after-preview race test.

History pagination ordering was subsequently fixed separately in `3a7dda8` and
merged through PR #34 (`fb95b05`). Its 75-record regression fixture covers equal
timestamps across pages, cursor account scope and unchanged summary/demo behavior;
31 reader/progress tests and analysis passed for that change. This supersedes the
open pagination handoff above. Hosted testing with more than 30 records remains
separate from those in-memory query-double tests.

Remaining gates: physical two-phone rehearsal; hosted expired/revoked invitation
and final-seat race; fresh phone large-text review/screenshots. Shanuka is preparing
a Revoke action. Once merged, preview an invitation on the guest device, revoke
the same invitation on the issuer device, then Recheck on the guest: expect the
expired/revoked message and no Join. No code or database expiry was altered merely
to claim this check passed.

The user authorized publication of only the Step 6 account-scope provider fix,
its regression tests and this verification note. Private study guides and generated
Android build output are excluded from this commit.

Publication verification on merged baseline `fb95b05`: the combined invitation,
scanner, account-scope, pagination and progress suite passed **61 tests**;
`flutter analyze --no-pub` reported no issues. Logs:
`%TEMP%/sandali-step6-publication-tests.log` and
`%TEMP%/sandali-step6-publication-analyze.log`.
