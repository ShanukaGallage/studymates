# StudyMates — common four-member plan

This is the current team working plan. It supersedes the five-member assignments
and startup assumptions in the two original StudyMates guides. It is not an
assignment report. Deliverable: **five-minute live Android demonstration**, with
no slides, report or formal rubric. All four members use VS Code with Codex.

Read this first, then your individual guide:

| Member | Main responsibility | Individual guide |
|---|---|---|
| M1 — Shanuka | Shared UI, room/session presentation, navigation and difficult integration work | [Shanuka](01-shanuka-ui-integration.md) |
| M2 — Poojani | Firebase setup, authentication, profiles and communities | [Poojani](02-poojani-accounts-communities.md) |
| M3 — Aradhana | Live rooms, seat correctness, session timing and completion writes | [Aradhana](03-aradhana-rooms-sessions.md) |
| M4 — Sandali | QR/manual invitations and read-only progress/history | [Sandali](04-sandali-invites-progress.md) |

These assignments follow the supplied name order and can be exchanged before work
starts. Availability and deadline have not been supplied; use the gates below,
not the original guide's four-week estimate or former part-time assumptions.
Reserve roughly one quarter of available effort for integration, testing and fixes.

## 1. What we are building

StudyMates helps people find study partners through **SIG → subgroup → room →
focus session → personal history**. Example: IoT → ESP32 → First Sensor Project.
The timer records eligible participation, not verified attention or learning.

Core target: email/password accounts and reset, preset profiles, create/discover/
join/leave SIGs, owner-created subgroups, six-seat rooms, personal goals, a shared
focus/break schedule, one completion per user/session, camera invitations with
manual fallback, and private personal history. Retain camera scanning as a product
choice; do not describe it as a formal marking criterion now that no rubric exists.

Normal schedule: 25-minute focus + 5-minute break. Provide a visibly labelled
60-second demo cycle, kept separate from ordinary progress. Proposed demo split:
45-second focus + 15-second break; agree and record the exact split at Gate 1.
Goal outcome (completed/unfinished) is independent of timer completion.

Defer charts, decorations and resource links until the connected path is reliable.
No full chat, voice/video, AI, 3D world, uploads, public rankings or public launch.

## 2. Existing work — extend it

All four members have reported running the app on their devices. This confirms
onboarding; it does not yet prove everybody has the latest room-preview code.
Shanuka's recorded device is 23129RAA4G, Android 15, build AQ3A.240829.003.

Present locally: Flutter 3.50.0 / Dart 3.14.0; Material UI, Riverpod and go_router;
shared theme/components; four-tab shell; preview gallery and scenario controls;
community search/details with in-memory membership; six-seat presentation, local
seat selection/conflict simulation and goal entry. The normal entry point remains
a disconnected shell. The latest recorded full suite passed 21 tests; an ARM64
preview APK built. Room phone/TalkBack review remains pending.

Not present: Firebase integration, real identity, persistent memberships, live
seating, real sessions, invitation services/scanning, persisted completions/history.
The existing `RoomLobbyPreview` is a local interaction harness, not a live-room
controller. Never convert its simulated success into a claimed server admission.

**First dependency:** the latest community/room changes are still uncommitted on
`feat/community-preview` in this checkout. Shanuka reviews and publishes a tested
baseline through the team's normal PR/merge workflow; everyone starts from that
same commit. Do not regenerate the app, directories, theme, router or dependencies.

## 3. Ownership and conflict boundaries

Each feature owner implements their own screens with Shanuka's components.
Shanuka designs/reviews shared UI, builds room/session presentation and handles
integration; he does not rewrite all three teammates' screens.

| Area / paths | Single coordinating owner | Cooperation rule |
|---|---|---|
| `lib/core/theme`, `lib/core/widgets`, assets/design references | Shanuka | Request missing components; reuse existing ones meanwhile |
| `lib/app`, `main.dart`, `main_preview.dart`, central preview bindings | Shanuka | Feature owners provide constructors, providers and route requests; Shanuka wires them |
| `lib/features/auth`, `profile`, `communities` | Poojani | Preserve existing community consumers; publish interface changes first |
| `lib/features/home` | Shanuka | Consume Poojani's agreed community/profile services when available |
| `lib/features/rooms/data`, new live-room controllers | Aradhana | Adapt live state to the existing scene; no second scene or seat service |
| Existing room scene/lobby/goal widgets and `room_scene_provider.dart` | Shanuka | Aradhana supplies state/callbacks; agree before editing these files |
| `lib/features/sessions/data` and `presentation/controllers` | Aradhana | Own timing, participation and finalization logic |
| `lib/features/sessions/presentation/screens` and `widgets` | Shanuka | Consume Aradhana's contracts; no duplicate timer/completion engine |
| `lib/features/invites/presentation`; scanner/token parser | Sandali | UI consumes Aradhana's shared invite/admission operations |
| `lib/features/invites/data` invitation contract + remote implementation | Aradhana | Sandali contributes parser-specific files only; agree filenames first |
| `lib/features/progress` including read-only history adapter | Sandali | Read the agreed completion schema; never award or rewrite completions |
| Shared domain models and `docs/contracts.md` | Poojani coordinates | Aradhana authors room/session fields; Sandali reviews consumers; Shanuka reviews UI needs |
| Firebase project/config/bootstrap, `firestore.rules`, indexes | Poojani | Aradhana supplies room/session/invite rule changes and tests in a reserved small PR |
| `pubspec.yaml`, lockfile and `android/` shared config | Shanuka coordinates | One dependency/config PR at a time; Poojani and Sandali request a short edit slot |
| Shared tests (`widget_test.dart`, existing preview suites) | Shanuka | Each member adds separate feature test files in owned scope |
| New feature fixtures under `lib/preview/` | Relevant feature owner | Separate named files; only Shanuka changes central `preview_scope.dart` |

