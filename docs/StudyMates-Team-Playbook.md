# StudyMates — Project and team playbook

Prepared 14 November 2026. Planning baseline: five members, three with substantial weekday availability and two with limited availability. Shanuka owns UI design and integration. This is a development guide, not an assignment report. No implementation is claimed to exist yet.

## 1. Outcome and scope

StudyMates is an Android Flutter app for anyone who wants to learn with others. Users discover Special Interest Groups (SIGs), join topic subgroups, enter illustrated study rooms, set individual goals and complete shared focus sessions.

Example: IoT → ESP32 → First Sensor Project room → 25-minute session → personal history.

The app is a study companion. A timer records participation; it does not verify attention or teach the subject. Initial rooms provide companionship, goals and preset status, without voice/video or full chat.

### Release scope

| Priority | Features | Owner |
|---|---|---|
| Required | Email/password authentication, password reset, profile and preset avatar | M2 |
| Required | Create/discover/join/leave SIGs; owner creates one level of subgroups | M2 |
| Required | Subgroup membership and room discovery | M2 with M3 |
| Required | Create/join/leave six-seat rooms; live avatars; seat conflict handling | M3 |
| Required | Personal goal, shared focus/break schedule, session summary and unique completion record | M3 |
| Required | Camera QR invitations; manual code fallback and invalid/full-room states | M5 with M3 |
| Required | Personal session history and total recorded time | M4 |
| Required | Shared UI theme/components, one attractive room scene, navigation | M1 |
| Required | Access rules, connection states and recovery | M2/M3 with M1 review |
| Small enhancement | Weekly chart and three milestone decorations | M4 |
| Small enhancement | Owner-maintained resource links | M2 |
| Deferred | Full discussion feeds, voting, AI, voice/video, file uploads, 3D movement, public rankings, additional sensors | — |

For an open public release, add reporting, owner moderation and removal enforcement before launch. The assignment build uses controlled demo accounts; it is not a production public-community release. Public SIG creation means the product is open to different interests, not that the prototype must be publicly launched now.

## 2. Capacity and assignments

Use effort capacity, not equal feature counts. Full-day availability does not mean eight effective engineering hours daily. Provisional planning capacity: M1–M3 each 20–25 focused hours/week; M4–M5 each 4–6 hours/week. Confirm actual availability at kickoff. Reserve approximately 25% of the full-time capacity for reviews, integration and fixes. Four weeks is a planning target, not a guarantee.

| Member | Availability | Main ownership | Backup |
|---|---|---|---|
| M1 — Shanuka | High | UX/UI design, Flutter design system, navigation, room artwork/composition, integration and release | M2 reviews builds |
| M2 | High | Firebase setup, accounts, profiles, SIGs, subgroups, memberships and shared data contracts | M1 |
| M3 | High | Room services, live seating, focus sessions, completion records, reconnects | M2 |
| M4 | Limited | Read-only history/progress, then milestone decoration display | M1 |
| M5 | Limited | QR display/scanning, permission states and camera verification | M3 |

M4 and M5 get short tasks with fixed inputs and isolated files. They do not own authentication, global routing, schema decisions or the live timer. Their work starts with fixtures immediately. QR scanning remains required, so M5 must deliver a working camera spike by the end of Week 1; M3 takes over if that milestone is missed. M4's basic history is required; the chart and decorations are the first cuts if capacity shrinks.

## 3. Product behaviour to agree on Day 1

