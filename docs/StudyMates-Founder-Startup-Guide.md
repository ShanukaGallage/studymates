# StudyMates — Shanuka's startup and handoff guide

Prepared 14 November 2026. This guide supplements StudyMates-Team-Playbook.md. It specifies what the team lead should prepare before feature implementation is handed over. It does not claim a repository, Firebase project or application has been created. Commands are instructions to run in your chosen development folder; replace placeholders explicitly.

## 1. Your startup goal

Produce one shared Android Flutter project with a consistent visual system, navigable screen shells, stable sample data and clear responsibilities. You own UI design, shared components and integration. Members implement their screens from your specifications. Member 2 owns backend/account/community work; Member 3 owns rooms/sessions; the limited-availability Members 4 and 5 own progress and QR respectively.

Aim for an initial foundation in two to three focused days, with additional visual polish continuing afterward. This is an estimate, not a deadline promise. Do not hold the team idle until every illustration is final. Invite them at repository creation; release work as soon as the corresponding design and contract are ready.

### What must exist before broad handoff

- One GitHub repository and one runnable Flutter project.
- A recorded Flutter/Dart version and committed dependency lockfile.
- Shared theme, reusable controls and a component preview screen.
- The complete screen inventory with rough layouts and behaviour notes.
- Detailed references for Discover, SIG/subgroup details, room and timer.
- Working navigation through sample content, clearly identified as a UI preview.
- A first version of shared models and repository interfaces, reviewed by M2/M3.
- Small issues for each member with an owner and acceptance criteria.
- One successful clone-and-run check on another member's machine.

Not required before delegation: finished authentication, Firebase integration, functioning synchronization, complete statistics, QR implementation, every final illustration, or a public deployment.

## 2. Freeze the decisions that affect everyone

Record these in docs/project-plan.md before creating screens:

| Decision | Initial choice |
|---|---|
| Product | StudyMates; anyone may sign up |
| Tagline | Find your people. Learn together. |
| Platform | Android only, Flutter/Dart |
| Hierarchy | SIG → subgroup → persistent room → timed sessions |
| Main navigation | Home, Discover, Progress, Profile |
| Group permissions | Anyone creates a SIG; owner creates its subgroups; subgroup members create rooms |
| Room | Six seats; preset avatars; one illustrated scene |
| Study cycle | 25-minute focus plus 5-minute break; no global pause |
| Phone hardware | Camera QR room invitation scanning |
| Theme | Light theme first; warm cream, forest green, mint and amber |
| Backend | Firebase Authentication and Cloud Firestore |
| State and navigation | Riverpod and go_router |
| Preview mode | Separate preview entry point with fake repositories |
| Scope | No full chat, voice/video, AI, 3D world, file uploads or public rankings |

Keep the previously agreed session rules in the team playbook: atomic seats, unique participation records, late-join credit, explicit connection uncertainty and a separate demo dataset. Exact lease/participation implementation is M3's early spike with M2, not a UI-only decision.

## 3. Set up your workstation and confirm the Android toolchain

Install Git, VS Code, a stable Flutter SDK, Android Studio for SDK/emulator management, the Flutter extension (which installs Dart) and the official OpenAI Codex extension. Coding stays in VS Code. You do not need iOS tooling for this assignment.

In a terminal:

```bash
git --version
flutter --version
dart --version
flutter doctor -v
flutter doctor --android-licenses
flutter devices
```

Review and accept Android licenses interactively. Resolve the Android toolchain/device findings. On Ubuntu, use the Linux sections of the official Flutter/Android setup pages; do not copy Windows SDK paths. Use Android Studio's compatible bundled JDK unless the selected Flutter/Gradle setup requires another configuration.

For a physical phone: enable Developer options and USB debugging, connect a data-capable USB cable, approve the computer on the phone, and verify it appears under flutter devices. If Linux permissions or device authorization fails, resolve that before app development. Have M5 check their own physical phone early.