Firebase bootstrap code should live in a dedicated new service file owned by
Poojani; Shanuka calls it from the normal entry point. Generated Firebase client
config belongs to Poojani. Do not give two agents concurrent ownership of `main.dart`.

A coordinating owner is not a permanent gatekeeper for every edit. Reserve the
shared file in the task/PR, make one small change, merge it, then release the slot.
If a task is blocked by another owner, continue its fixture-based screen/tests.
Do not silently edit the other owner's files just to make your branch compile.

## 4. Contract handoffs before dependent implementation

Current implementations and drafts are distinguished in [contracts](../contracts.md).
The following future interfaces must be agreed; the table is not a claim that
these APIs already exist. Choose exact names/types in one small contract PR.

| Handoff | Producer → consumer | Agree and provide before integration |
|---|---|---|
| Identity/profile state | Poojani → everyone | loading / signed-out / incomplete-profile / ready; stable user ID, name, avatar; error behavior |
| Community membership | Poojani → Aradhana/Shanuka | SIG/subgroup IDs, owner permissions, membership checks; leave-parent behavior |
| Room state/admission | Aradhana → Shanuka/Sandali | room ID, six seat states, host, current user's seat, connection status; admitted/full/seatTaken/membershipRequired/unavailable |
| Session state | Aradhana → Shanuka | stable session ID, UTC start/focus-end/break-end, phase, goal, participation, save state; host and member actions |
| Completion/history | Aradhana → Sandali | stable user/session record ID, creditedSeconds, endedAt UTC, timer completion status, goal outcome, isDemo; private read/query boundary and complete-total source versus bounded history pages |
| Invitation | Aradhana → Sandali/Shanuka | exact versioned QR/manual-token format, preview fields, expiry/revocation and errors; explicit membership consent; one admission operation |
| Route intent | Each owner → Shanuka | destination, parameter IDs, auth requirement, back behavior, pending invitation across login |

Poojani and Aradhana must resolve how shared models evolve without duplicating
`UserProfile`, `RoomSummary` or the existing membership types. Presentation-only
`RoomSeat` is not automatically the Firestore seat schema. Add fixtures and
meaningful contract tests alongside each change. Freeze a small version of these
interfaces while Sandali builds its consumers; provide migrations when changing them.

## 5. Parallel work and merge order

| Gate | Shanuka | Poojani | Aradhana | Sandali | Exit proof |
|---|---|---|---|---|---|
| 0: Shared baseline | Review/publish current preview; record commit | Pull/run same commit | Pull/run same commit | Pull/run same commit | All four confirm identical commit and preview route |
| 1: Contracts + first independent tasks | Session UI states/design; route-request list | Auth/profile contract; Firebase setup PR | Room/session/invite/completion drafts and fixtures | Camera spike with test token; history from fixture contract once merged | Contracts merged; scanner reads known QR once on a phone |
| 2: Identity + real occupancy | Connect auth gate; live room adapter | Auth/profile first, then SIG/subgroup persistence/rules | First room stream and checked atomic seats | Scanner errors/manual input; history UI | Two authenticated accounts join one subgroup and occupy distinct seats |
| 3: Complete path | Focus/break/summary UI; navigation/invite integration | Ownership/membership regressions; seed demo data | Shared schedule, unique completion, invitation lookup/admission | Real invite preview/join and real history reader | QR → room → demo cycle → saved history across two devices |
| 4: Reliability/freeze | Responsive/accessibility fixes, candidate APK, rehearsal | Access/isolation checks | Conflicts/reconnect/host departure/duplicate completion | Camera denial/retry, history totals and demo separation | Exact candidate APK completes repeatable five-minute demo |

Dependencies: Aradhana can write fixture/emulator tests before Firebase UI is
ready, but real admission needs Poojani's identity/membership/rules. Shanuka can
build timer screens from timestamps before the real session engine exists.
Sandali can prove camera hardware immediately and history UI from fixtures;
actual QR admission waits for Aradhana, and real totals wait for completion writes.
Nobody needs final artwork to start. Merge small slices at each gate; do not wait
for an entire member's module to be finished before integrating it.