1. Any authenticated user may create a SIG. Its creator owns it.
2. Only the SIG owner creates subgroups in the first version. Members may create rooms inside subgroups they joined.
3. An invitation opens a preview. A non-member explicitly agrees to join the necessary SIG/subgroup before entering; QR scanning never bypasses access checks.
4. Rooms have six seats. A transaction admits one occupant to a seat; enforce one active seat per user with a coordinated active-room record and access rules.
5. The host starts a fixed 25-minute focus plus 5-minute break cycle. Solo sessions are allowed.
6. Participants can join late and receive only eligible participation time. Nobody pauses the shared timer for everyone.
7. A started schedule continues if the host leaves. Claiming a vacant host role for a future cycle is a coordinated update, never a local UI assumption.
8. A session and its participation records have stable IDs. A repeated finalization cannot award a second completion.
9. Task outcome is completed/unfinished and is independent of timer completion.
10. Display unknown connectivity rather than claiming a participant is definitely online. Reserve seats through a documented renewable lease with a grace period; expired seats can be reclaimed transactionally. Backgrounding must be tested because renewal may pause.
11. Allow a clearly labelled 60-second demo session, separated from normal progress and rewards. Demo rewards may be demonstrated in the separate demo dataset.
12. Rewards are cosmetic milestones, not proof of study or a fraud-resistant ranking system.

M3 documents exact lease/grace durations and the treatment of missing participation intervals after the first two-device spike. Do not credit all disconnected time automatically. Do not pretend that a seat-expiry policy is reliable foreground/background presence detection.

## 4. Project setup and technical baseline

Proposed stack: Flutter/Dart, Firebase Authentication, Cloud Firestore, Riverpod, one routing approach, bundled room/character assets and a maintained camera QR package. Do not add a separate custom backend, a game engine or multiple state-management systems for the first build.

Everyone installs Git, VS Code, Flutter/Dart extensions, the same Flutter SDK version, Android SDK/build tools and the official OpenAI Codex extension. Android Studio can be used to manage the Android SDK and emulator even though coding is in VS Code. Resolve Android-related `flutter doctor -v` findings; unrelated iOS tooling is not required. Verify `flutter devices` and run the shared project on Android. M5 needs a real camera-equipped Android phone early.

Shanuka creates the one Flutter project and remote repository. Everyone clones it; do not generate five apps and merge them later. Commit the app lockfile and record the SDK version. Use separate branches in separate local clones.

M2 creates a development Firebase project, configures authentication and data access, and gives only necessary access to collaborators. Check service/billing requirements before enabling additional products; do not assume all Firebase features are free. Keep admin credentials and release signing secrets out of the repository and Codex prompts. Do not use allow-all database rules for the shared demo environment.

| Area | Planned folder | Owner |
|---|---|---|
| Theme/shared widgets | lib/core/theme, lib/core/widgets | M1 |
| App navigation | lib/app | M1 |
| Auth/profile | lib/features/auth, lib/features/profile | M2 |
| Communities | lib/features/communities | M2 |
| Rooms/sessions | lib/features/rooms, lib/features/sessions | M3 |
| Progress | lib/features/progress | M4 |
| Invitations | lib/features/invites | M5 |
| Shared models/contracts | lib/core/models, docs/contracts.md | M2, agreed with M3 |
| Design references/assets | docs/design, assets | M1 |

Feature owners implement their own screens using M1's components. UI design ownership does not mean M1 writes every screen. M1 should spend roughly half the initial time on design/components and protect daily time for review/integration.

## 5. Day 1–2 contracts and fixture data

M2 and M3 write these together before feature development diverges. M1 reviews them; M4 and M5 receive stable examples.

| Contract | Inputs / outputs | Consumer |
|---|---|---|
| Current profile | User ID, name, avatar ID, interest IDs | All |
| Community summaries | SIG/subgroup IDs, name, description, joined state | M1/M2 |
| Room snapshot | Room ID, subgroup ID, host ID, six seat states, active session ID | M1/M3 |
| Invitation lookup | Opaque invitation token → preview or invalid/full/unauthorized status | M5 |
| Join room | Room ID and authenticated user → admitted or explicit error | M3/M5 |
| Session snapshot | Session ID, shared timestamps, phase, individual participation | M3 |
| Completion history | Unique record ID, user ID, session ID, credited seconds, finish time, goal outcome, demo flag | M4 |
| Equipped decoration | Allowed decoration ID for the current user | M3/M4 |

Use an in-memory implementation for unfinished services, not hardcoded behaviour embedded in UI widgets. M4 gets empty, one-session and several-session history fixtures. M5 gets valid, expired, full and membership-required invite fixtures. Fixtures allow parallel development; they are not evidence of working backend integration.