Record the actual Flutter/Dart versions and demo phone Android versions in README.md. Have everyone use that Flutter version; commit pubspec.lock. Do not independently upgrade SDK/packages during the project.

Codex: sign in to the VS Code extension using your own ChatGPT account. Each teammate checks their own access. Current official guidance includes Go in Codex access, with plan-dependent limits; Go does not include Codex Cloud. Do not design the workflow around unlimited AI calls or a cloud agent.

## 4. Create the GitHub repository and app

### A. Create an empty remote repository

In GitHub, choose New repository:

- Owner: your account or an existing team organization.
- Repository name: studymates.
- Description: Android study-community app built with Flutter.
- Visibility: private initially, unless the module requires public access.
- Leave initialization options unchecked: no remote README, .gitignore or license yet, because Flutter will create local files.

Invite the four teammates as collaborators. Confirm invitations are accepted. Use each person's own GitHub account. Do not make everyone an administrator. A new organization is optional, not a prerequisite.

### B. Create one local Android app

From the parent development folder where you want the project:

```bash
flutter create --platforms=android --org com.example studymates
cd studymates
code .
flutter run
```

The example application ID is com.example.studymates. It is acceptable as a classroom prototype identifier; if you choose another unique identifier, decide it before registering the app with Firebase. Do not use a university or company namespace you do not control. The Dart package name stays studymates. Set the Android display label to StudyMates in the main Android manifest or the referenced string resource. The display label and application ID are different.

First confirm the generated starter runs. Then replace the counter screen as part of the foundation work. Stop the running app with q before entering further shell commands in the same terminal.

### C. Make the initial commit and push

Review Flutter's generated .gitignore. It should omit build output and machine-specific Android paths. Add any project-specific exclusions before staging. Keep pubspec.lock because this is an application.

Additional examples, if not already covered:

```gitignore
.env
.env.*
!.env.example
android/key.properties
*.jks
*.keystore
```

Do not exclude every JSON file: configuration and assets can be legitimate source files. Never commit service-account private keys, account tokens or release signing secrets.

```bash
git init
git branch -M main
git add .
git diff --cached --stat
git diff --cached
git commit -m "chore: initialize Android Flutter app"
```

After inspecting the staged files, add the remote. Replace YOUR_GITHUB_USERNAME in the URL below before running it:

```bash
git remote add origin https://github.com/YOUR_GITHUB_USERNAME/studymates.git
git push -u origin main
```

Use GitHub's supported sign-in/credential flow, not an account password embedded in the URL. If origin already exists, inspect git remote -v instead of adding a duplicate. If you already initialized the remote with files, reconcile histories normally; do not force-push over work.

### D. Team workflow

Use main plus short task branches. Do not add a permanent branch for each member. Example: chore/app-foundation, feat/sig-membership, feat/seat-claims, feat/progress-history, feat/qr-scanner. Require a teammate review for merges. If branch-protection/ruleset controls are available on your repository plan, enforce reviews and checks; otherwise follow the same convention manually.

No direct pushes to main after the initial skeleton. Keep branches short and merge working slices. M2/M3 review each other's behaviour; you review shared UI and integration. Create a board with Backlog, Ready, In Progress, Review and Done if useful; ordinary GitHub Issues are sufficient.

## 5. Keep the architecture small and explicit

Use feature folders, separating visual widgets from state and data access. A repository is the interface a feature uses to obtain/change data. A fake repository implements that same interface using memory; later, Firebase replaces the data implementation without redesigning the screen.

