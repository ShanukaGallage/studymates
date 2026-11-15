# Sandali — Step 3 history handoff

Inspected 15 November 2026 on `feat/sandali-progress-history`, baseline
`0c79356` (latest pulled main). This is the first small planning slice, not a
working history screen. No new completion schema or speculative model is defined.

## Initial dependency (historical; resolved below)

`docs/contracts.md` still lists CompletionRecord and participation/finalization
as future work. No CompletionRecord, history repository or progress fixtures
exist in lib/test; progress folders contain placeholders. Step 3 requires a
merged completion model/contract and read boundary, not a live Firebase service.

## Original requested handoff (historical draft, not sent)

Aradhana: please provide the merged commit, exact CompletionRecord import/type,
stable record identity, user/session identity, creditedSeconds, endedAt UTC,
timer completion status, independent goal outcome and isDemo representation.
Please define count/credit behavior for completed, cancelled and early-left
participation, and how consumers resolve conflicting versions of one record.

Provide agreed empty, single/multiple, duplicate, long-goal, unfinished-goal,
early-left/cancelled and demo fixtures with expected counts and credited totals.
Specify the exact read-only repository method, return type and retry/error
behavior; this note does not assign speculative Dart method names.

Aradhana and Poojani: agree current-user scoping and the complete-total source
versus bounded recent-history pages. If only recent data is available, its sum
must be labelled as recent recorded time, not an all-time total. Remote reads,
rules/indexes and account integration are Step 5 work, not part of this slice.

Shanuka: once the model is merged, Sandali will provide a screen constructor and
provider handoff; global routes and central preview bindings remain your scope.
No route name or shared provider API is introduced here.

## Small implementation slices after handoff

1. Consume the agreed model and read boundary; add separate `progress_*`
   fixtures/tests proving unique-record credit, session count and demo separation.
2. Build the read-only history screen with existing shared controls: recorded-time
   total, completed-session count, history, and loading/empty/error/retry states.
3. Add clearly labelled demo history, long-text/accessibility checks and provide
   constructor/provider wiring instructions to Shanuka. Run formatting, analysis
   and relevant independent tests before reviewing each slice.

## Acceptance checklist

- Unique agreed record identities contribute once according to the credit policy.
- Unfinished goals do not erase eligible recorded time or imply timer failure.
- Early-left/cancelled credit and counts match the producer's agreed policy.
- Demo records appear separately and never inflate normal totals.
- Loading, empty and failure are distinct; retry uses the same read boundary.
- Totals accurately describe the scope of available data.
- No completion writes, auth/schema changes, shared routing, charts or rewards.

Next dependency: the agreed completion contract/fixtures from Aradhana, coordinated
with Poojani. The initial handoff slice changed no Dart code or shared files.

## Independent presentation slice — 15 November 2026

While the completion contract is pending, added presentation-only loading, empty
and error/retry content in
`lib/features/progress/presentation/widgets/progress_status_view.dart`.
It reuses shared LoadingView, EmptyView and ErrorView. It neither defines a
CompletionRecord nor reads history, computes totals or changes global routing.

Constructor handoff for Shanuka (or the eventual progress screen):

- `ProgressStatusView.loading()` while awaiting a read.
- `ProgressStatusView.empty()` only after a successful read with no records.
- `ProgressStatusView.error(onRetry: callback)` after a failed read.

Embed the content in a scrollable parent. Loading/error do not show zero totals
or claim an empty history. Retry delegates to the owner; it does not fabricate
records or successful recovery.

Standalone development preview:

```powershell
flutter run -d <device-id> -t lib/preview/progress_states_preview.dart
```

Choose Show loading, Show empty and Show error. In error, Retry shows loading and
explicitly reports that the preview callback made no network request. Select
Show empty manually to inspect recovery. The preview is separate from normal
app entry points and central preview bindings.

Independent tests in `test/progress_status_view_test.dart` check state separation,
retry delegation, preview transitions and 320px/2x text with keyboard insets.
Checks performed: changed Dart files formatted; `flutter analyze --no-pub` passed
with no issues; `flutter test --no-pub test/progress_status_view_test.dart` passed
all four tests. The user subsequently supplied an Android emulator screenshot
showing the loading preview and confirmed Show empty and Show error > Retry
behaviors in chat. These are user-verified runtime results; the coding agent did
not independently perform an Android build/run for this presentation slice.

After preview verification, the user authorized a meaningful commit and push of
this independent UI slice. Real history, totals, demo separation and repository
wiring still await the agreed contract and fixtures; this is not full Step 3.

## Agreed-contract controller slice