Store times consistently in UTC. Define the week start (Monday) and local-time display; aggregate a bounded recent history rather than repeatedly loading every session. M3 must use shared timestamps rather than per-second database timer writes. M2/M3 verify transactions, membership rules and exactly-once completion through meaningful tests.

## 6. Overall schedule

| Stage | M1 | M2 | M3 | M4 | M5 | Exit condition |
|---|---|---|---|---|---|---|
| Days 1–2 | User flows, theme, widgets, skeleton routes | Setup, auth, models/contracts | Room/session spike, contracts | Progress fixture screen | Real-device scanner spike | Everyone runs the same Android project; contracts agreed |
| Rest of Week 1 | Community/room design references and interactive room shell | Authentication and basic SIG/subgroup membership | Real shared room and seat transactions | History/total from fixtures | Scan a known test QR and return token | Two authenticated users occupy different seats in the same room |
| Week 2 | Screen reviews and scene polish | Community CRUD/access rules; integration support | Goals, shared timer, unique completion record | Connect real history once contract is ready | Real invitation preview and join integration | QR → room → session → saved history works |
| Week 3 | Final styling, responsive fixes, full-flow review | Empty/error/owner states, optional resources | Reconnect/host departure/duplicate handling | Optional chart, milestone decorations | Permission/error cleanup and phone checks | Candidate APK passes core acceptance checks |
| Week 4 | Release APK, polish and demo rehearsal | Access-rule regression and fixes | Real-time regression and fixes | Progress regression; explain own feature | Camera regression; explain own feature | Repeatable demo on two real Android devices |

Do not spend Week 1 only on mockups. Build one rough but connected path early. Keep one reusable room illustration, six static seat coordinates and preset avatars; avoid walkable worlds. If the live session is not complete by the end of Week 2, freeze enhancements immediately.

## 7. M1 — Shanuka: step-by-step

1. Confirm deadline, rubric and hardware requirement; record each member's available work slots. Assign names to M2–M5.
2. Create the shared repo, Flutter skeleton, navigation placeholders and project instructions. M2 owns Firebase configuration to avoid overloading you.
3. Sketch the main route: onboarding → discover → SIG → subgroup → room → focus → summary → progress. Set Home, Discover, Progress and Profile as bottom navigation.
4. Define color tokens, text styles, spacing, corner radii and reusable cards/buttons/inputs. Build these in Flutter once.
5. Design the community list/details and room/focus screens first. Deliver screenshots plus states and component references, not screenshots alone.
6. Produce a reusable room background without baked-in occupants. Keep avatars, selection outlines and desk decorations as separate layers. Provide seat coordinates that scale with the illustration bounds.
7. Give each owner a screen handoff: screenshot, component names, tap behaviour, data inputs, empty/loading/error states and small-screen expectations. They implement it with Codex and return screenshots.
8. Implement the room presentation shell with fixture participants while M3 builds its behaviour. Agree on its inputs so neither of you rewrites the other person's files.
9. Review a small batch of PRs in a predictable daily slot. Ask M2/M3 to review one another's logic first; you focus on integration and visuals.
10. Build/install the candidate APK, complete two-device rehearsals and freeze new features in the final week.

Done: every screen uses the same visual system, navigation works, text does not overflow on the demo phones, and the installed APK completes the full flow. Avoid becoming the sole person who can run or explain the app.

First Codex task: inspect the shared project, read docs/contracts.md and the design references, then implement only the app theme and reusable button/input/card components. Use a small preview screen. Do not change feature repositories or add a second state-management solution.

## 8. M2 — Full-time: accounts, communities and data

1. Run the shared app, agree on models with M3 and publish docs/contracts.md by Day 2.
2. Configure Firebase development access and implement signup, login, logout and reset. Verify an authenticated user persists across restart.
3. Implement profile creation, preset avatar and interests. Keep university information optional or omit it.
4. Implement SIG list/detail/create and join/leave with clear owner permissions.
5. Implement owner-created subgroups and subgroup memberships. Provide fixtures early so other screens do not wait for backend completion.
6. Connect room discovery through M3's agreed contract. Avoid creating a separate room implementation.
7. Add and test rules for own-profile edits, community ownership, membership and room access. Coordinate room/session rules with M3. Verify a second account cannot perform owner actions.
8. Add owner resource links only after the Week 2 complete flow works.
9. Support M3 on transactional seat/session issues; act as logic reviewer and backup for authentication/community bugs.
10. Prepare realistic demo SIGs and test users through a documented, repeatable setup, keeping privileged setup credentials out of the app.