| Path | Responsibility |
|---|---|
| lib/main.dart | Normal app entry point; M2 wires backend initialization later |
| lib/main_preview.dart | Explicit UI-preview entry point with fake repositories |
| lib/app/app.dart | Root app configuration |
| lib/app/router.dart | Route definitions and auth/onboarding redirect coordination |
| lib/app/app_shell.dart | Four main navigation destinations |
| lib/core/theme/ | ThemeData, colors, spacing and typography |
| lib/core/widgets/ | Truly reusable buttons, fields, cards and state views |
| lib/core/models/ | Small set of agreed shared domain models |
| lib/features/auth/ | Authentication screens, controllers and repository |
| lib/features/profile/ | Profile setup/editing and preset avatar selection |
| lib/features/home/ | Composed home view using existing repositories |
| lib/features/communities/ | SIG/subgroup screens and memberships |
| lib/features/rooms/ | Room list/create/lobby, scene widgets and room repository |
| lib/features/sessions/ | Goals, phase state, timer and completion |
| lib/features/progress/ | History, totals and optional milestone rewards |
| lib/features/invites/ | Invitation display, scanner and preview |
| lib/preview/ | Fixtures, fake implementations and development state controls |
| assets/rooms/ | Empty room scene and optional foreground layer |
| assets/avatars/ | Preset avatar assets |
| assets/decorations/ | Optional transparent decoration assets |
| test/ | Meaningful widget and logic tests |
| docs/ | Plan, contracts, designs, setup and handoff |

Inside a feature, start with presentation/screens, presentation/widgets, presentation/controllers and data. Keep public repository contracts beside their implementations in data initially. Do not create hundreds of empty files or separate use-case classes for every button. Only share models that multiple features actually use. No second copy of UserProfile, Room or StudySession in another folder.

Initial packages:

```bash
flutter pub add flutter_riverpod go_router
```

These are the agreed recommendations; the publisher documentation describes their state/data-binding and routing capabilities. Use APIs compatible with the versions resolved in your lockfile. Avoid adding code generation, several state libraries or a game engine at kickoff.

M2 adds firebase_core, firebase_auth and cloud_firestore when wiring Firebase. M5 evaluates mobile_scanner and a QR rendering package such as qr_flutter in their early hardware spike. You do not need to install every future package on Day 1. Record dependency changes in the PR; verify Android compatibility before merging.

## 6. Prepare the minimum project documents

These are working agreements, not an assignment report. Keep them brief and in the repository.

| File | Contents |
|---|---|
| README.md | Product, platform, SDK version, setup/run/check commands, team ownership, preview vs connected mode |
| AGENTS.md | Instructions Codex follows across features |
| docs/project-plan.md | Scope, role table, milestones and behavioural rules |
| docs/contracts.md | Shared models, service operations, IDs, errors and dates |
| docs/design/screens.md | Screen inventory, route, state, behaviour and owner |
| docs/design/design-system.md | Tokens, components, asset rules and responsive behaviour |
| docs/design/references/ | Numbered reference images and wireframes |
| docs/handoff.md | Foundation commit, current status, first task per member, known gaps |
| assets/ATTRIBUTION.md | Sources/licenses or generation provenance for artwork/fonts |
| .github/pull_request_template.md | Problem, change, checks, screenshot and limitations |

An AGENTS.md starter:

```markdown
# StudyMates

- Read README.md, docs/project-plan.md and docs/contracts.md first.
- Android Flutter app using Riverpod, go_router and the agreed Firebase services.
- Reuse Shanuka's theme and shared controls; implement assigned screens from docs/design.
- Keep database and session logic out of presentation widgets.
- Reuse shared models; coordinate changes to contracts, dependencies and routing.
- Use preview repositories for unfinished services; label preview/demo states.
- Seat admission and membership checks belong in shared logic, not only UI controls.
- Session timing uses shared timestamps; completions must not be duplicated.
- Do not add unplanned features or weaken access rules.
- Do not commit secrets, deploy services or change billing during feature work.
- Run formatting, flutter analyze and relevant tests; report checks not run.
- Summarize changes, important logic and manual Android verification steps.
```

This guide supplies a template; create that actual file in your application repository. Codex should inspect existing files rather than repeatedly regenerate the project.

## 7. Agree on data contracts before detailed screens diverge

