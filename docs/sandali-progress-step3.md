# Sandali — Step 3 history handoff

Inspected 15 November 2026 on `feat/sandali-progress-history`, baseline
`0c79356` (latest pulled main). This is the first small planning slice, not a
working history screen. No new completion schema or speculative model is defined.

## Current dependency

`docs/contracts.md` still lists CompletionRecord and participation/finalization
as future work. No CompletionRecord, history repository or progress fixtures
exist in lib/test; progress folders contain placeholders. Step 3 requires a
merged completion model/contract and read boundary, not a live Firebase service.

## Requested handoff (draft for teammates, not sent)

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