Done: two accounts can independently join IoT/ESP32, the owner can create a subgroup, another user cannot edit it, and membership is respected by room admission.

First Codex task: implement the agreed authentication repository and login screen using the provided UI components. Add only the necessary authentication/profile access rules. Verify loading, invalid credentials and sign-out. Do not implement communities in the same task.

## 9. M3 — Full-time: rooms and sessions

1. Agree with M2 on IDs, membership, room states and completion schema; provide fixtures immediately.
2. Implement create/list/open room and stream participant changes to M1's room presentation.
3. Implement transactional seat claims, one active seat per user, leave/release and capacity checks. Test two simultaneous claims.
4. Expose a shared room-join method for both typed codes and QR invitations. Implement invitation lookup/admission with M2's membership checks; M5 owns scanning UI.
5. Build personal goal entry, host start and the shared timestamp-based focus/break schedule.
6. Handle late joins, early leaves and app resume. Record eligible participation time; do not just award the room's full duration to every participant.
7. Finalize participation once using a stable user/session identity. Provide a real history stream for M4.
8. Implement the agreed lease/reconnection policy and show uncertain connection state. Test host departure and reclaiming abandoned seats.
9. Add the labelled 60-second demo mode with separate demo data. Test duplicate completions and a near-end reconnect.
10. Pair with M5 for QR integration; take over the scanner if the Week 1 hardware spike slips. Own final two-device reliability checks.

Done: two phones agree on room occupancy and session phase; reopening does not reset the timer; repeated completion does not increase totals twice; QR and manual codes use the same admission logic.

First Codex task: implement only transactional claimSeat/releaseSeat operations behind the agreed repository contract, with meaningful tests for conflicting claims and non-member access. Use placeholder rendering. Do not implement the timer yet.

## 10. M4 — Limited availability: progress and rewards

Plan three 60–90-minute work blocks per week, adjusted to actual availability. Keep a short handoff note after every block. Do not wait for the timer backend before starting.

1. Block 1: set up the project, open M1's progress reference and inspect M3's completion fixture contract.
2. Block 2: implement a reusable history list using fixtures; support no sessions, one session and long goal text.
3. Block 3: implement total minutes and completed-session count. Exclude demo records from normal totals and avoid counting cancelled sessions as completed.
4. Block 4: connect M3's real history repository when available, without changing its schema. Show loading, retry and empty states.
5. Block 5: test restart persistence, duplicate record handling and a second user's isolation. Submit the required history feature by the end of Week 2 if the service is available; otherwise hand off a complete fixture-tested screen.
6. Block 6: add the weekly chart only after core history works. Test week boundaries using fixed dates and the agreed local-time convention.
7. Block 7: derive three cosmetic milestone unlocks from unique completed sessions. Add an equip action and connect the selected ID to M3's room presentation.
8. Final blocks: test the real demo dataset, capture screenshots and explain how totals are calculated.

Done: totals match the unique eligible records, cancelled/demo sessions are handled correctly, and history survives reopening. The chart and decorations may be dropped if hours are insufficient. M1 takes the small required history screen if M4 becomes unavailable.

First Codex task: create only the progress/history screen using the supplied fixture repository and M1's components. Use the published Completion model. Do not modify authentication, database schema or session finalization. Include empty/loading/error states and verify duration formatting.

## 11. M5 — Limited availability: QR invitations and hardware

Plan three 60–90-minute work blocks per week. This is bounded work but fulfils a required hardware criterion, so prove the camera early.