Draft these with M2/M3. You define what the UI needs; they own final storage layout and enforcement. A UI contract is not automatically a Firestore schema.

| Model | Minimum UI fields |
|---|---|
| UserProfile | id, displayName, avatarId, bio, interestIds, equippedDecorationId |
| SigSummary | id, name, category, description, ownerId, membershipState |
| SubgroupSummary | id, sigId, name, description, membershipState |
| RoomSnapshot | id, subgroupId, title, hostId, capacity, seats, activeSessionId |
| SeatState | seatId, occupant summary or empty, occupancy status |
| SessionSnapshot | id, roomId, phase, startsAt, focusEndsAt, breakEndsAt |
| Participation | userId, sessionId, goal, join/leave data, creditedSeconds, outcome |
| CompletionRecord | stable id, sessionId, userId, endedAt, creditedSeconds, outcome, isDemo |
| InvitationPreview | room summary, parent communities, eligibility and error status |

Define repository operations such as watchCurrentProfile, listJoinedSigs, watchSubgroupRooms, claimSeat, leaveRoom, startSession, finalizeParticipation, watchHistory and resolveInvite. Define errors such as fullRoom, seatTaken, membershipRequired, invalidInvite and unavailable instead of presenting raw exception strings.

Store shared dates in UTC and display local time. Use stable IDs for navigation. Do not pass whole Firestore snapshots between screens. Agree that Monday begins the weekly chart. Keep goal outcome separate from whether a timed session completed.

Fixtures to create now: two sample users, IoT/ESP32, Programming/Flutter, an empty room, a half-full room, a full room, a running session, an empty history and a few completions. Include an unusually long community title and a long goal for layout checks.

## 8. Design system: define once, reuse everywhere

Proposed palette (starting values, verify actual combinations before finalizing):

| Token | Value | Use |
|---|---|---|
| Primary | #225B3B | Main actions and active navigation |
| Background | #FAF7F0 | Page background |
| Surface | #FFFFFF | Cards and forms |
| Soft accent | #E4F0DF | Selected chips and supportive surfaces |
| Warm accent | #E4B35A | Small decorative highlights |
| Main text | #1E2B24 | Headings/body |
| Secondary text | #5F6D64 | Supporting labels |
| Border | #DCE3D8 | Card/input boundaries |
| Error | #B3261E | Error text and icons |

Use one font family initially; the platform font is fine. If choosing another, bundle licensed font assets so the demo does not depend on downloading them. Suggested type scale: page title 26–28, section title 20, card title 18, body 16 and supporting label 14 logical pixels. Avoid setting unrelated text sizes in individual screens.

Spacing scale: 4, 8, 12, 16, 24, 32. Base horizontal padding: 16–20. Card radius: 16; main controls around 12. Aim for at least 48 logical-pixel interactive targets. Verify contrast, TalkBack labels, text scaling, keyboard behaviour and Android safe areas; color alone should not communicate occupied/selected/error states.

Build these components before feature screens:

- StudyMatesTheme and shared spacing/text tokens.
- AppButton: primary, secondary, destructive, loading and disabled variants.
- AppTextField: label, helper, validation, password visibility.
- AppCard, InterestChip and AvatarBadge.
- LoadingView, EmptyView and ErrorView with optional retry callback.
- ConfirmDialog and a consistent bottom-sheet layout.
- Feature-specific SigCard, RoomCard and SeatWidget kept in their feature unless genuinely shared.

Create a development component-gallery route so every member can inspect these states. Do not expose developer switches in the final demo UI. Leave dark mode for later.

## 9. Design the screens in three passes

Pass 1 — wireframes: rough layout, content, primary action and navigation for every required screen. Paper or simple frames are sufficient. Do not polish illustrations yet.

Pass 2 — detailed references: finalize Discover, SIG/subgroup details, room lobby and focus screen, then the reusable forms/history/profile layouts. Reuse components. Screenshots generated as visual inspiration are not functional UI specifications; write down the states and interactions separately.