## 6. Working together in Git and Codex

Use one repository, one clone per person, and short task branches. Before a task,
check `git status`; preserve unfinished changes. With a clean tree and the shared
baseline merged, use `git switch main`, `git pull --ff-only`, then
`git switch -c feat/<one-small-task>`. No force-pushes over shared work, duplicated
apps, bulk replacement of folders, or automatic resolution of others' conflicts.

One small issue should name the owner, allowed files, input contract/commit,
observable success/error cases, reviewer and any shared-file reservation.
Every day (or after each work block), post: branch, completed, next, blocker,
and requested handoff. This is team coordination, not a report deliverable.

Review assignments: Poojani and Aradhana review each other's backend/rules work;
Shanuka reviews UI/integration; Sandali reviews QR/history consumers; Poojani reviews
Shanuka's app wiring/release. Each PR needs one appropriate human reviewer and
matching checks. Feature owners must explain the behavior their AI helped produce.

Paste this starter into a fresh Codex task, then append ONE step prompt from your
individual guide. Replace all bracketed fields before running it.

```text
We are building the existing StudyMates Android Flutter app.
Read AGENTS.md, README.md, docs/team/00-common-plan.md, my individual plan
[exact file], and docs/contracts.md. Inspect git status and relevant existing
code before changing anything. Preserve unrelated and uncommitted work.
I am [member/name]. Implement only [one task] in [owned paths].
The agreed input contract/commit is [reference]. Acceptance cases: [list].
Reuse Material UI, Riverpod, go_router and existing shared components.
Do not recreate the project, guess a missing backend contract, add a second
state solution or change another owner's shared files silently.
If a dependency is missing, keep the task fixture-backed and report the exact
handoff needed. Ask only about decisions that block this task; continue safe,
independent work. Never treat mock data as real synchronization.
No backend deployment, billing change or external messages are part of this task.
Format changed Dart files, run analysis and relevant independent tests, and
report Android checks actually performed. Summarize changed files, behavior,
remaining placeholders, integration requests and a phone verification sequence.
Do not commit or push unless I explicitly ask within this task.
```

Common checks: `dart format lib test`, `flutter analyze`, `flutter test`, then
`flutter run -t lib/main_preview.dart` for previews. Once backend wiring exists,
test `flutter run -t lib/main.dart` separately: a working preview does not validate
Firebase. Use emulator-backed rules/transaction tests when available and record
commands in README. Do not make routine tests require a personal Firebase login.
Pin the agreed SDK/lockfile and verify package compatibility when adding a package.

## 7. Reliability and scope decisions

Use atomic admission for six seats and one active seat per user; enforce permissions
in backend rules, not just button visibility. Use shared timestamps rather than
per-second timer writes. Document late-join/early-leave credit, lease/grace periods,
uncertain connectivity, background/resume and host departure. Finalizing the same
user/session twice must not produce a second completion. History is private.

Poojani owns the shared development Firebase project; collaborators use their own
accounts. Never put admin credentials, release signing secrets or passwords in
source or AI prompts. Client config is distinct from admin secrets; decide its
tracking policy explicitly. Do not use allow-all shared database rules. Human
project setup/rule deployment is a named step, not an implicit action in every prompt.

If a gate slips, stop charts/decorations/resources and final art polish. Shanuka
helps with a bounded integration task; he does not absorb all unfinished features.
If Sandali is overloaded, finish the camera spike first, then the minimal history
list/total; Shanuka can take history presentation after an explicit ownership
transfer. If Aradhana is overloaded, Poojani pairs on transactions after accounts
are stable and Shanuka retains all session UI. Transfer a named file/task before
another person or Codex agent edits it.

## 8. Five-minute demo and final handoff

Prepare the exact candidate APK on two phones, two controlled accounts, seeded
IoT/ESP32 data, working connectivity and a repeatable reset. No Play Store release
is needed. Use a visible demo flag and a separate demo-history view/dataset; normal
totals must exclude demo time. A backup recording may explain an outage but must
not be represented as live behavior.

| Time | Demonstration |
|---|---|
| 0:00–0:30 | Introduce StudyMates and show the two prepared accounts |
| 0:30–1:15 | Discover/join IoT → ESP32 and open the room |
| 1:15–2:00 | Display/scan invitation; show both participants in different seats |
| 2:00–2:20 | Enter separate personal goals and start labelled demo mode |
| 2:20–3:20 | Run the agreed 60-second focus/break demo cycle |
| 3:20–4:10 | Show summary and saved demo history; reopen to show persistence |
| 4:10–4:40 | Show demo separation from normal progress; explain one reliability behavior |
| 4:40–5:00 | Buffer and finish |

Do not force every error case into the live five minutes. Verify them beforehand:
seat race, multiple-seat prevention, invalid/full invite, camera denial/retry,
private history isolation, reconnect, host departure and duplicate finalization.
A final handoff names the tested commit/APK, device versions, known limitations,
setup/reset steps and who can explain each feature. No slides or report are added.