1. Block 1: run the app on a real Android phone. Agree on the QR package with M1/M3; record any Android SDK/build requirements before adding it.
2. Block 2: build an isolated scanner screen that reads a known StudyMates test QR and returns its token. Request permission only when scanning is opened. Stop/release the camera when leaving.
3. Block 3: handle denied permission, invalid payload and repeated recognition; return at most one accepted scan per interaction. Deliver this spike by the end of Week 1.
4. Block 4: build the QR invitation display with a manual room code. Use the approved invitation format; do not encode passwords or profile data.
5. Block 5: connect the scanned token to M3's lookup. Show room preview and explicit join; handle membership-required, full and revoked/expired invitations.
6. Block 6: scan from the second phone, complete the join, and verify the avatar appears on both devices. Submit by the end of Week 2.
7. Final blocks: test denial/retry, reopening scanner, low light, code entry and room-full behaviour. Document the successful Android device/build used.

Done: real camera scanning joins through the same checked path as manual code entry, and failure states leave the user able to recover. If Block 2 is not complete by the end of Week 1, hand the branch and error details to M3 immediately.

First Codex task: implement an isolated Android QR scan screen using the approved dependency. Accept only the StudyMates invitation format, return one token, and handle denied permission and disposal. Use a fake lookup callback; do not alter room membership rules or global navigation.

## 12. Codex and VS Code workflow

Checked against current official guidance on 14 November 2026: ChatGPT Go includes Codex access with plan-dependent limits; Codex Cloud is not included with Go. Use the official VS Code extension signed into each person's own ChatGPT account. Confirm each member can complete a small local edit on Day 1. Do not assume unlimited usage, a particular model or cloud delegation. Do not share logins or buy upgrades before checking the actual constraint.

Codex is the implementation assistant. Each member must read the diff, run the feature and understand the code they submit. Smaller tasks reduce retries and inconsistent architecture. Avoid asking five separate Codex sessions to build the whole app.

### Per-task workflow

1. Pull the latest main with a clean working tree; make a short feature branch.
2. Read the task acceptance criteria and relevant design/contract files.
3. Ask Codex to inspect the existing implementation, then implement one bounded change.
4. Keep schema, dependency or shared-route changes explicit and coordinate them with their human owner.
5. Review the diff before accepting the work. Revert unrelated edits.
6. Format, analyze, run applicable tests and manually use the feature on Android.
7. Submit a small PR with screenshots, checks and remaining limitations.
8. After merge, start the next task from current main rather than continuing a stale branch indefinitely.

If usage runs out, continue manual debugging/testing, screen review or fixtures, or resume when allowance returns. Nobody's delivery should depend on a cloud agent running overnight.

### Reusable task prompt

```text
Read AGENTS.md, docs/project-plan.md, docs/contracts.md and the relevant design reference.
Inspect the existing implementation before changing files.

Task: [one concrete behaviour]
Primary files: [feature directory and relevant tests]
Existing contract: [model / repository / route]
Design: [screenshot and named components]
Acceptance criteria:
- [observable success]
- [important error case]
- [state persistence or access rule if relevant]

Implement this task using the existing architecture and shared widgets.
Keep changes focused. Coordinate any required shared-schema, dependency or routing
change instead of silently introducing a conflicting design.
Do not deploy, change billing, expose credentials or weaken access rules.
Run formatting, analysis and relevant tests where available; state what could not run.
Finish with changed files, verification results and an Android manual-check sequence.
Explain the key logic so I can review and demonstrate it.
```

### Root AGENTS.md starter to adapt in the actual repository

```markdown
# StudyMates project instructions

- Android Flutter app. Read docs/project-plan.md and docs/contracts.md.
- Use the agreed Firebase and Riverpod architecture; reuse existing repositories.
- Feature owners implement screens from Shanuka's references and shared components.
- Do not introduce competing themes, routers, models or state libraries.
- Keep database operations out of presentation widgets.
- Use shared session timestamps, atomic seat claims and unique participation records.
- Respect membership/ownership rules. Never use allow-all shared database rules.
- Use fixtures behind contracts for unfinished dependencies; label demo data.
- No voice/video, full chat, AI tutor, 3D engine or new scope without a team decision.
- Keep changes focused. Coordinate shared schema/dependency/routing changes.
- Run formatting, flutter analyze and relevant tests. Report checks not run.
- Do not commit secrets, deploy services or change billing as part of feature tasks.
- Summarize the diff and give manual Android verification steps.
```