Pass 3 — runnable Flutter preview: implement shared components and route shells, then connect fixture-driven views. Feature owners can fill their assigned shells after handoff. Your preview is a UI prototype, not real synchronization or authentication.

Use a consistent 390 × 844 design canvas as a reference, not a fixed device size. Check at narrower/wider Android widths and with larger text. Content should scroll rather than overflow when the keyboard or system bars reduce available height.

Suggested design pages: Foundations, Components, Auth/Profile, Communities, Rooms/Sessions, Progress, Invites, States, Prototype. An optional design tool is useful only if it is already comfortable; a new tool should not delay implementation. Commit exported references to the repo so teammates do not rely on an external account to see the designs.

## 10. Complete screen and state inventory

Some entries are sheets or phases rather than separate full-screen pages. Keep that distinction to avoid unnecessary routes.

| ID | Screen/surface | Main content/action | Important states | Implementer |
|---|---|---|---|---|
| S01 | Startup gate | Restore identity/profile, route onward | Loading, unavailable, retry | M1 shell/M2 logic |
| S02 | Welcome | StudyMates value, Create account, Sign in | Small-screen layout | M2 |
| S03 | Sign in | Email, password, visibility, submit, reset link | Invalid input, rejected credentials, loading | M2 |
| S04 | Sign up | Name/email/password and create action | Invalid input, account error, submitting | M2 |
| S05 | Reset password | Email and send action | Validation, neutral sent confirmation | M2 |
| S06 | Profile setup | Name, preset avatar, interests | Required fields, saving, retry | M2 |
| S07 | Home | Joined SIGs, available rooms, progress shortcut | New user CTA, loading, no rooms, unavailable | M1 UI/M2 data |
| S08 | Discover | Search SIGs, category chips, SIG cards, create SIG | Results, no matches, loading, error | M2 |
| S09 | SIG detail | Description, owner, join/leave, subgroup list | Non-member/member/owner, no subgroups | M2 |
| S10 | SIG create/edit form | Name, category, description, save | Validation, submitting, owner edit | M2 |
| S11 | Subgroup detail | Topic, join/leave, rooms, create room | Non-member/member, empty/full room cards | M2 with M3 list |
| S12 | Subgroup create/edit form | Name/description, parent SIG, save | Owner only, validation, save error | M2 |
| S13 | Create room form | Title, parent subgroup, six-seat summary, create | Non-member, submitting, validation | M3 |
| S14 | Room lobby | Scene, six seats, participant labels, Invite, goal, Start/Join | Empty/taken/own seat; host/member; full; reconnecting | M1 scene/M3 behaviour |
| S15 | Goal sheet | Personal task, save/ready | Empty/long goal, saving, dismiss | M3 |
| S16 | Focus phase | Timer, personal goal, participants, next break, leave | Running, late join, reconnecting, ended | M3 |
| S17 | Break phase | Break timer, finish-focus feedback, return action | Break running/finished, host absent | M3 |
| S18 | Session summary | Recorded time, goal outcome, progress/room actions | Saving, saved, retry without duplicate credit | M3 |
| S19 | Invite sheet | Room name, QR and manual code | Loading token, unavailable, revoked token | M5 |
| S20 | Scan / enter code | Camera frame, torch if supported, code fallback | Permission request/denied, invalid QR, scanner paused | M5 |
| S21 | Invitation preview | Room and parent community, seats, join action | Membership required, full, invalid/expired/revoked | M5 with M3 admission |
| S22 | Progress | Recorded-time total, completed count, history | Empty, loading, error; optional weekly chart | M4 |
| S23 | Profile/settings | Avatar/name/bio/interests, edit, logout | Saving, logout confirmation | M2 |
| S24 | Decoration picker (optional) | Three milestones, locked/unlocked/equipped | Locked explanation, equip pending | M4 |

Design these shared surfaces too: leave-session confirmation, leave-community confirmation, network-status banner and generic retry. Do not show a notification bell, chat icon or settings switch if there is no implemented behaviour behind it.