The dependency above was resolved by merged baseline `e1deaca` (M3 completion
contract PR #11). This slice consumes the actual `CompletionRecord` and
`CompletionHistoryRepository` without changing them. The agreed goal outcomes
are `completed` and `unfinished`, not the earlier proposed names in chat.

Added `progress_history_controller.dart` in progress presentation/controllers.
`progressHistoryRepositoryProvider` requires an explicitly supplied current-user
repository; it throws when unconfigured and never silently substitutes fixtures.
`progressHistoryProvider` loads the first history page and separate complete
summary. Use `ref.invalidate(progressHistoryProvider)` for an explicit full retry
or refresh, and `loadNextPage()` for pagination/page-error retry.

`ProgressHistoryData` keeps the summary, unique loaded records, separate normal
and demo record views, next-page token, loading-more flag and page error. Duplicate
`recordId` entries retain their first occurrence; records are sorted newest first.
Conflicting versions require a producer contract, not invented credit adjustment.
Paging never derives or mutates the complete summary. Page failures preserve
already loaded data/summary and allow retry with the same token. Concurrent taps
issue one request, and stale page responses after refresh/disposal are ignored.

`lib/preview/progress_history_fixtures.dart` implements the agreed read interface
with two explicit local pages, duplicates and M3's existing normal/early-left/demo
records. Its complete normal summary is 3900 seconds and two completed sessions,
even when only the 1200-second unfinished-goal record is initially loaded. The
75-second demo record appears separately; no live backend or credit policy is
implemented. The provisional cancellation fixture is not used to set policy.

This is the controller/fixture slice only. It is not yet wired to a history
screen, global router, Firebase or auth. Goal text/long-goal fixture support remains
an M3 handoff because the merged model does not contain goal text. The next slice
will connect the existing UI states and add the history/summary presentation.

Validation for this slice: `flutter pub get` resolved the pulled Firebase packages
without tracked dependency/lockfile changes; `flutter analyze --no-pub` passed
with no issues; the controller and existing status-view suites passed all nine
tests. Changed Dart files were formatted and `git diff --check` passed. No Android
runtime check, commit or push was performed for this controller-only slice.

## Fixture-backed history screen slice

Added `ProgressHistoryScreen` as a scrollable route body using the agreed
controller and shared controls. It displays the complete normal summary, normal
and demo history, local end times, credited duration, separate timer/goal status,
refresh, load-more and page retry. A failed page retains the summary and already
loaded records; an incomplete page never claims the entire selected history is
empty. Demo history is explicitly labelled and never changes the normal summary.

`ProgressHistoryFixtureRepository` now supports sample, empty, held loading,
initial-error-once and next-page-error-once scenarios. It remains a local fixture
implementation; no Firebase reads, completion writes or production fallback.

Run the new independent preview (the earlier state-only preview still exists):

```powershell
flutter run -d <device-id> -t lib/preview/progress_history_preview.dart
```

Use the sliders icon to select scenarios. For Sample history:

1. Confirm Normal progress reports 1h 5m and two completed sessions, even though
   only the 20m unfinished-goal record is initially shown.
2. Load more: normal history shows 20m, 30m and 15m records once each; the last
   record's timer ended early. Summary remains 1h 5m / two completed sessions.
3. Select Demo history: its record is 1m 15s, excluded from normal totals/counts.
4. Test Empty history, Initial error once > Retry, Next-page error once > Retry
   loading more, and held Loading history (select another scenario to exit).
5. Check large text/narrow layouts and refresh. These fixtures are not persistent.

Shanuka handoff: use `const ProgressHistoryScreen()` as the route body within a
ProviderScope supplying `progressHistoryRepositoryProvider` with the agreed
current-user read repository. Production routing/central bindings are unchanged.
The fixture preview demonstrates explicit repository injection. Live adapter,
identity changes, private Firestore reads and restart persistence remain Step 5.

The merged record has no goal text or room title; this screen does not invent
those fields. It displays the session identifier and agreed goal outcome. A true
long-goal fixture still requires the producer's agreed field/contract extension.

Validation: analysis passed with no issues; final full `flutter test --no-pub`
passed all 83 tests, including seven history screen/preview tests and five
controller tests. The debug APK was produced for the new preview target and
installed/run on Android 17 emulator `emulator-5554`. Used the temporary
`--no-enable-impeller` diagnostic flag because of the previously observed emulator
rendering issue; no manifest/renderer configuration was changed. Inspected the
normal summary/first record screenshot, loaded the next page, switched to Demo
history and inspected its 1m 15s record with the normal 1h 5m / two-session summary
unchanged. Session end times displayed in local time. Screenshots for this run:
`%TEMP%/progress-history.png` and `%TEMP%/progress-demo.png`.

Build logs emitted existing Firebase KGP migration/deprecation warnings; these
shared dependencies were not changed. Physical-phone checks of this new screen
remain pending. No commits or pushes were made for the controller/screen slices.

After verification, the user authorized publication in separate meaningful
commits for the controller/fixtures and the history screen/preview. The notes
above describe checks performed before publication. PR review should cover the
fixture-backed behavior and Shanuka's route/provider handoff; production history
integration and long-goal support remain outside this change.