This AGENTS.md is proposed guidance, not a skill installation or a file already added to a repository. Codex documentation explains how repository AGENTS.md instructions are discovered.

## 13. Git, reviews and integration

Use one main branch and short branches such as feat/sig-membership or feat/qr-scanner. One person owns a shared file change at a time. M2 and M3 review each other's logic; M1 checks shared UI/navigation and final integration. Avoid long-lived branches for a whole module.

Daily full-time check-in: completed, next, blocked. Part-time members post an update after each work block, including branch, next step and any blocking error. Keep one GitHub issue per small deliverable. Do not rely on chat history as the only specification.

PR description: what changed; acceptance criteria met; commands/tests actually run; screenshot/video for UI changes; dependencies or follow-up work. A green analyzer alone does not prove real-time or permission behaviour.

Typical checks from the app directory:

```bash
dart format lib test
flutter analyze
flutter test
flutter run
```

Adapt paths to those present. Use focused tests during development and the complete relevant suite for the candidate build. M1 produces the final Android APK with the team's documented release configuration; install and test that exact artifact rather than relying only on hot reload. No Play Store publishing is required for this demo.

## 14. Acceptance and demo checklist

- Two distinct accounts can create/join the intended community hierarchy.
- A non-owner cannot edit another owner's SIG/subgroup; users cannot read another's private history.
- Two users racing for one seat cannot both occupy it.
- A user cannot occupy multiple active seats.
- QR scanning works on the actual demo phone with permission allowed, denied and retried.
- Full/invalid/revoked invitations have recoverable errors.
- Both devices show the same scheduled phase; background/resume does not reset the session.
- Late join, early leave, host departure and reconnect follow documented behaviour.
- Reopening summary/finalization does not duplicate progress or rewards.
- Completed time agrees with the documented participation policy.
- Demo sessions are clearly labelled and separated from ordinary totals.
- Long text and the keyboard do not break screens on either phone.

Demo order: join IoT/ESP32; create First Sensor Project; display QR on phone A; scan on B; choose adjacent seats; enter separate goals; run a labelled 60-second demo session; show summary/history; optionally equip a demo decoration.

Prepare reliable connectivity, two accounts, the installed candidate APK, charged phones and a repeatable demo reset. A backup recording can help explain an outage but should never be presented as live behaviour.

## 15. First-day checklist and fallback decisions

M1: publish the skeleton, theme starter, rough screen flow and ownership table.
M2: prove signup/login and publish initial model/contract drafts with M3.
M3: prove shared room data reaches two clients and define seat/session operations.
M4: run the app and render one fixture completion record.
M5: run on a phone and start the camera scanner spike.

By Day 2, every member should show a running screen and name their next small deliverable. If the shared contracts or reusable components are delayed, owners build against agreed fixtures while M1/M2 resolve the blocker. If the room/timer milestone slips, cut charts, rewards and resources before adding more members to the same files. Keep camera integration and the central study flow.

## Sources checked

- OpenAI, Using Codex with your ChatGPT plan: https://help.openai.com/en/articles/11369540-using-codex-with-your-chatgpt-plan
- OpenAI, Codex IDE extension: https://developers.openai.com/codex/ide/
- OpenAI, AGENTS.md guidance: https://developers.openai.com/codex/guides/agents-md/
- Flutter, Install Flutter with VS Code: https://docs.flutter.dev/install/with-vs-code
- Firebase, Flutter setup: https://firebase.google.com/docs/flutter/setup
- Firebase, transactions: https://firebase.google.com/docs/firestore/manage-data/transactions
- Firebase, presence limitations: https://firebase.google.com/docs/firestore/solutions/presence

The role allocation, effort estimates, scope and delivery schedule are project recommendations, not vendor claims. Verify package compatibility at project setup and do not promise exact Codex limits or unverified Firebase costs.