### Main route proposal

| Route | Destination |
|---|---|
| /welcome, /login, /signup, /reset-password | Authentication |
| /setup | Profile setup |
| /home, /discover, /progress, /profile | Four main tabs |
| /sigs/:sigId | SIG detail |
| /sigs/new and /sigs/:sigId/edit | SIG form |
| /subgroups/:subgroupId | Subgroup detail |
| /sigs/:sigId/subgroups/new | Subgroup form |
| /subgroups/:subgroupId/rooms/new | Room form |
| /rooms/:roomId | Lobby |
| /rooms/:roomId/session/:sessionId | Focus/break phases |
| /sessions/:sessionId/summary | Personal summary |
| /scan | Scanner/manual-code surface |
| /invite/:token | Invitation preview |

Use named routes where helpful, preserve tab stacks, and make auth/onboarding redirects depend on explicit loading/signed-out/incomplete/ready states. Keep a pending invitation across login, then revalidate it. Define not-found/unavailable routes. Do not assume a URL pattern grants access; the backend still checks authorization. Hide bottom navigation during the active focus screen; Android back should offer a clear leave action rather than silently losing context.

## 11. Build the room scene correctly

The scene is the visual signature of StudyMates. Start with a simple fixed-camera 2D/isometric room and six empty desks. It is a Flutter interactive scene, not a game world.

Prepare assets separately:

- Empty-room background with consistent perspective and lighting.
- Preset seated avatars with transparent backgrounds and a consistent scale.
- Optional desk foreground/occlusion layer if avatars need to appear behind desks.
- Optional desk plant/decoration assets.

Render the room inside an aspect-ratio-preserving container. Position seats/avatars using normalized coordinates relative to the actual painted image bounds, not raw screen coordinates. Align taps to the same transformed bounds; resizing must not move tap targets away from desks. In a perspective view, choose back-to-front layer order so avatars do not overlap incorrectly.

Seat widget states: available, selected, yours, occupied, claim pending, claim failed. Identify occupants with a short label/accessible description. Disable repeated claims while pending and recover from a seat conflict. Selection in a UI preview is not a successful server reservation.

Prototype with colored placeholders first, then replace assets. Keep timers, names, buttons and all dynamic text as Flutter widgets. Do not bake changing values or people into the room background. Limit initial animation to subtle transitions; protect usability and tap accuracy.

## 12. Make a preview that works without Firebase

Create main_preview.dart with fake repository overrides. Keep preview setup and fixtures in lib/preview and make the runtime visibly say UI Preview in development. Do not silently use fake data when the real backend fails.

After that entry point exists:

```bash
flutter run -t lib/main_preview.dart
```

The preview should navigate from Home/Discover to IoT, ESP32, a room, goal, focus and summary. Local interactions may change fixture state for design review, but no screen should claim another real user joined. Keep sample timer/rewards clearly separated from production state.

Provide a development-only way to inspect empty/loading/error/full states and long text. Do not make every route a static screenshot. Components should consume models and callbacks that feature owners can wire to real services.

M4 can implement progress from completion fixtures immediately. M5 can read a test token before invitation services are ready. M2/M3 should receive fixture-backed consumers while they build actual repositories.

## 13. Firebase ownership and your minimum coordination

You decide the final application ID with M2 and agree which shared development Firebase project the team uses. M2 creates/configures it, enables email/password authentication and Firestore, and owns the first access rules. You should have appropriate project access so the app is not tied to a single unavailable member; never share passwords.

When M2 is ready, the official setup uses the Firebase CLI and FlutterFire CLI, followed by app initialization. Example workflow after Firebase CLI is installed:

```bash
firebase login
dart pub global activate flutterfire_cli
flutter pub add firebase_core firebase_auth cloud_firestore
flutterfire configure
```

