# M2 — Poojani: accounts, profiles and communities

Read the [common plan](00-common-plan.md), then this guide. You own the identity
and membership foundations that Aradhana's admission logic and Sandali's history
need. You also implement your feature screens using Shanuka's shared controls.

## Your files and boundaries

Own `lib/features/auth`, `profile`, `communities`, Firebase generated config and a
dedicated bootstrap service. Coordinate `docs/contracts.md`, shared models,
Firestore rules/indexes and the shared development project. Existing community
screens, providers and fake repositories are useful working consumers: extend them.

Shanuka owns `main.dart`, routes, shared UI and central preview composition.
Aradhana owns room/session writes and supplies their rules. Sandali owns history
reads and scanning. Do not add a second RoomRepository, router or UserProfile.
Firebase/Android/dependency edits need a short shared-file reservation first.

## Step 1 — Align the baseline and agree identity/membership contracts

Pull the reviewed commit Shanuka publishes, run the preview and inspect the
existing `community_models.dart`, `CommunityRepository` and `CommunityController`.
Do not run `flutter create`. Meet Aradhana to settle profile/identity state,
community membership, subgroup ownership and parent-leave behavior.

```text
I am Poojani. Read docs/team/02-poojani-accounts-communities.md and the common
starter instructions. Inspect existing auth/profile/community code and shared
models. Draft only the missing identity/profile and membership contract changes
in docs/contracts.md for team review. Reuse existing IDs and models; clearly
separate proposed APIs from implemented ones. List effects on Aradhana's room
checks and Shanuka's route guards. Do not configure services or implement all
features in this task.
```

Done: everyone knows the identity states, profile shape, owner/membership rules,
and what happens to subgroup membership when leaving a SIG. Add only the agreed
model/interface changes in a follow-up small PR, with examples for consumers.

## Step 2 — Set up the shared development Firebase project

Confirm the application ID with Shanuka before registration (currently
`com.example.studymates`). One development project, individual collaborator access,
email/password Auth and Firestore; record client-config policy and setup commands.
Check service/billing requirements before enabling anything additional. No admin
key belongs in source, the app or a Codex prompt. Do not use allow-all shared rules.

Reserve dependency/config files with Shanuka, then make one bootstrap PR. Human
project selection and deployment are explicit actions; they are not silently
included in later feature prompts.

```text
Implement only the agreed Firebase client/bootstrap slice for Android after I
identify the shared project and authorize its setup actions. Inspect existing
package and Android versions first; add only required Firebase packages and
verify compatibility. Keep initialization in one service; Shanuka will wire
main.dart and route state in his integration PR. Preserve the offline preview.
Explain generated config versus secrets. Do not add room logic, deploy permissive
rules, change billing or alter Gradle/JDK versions without evidence of a need.
```

Done: provide Shanuka the bootstrap callable, success/failure contract, generated
config and setup instructions. Demonstrate initialization in a test harness or
coordinate the entry-point wiring immediately; do not mark the connected app ready
until that integration runs. Release the package/config slot for Sandali's scanner.

## Step 3 — Implement authentication, then basic profile

Split into small PRs: repository/state, sign-in/signup/reset/logout screens, then
profile setup/edit. Use shared AppButton/AppTextField/AvatarBadge; no theme copies.
Use neutral password-reset confirmation and recoverable error/loading states.

```text
Implement only [one agreed auth/profile slice] in my feature paths using the
merged identity contract and shared controls. Keep Firebase calls in repositories
and UI state in providers/controllers. Expose the agreed loading/signed-out/
incomplete/ready states for Shanuka; do not edit global routes or main.dart.
Include focused tests for success/error and state transitions, and list exact
route/provider integration requests. Keep tests independent of personal login.
```

Replace the bracketed task before use. Then verify two accounts, incorrect
credentials, reset flow, logout, profile persistence and app restart. Add/test rules
so users edit their own profile only. Hand off constructors/providers to Shanuka.

## Step 4 — Persist SIGs and subgroup memberships

Only after identity is stable, connect existing community consumers through the
agreed repository. Implement SIG create/discover/join/leave and owner-created
subgroups in separate slices. Implement the actual forms, not just their data.
Coordinate any need for streaming membership with Aradhana before changing the
current catalog API. Preserve its fixture implementation and preview tests.

```text
Implement only [SIG slice or subgroup slice] behind the existing agreed community
contract. Reuse the current discovery/detail screens and shared components;
add the necessary form/state instead of rebuilding them. Enforce owner and
membership permissions through rules as well as UI. Test joining a subgroup
without its parent, owner-only subgroup creation, and the agreed leave behavior.
Do not implement room admission, duplicate its data model or edit room widgets.
Give Aradhana the exact membership lookup/check and test account setup.
```

Done: two accounts can independently join IoT/ESP32, a non-owner cannot edit the
owner's data, and real memberships can be checked during room admission.
Leaving a SIG while seated/session-active needs an agreed rule with Aradhana before
integration: reject with a clear message or coordinate leaving; never orphan an
active seat by performing unrelated local deletes.

## Step 5 — Consolidate rules and seed the demonstration

Aradhana supplies room/session/invite rule requirements and emulator tests;
Sandali supplies history query requirements. You coordinate the single rules/index
change at a time, preserving unrelated protections. Review Aradhana's transactional
logic and have her review your access rules.

```text
Review the agreed rules/index changes for accounts, communities, room/session
operations, invitations and private history. Consolidate only the named scope;
do not replace existing rules wholesale. Verify own-profile edits, owner actions,
non-member admission rejection and cross-user history isolation using emulator
fixtures. Document indexes and repeatable demo data setup. Do not deploy until
I explicitly authorize deployment to the identified development project.
```

Done: a documented reset creates controlled users/SIGs/subgroups/rooms without
putting privileged setup credentials into the mobile client. Re-run permission
checks after the connected path is integrated. Provide the demo dataset to the team.

## Dependencies and conflict avoidance

| Dependency | Needed for | Independent work while waiting |
|---|---|---|
| Shanuka's published baseline | All branch work | Review current contracts and prepare scope |
| Shared dependency/config slot | Firebase setup PR | Auth/profile fixtures and screen tests |
| Shanuka's route integration | Normal app flow | Repository tests and your feature screens |
| Aradhana's admission/session policy | Active-room leave and room/session rules | Community CRUD, error states and demo seeding |
| Sandali's history query | Required indexes/read access | Existing ownership/isolation regressions |

Before each PR: format, analyze, relevant tests, and actual Android checks. Use
separate auth/community/rules test files rather than editing everyone's tests.
Report what is live versus fixture-backed. Your first task is Step 1; Firebase
setup and authentication follow immediately after the small contract handoff.