Select the intended shared project and Android platform. Configure Firebase initialization in the real entry point, using the generated options. Ensure preview tests remain independent. Check package requirements against the chosen Android SDK/minimum version; do not randomly change Gradle/Kotlin/JDK versions to fix an unrelated error.

Firebase documents the generated firebase_options.dart identifiers as non-secret configuration. That does not make the database safe: security rules must enforce access. Document whether development client config is tracked in the private repo or supplied separately. Never put a service-account private key in the mobile app. Review any paid service requirement before enabling it. The foundation does not need storage uploads, cloud functions or an AI API.

## 14. Verify before handing over

Check the actual app, not only generated screenshots. From the app root:

```bash
dart format lib test
flutter analyze
flutter test
flutter run -t lib/main_preview.dart
```

Replace the starter counter test with a meaningful app-shell/navigation smoke check when the counter is removed. Avoid tests that merely repeat constant color values. Verify that the preview opens without Firebase access, each tab navigates, details receive the correct IDs and empty/error states recover.

Manual visual checks: narrow/wider phone, larger system text, keyboard open, system back, long names/goals, unknown route, no image asset, loading/error/empty screens, selected and occupied seats. Test tap targets and TalkBack labels for custom scene controls. Do not disable text scaling just to fit a mockup.

Make a preview APK when useful:

```bash
flutter build apk --debug -t lib/main_preview.dart
```

This verifies the preview entry point only. The connected app and final assignment APK require their own verification later. Keep a tested foundation commit; optionally tag it foundation-v0.1 after it passes. Do not tag a broken skeleton as ready.

CI can be added once the local checks pass: run format-check, analysis and appropriate tests on PRs using the same pinned Flutter version. CI should use fixtures/emulators for tests and must not depend on a developer's Firebase login. It is useful, but not a blocker to inviting the team.

## 15. Give each member a small first issue

| Member | First implementation task | Inputs you provide | First proof |
|---|---|---|---|
| M2 | Authentication/profile plus initial contracts | Auth references, shared controls, application ID | Account state works on Android |
| M3 | Room stream and seat claim operations | Room scene, seat-state contract, fixture route | Two clients occupy different seats |
| M4 | Read-only history screen | Completion fixtures, total rules, progress reference | Empty and populated screens work |
| M5 | Camera scanning spike | Scanner design, test token format, callback contract | Real phone reads test QR once |

Each issue should contain purpose, owning paths, screenshot/reference, input/output contract, success/error cases, checks and reviewer. Example for M4: show unique completed normal sessions, exclude demo records from normal totals, handle empty/loading/error, do not modify session finalization or shared schema.

Your handoff note should say: repository URL, tested commit/tag, Flutter version, preview run command, design references, first issue per member, which interfaces are fake and which are live, and who can approve shared changes. Have one teammate clone the project fresh and follow README without verbal assistance. Fix missing steps before declaring the foundation complete.

After delegation, you continue design polish and integration. Do not take over every visual implementation; ask members to use your components and return screenshots. Freeze shared-model changes briefly while part-time members are working, or provide explicit migrations and fixtures when changes are necessary.

## 16. Codex prompts for your startup work

Run one stage at a time. Inspect changes and run the app between stages; do not paste all stages as one request to build the entire product.

### Prompt A — repository foundation

```text
Read AGENTS.md, README.md and docs/project-plan.md, if present.
Inspect the generated Flutter Android project before editing.
Set up the agreed feature-folder skeleton, shared app configuration and preview
entry point. Use Riverpod and go_router compatible with pubspec.lock.
Keep a runnable placeholder screen. Do not configure Firebase, deploy services,
implement feature logic or add unrelated dependencies. Explain the proposed
structure, implement the small foundation and run analysis/relevant checks.
Replace the counter test appropriately if the counter screen is removed.
```

### Prompt B — design system

```text
Read docs/design/design-system.md and the existing theme/widgets.
Implement only the shared theme, text/spacing tokens, button, text field, card,
avatar and loading/empty/error components. Include a development component
gallery with disabled/loading/validation examples. Preserve text scaling and
Android safe areas. Do not build every product screen or change data contracts.
Run formatting/analysis and give a manual Android preview checklist.
```

### Prompt C — screen shells and navigation

```text
Read docs/design/screens.md and docs/contracts.md.
Implement named route shells for the listed required screens and the four-tab
app shell, with explicit preview auth/profile states. Add a not-found route and
preserve pending invite intent through preview login. Use shared components.
Do not implement real authentication, database writes or unplanned screens.
Add a meaningful route smoke check and provide navigation steps to verify.
```

### Prompt D — first detailed UI slice

```text
Implement Discover, SIG detail and subgroup detail using the attached approved
references and shared components. Read their state specifications first.
Consume fake repositories through the agreed interfaces; do not hardcode a
separate copy of data in each widget. Include empty/loading/error/non-member
states, long text and join/create actions through callbacks. Keep backend logic
out of the screen. Report departures from the reference and manual checks.
```

### Prompt E — room presentation

```text
Build only the virtual-room presentation from the approved scene and seat data.
Render six interactive seats and separate avatars/decorations with coordinates
relative to the rendered image. Support available, occupied, selected, yours,
pending and failed states. Expose callbacks for seat taps and Invite/Start/Leave.
Use fixture state for now. Do not implement Firebase seat claims or timer logic.
Check scaling, tap alignment, text labels and missing-assets behaviour.
```

### Prompt F — handoff review

```text
Review the foundation against docs/handoff.md and the screen inventory.
Check whether a teammate can clone/run the preview from README, whether fixtures
are explicit, whether screens reuse shared components/models, and whether any
secrets or unrelated changes are present. Run available checks and fix scoped
foundation defects. Report remaining placeholders honestly. Do not generate
feature backends, deploy or claim synchronization from mock data.
```

For a task that changes shared contracts or dependencies, coordinate with its owner. Have Codex explain key decisions and errors in plain language. Each member remains responsible for understanding and demonstrating their submitted code.

## 17. Suggested order for your first three working days

| Day | Your main work | Release to teammates |
|---|---|---|
| 1 | Verify Android setup; create repo/app; record scope; create rough flows and shared theme | M2/M3 begin contracts/backend spikes; M5 prepares real phone |
| 2 | Complete screen inventory and key references; shared widgets/routes; fixture models | M4 builds history from fixtures; M5 builds scanner; M2 implements auth screens |
| 3 | Room presentation, core preview navigation, QA and fresh-clone handoff | Feature owners wire their screens; you retain design/integration |

If tooling takes longer, prioritize runnable project, stable contracts and minimum reusable components over final artwork. The foundation is ready when another member can run it and implement one assigned feature without guessing your design or duplicating architecture.

## Official references checked

- Flutter setup: https://docs.flutter.dev/install/with-vs-code
- Android toolchain: https://docs.flutter.dev/platform-integration/android/setup
- Creating an app: https://docs.flutter.dev/reference/create-new-app
- UI/data separation: https://docs.flutter.dev/app-architecture/guide
- Accessibility: https://docs.flutter.dev/ui/accessibility
- GitHub repository creation: https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-new-repository
- Firebase Flutter setup: https://firebase.google.com/docs/flutter/setup
- Riverpod package: https://pub.dev/packages/flutter_riverpod
- Routing package: https://pub.dev/packages/go_router
- Scanner package: https://pub.dev/packages/mobile_scanner
- QR rendering package: https://pub.dev/packages/qr_flutter
- Codex access: https://help.openai.com/en/articles/11369540-using-codex-with-your-chatgpt-plan
- Codex instructions: https://developers.openai.com/codex/guides/agents-md/

The palette, folder structure, screen inventory and schedule are design/project recommendations. Package versions should be resolved and checked at setup, then recorded in the application lockfile; this guide intentionally does not prescribe an untested version combination.
