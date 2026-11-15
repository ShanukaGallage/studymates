# M1 — Shanuka: UI and integration guide

Read the [common plan](00-common-plan.md) first. Your main work is the visual system,
room/session presentation and difficult cross-feature integration. Poojani,
Aradhana and Sandali implement their own feature screens using your components.
You are not responsible for writing every screen or every backend.

## Your files and boundaries

Own `lib/app`, both entry points, shared theme/widgets, Home, design/assets,
existing room scene/lobby/goal widgets, `room_scene_provider.dart`, session
screens/widgets, central preview composition and shared navigation tests.
Coordinate dependencies/Android config one short PR at a time. Poojani owns auth,
communities and Firebase bootstrap; Aradhana owns room/session logic; Sandali owns
scanner/history. Ask for state/callback contracts instead of copying their services.

Already available: shared controls, four tabs, gallery, community preview,
`RoomScene`, local goal sheet and fixture seat states. Improve these; do not rebuild.

## Step 1 — Publish one shared starting point

Inspect the uncommitted community/room work on `feat/community-preview`. Review the
changes, run checks, and inspect the room on your phone. Publish a reviewed baseline
through your Git workflow, then give everyone the same commit. Their earlier
successful device runs do not prove they have this latest code.

Codex prompt, after the common starter:

```text
I am Shanuka. Review the current foundation/community/room preview for handoff.
Inspect git status and existing changes; do not recreate any work or discard files.
Run analysis and tests, verify the preview on Android if a device is connected,
and identify scoped defects. Check README against what is implemented.
Do not configure Firebase or implement another feature. Give me a review summary
and the precise files to include in the shared baseline. Do not commit or push yet.
```

Done: all four confirm the same commit, preview command and IoT → ESP32 → room
path. Record the room phone check accurately. Keep test/device evidence brief.

## Step 2 — Freeze interfaces and release UI guidance

Meet with Poojani/Aradhana to review identity, membership, room, session, completion
and invite contracts. Sandali checks the invite/history inputs. Publish rough
screen behavior and state references rather than delaying for final artwork.
Specify loading/error/empty, host/member, non-member/full, and small-screen behavior.

Your difficult decisions: which app state owns routing, how pending invitations
survive login, how Android back behaves during a session, and how one set of
providers composes the connected app without hiding backend failures.

```text
Inspect the existing shared widgets and room scene and the agreed contracts in
docs/contracts.md. Prepare concise UI handoff notes for auth/profile, communities,
room/focus/summary, scanner and history. Identify reusable components and missing
states; do not redesign all screens or implement backend contracts yourself.
Keep detailed feature implementation with its owner. Do not promise an API that
Poojani/Aradhana have not agreed. List route requests separately from UI changes.
```

Done: teammates can implement one screen without inventing its inputs or styling.
You may refine colors/artwork later without changing public component signatures.

## Step 3 — Build focus, break and summary presentation from fixtures

Wait only for Aradhana's session/completion contract and fixture examples, not the
live backend. Own `features/sessions/presentation/screens` and `widgets`. Define
callbacks for start/leave/goal outcome/retry; Aradhana implements their behavior.

```text
Implement only the focus/break/session-summary presentation against Aradhana's
agreed models and fixture callbacks. Reuse the existing theme, goal sheet and
RoomScene. Render countdowns from provided UTC phase boundaries and a testable
clock; do not create a second session engine or perform database writes.
Show host/member, reconnecting, saving/saved/retry and labelled demo states.
Preserve large text, keyboard safe areas and clear leave confirmation.
Keep production integration separate and add focused presentation tests.
```

Done: one fixture can drive the screens; local display ticks do not write to
Firestore; summary clearly distinguishes task outcome from participation completion.
Do not present this fixture preview as synchronized across devices.

## Step 4 — Integrate identity and community routes

Requires Poojani's merged identity/profile state, auth screens and bootstrap
service. Poojani supplies Firebase initialization code; you own its call from
`main.dart` and route guards. Do not route through a fake identity on failure.

```text
Wire Poojani's merged bootstrap/auth/profile providers and screens into the
normal entry point and existing router. Handle loading, signed-out,
incomplete-profile, ready and initialization failure explicitly. Preserve the
independent main_preview.dart composition and its development-only routes.
Add named routes using stable IDs; keep a pending invite through login and
revalidate it before admission when the invite service exists. Do not implement
another auth repository. Test redirects, sign-out and unknown-route recovery.
```

Done: restarting restores identity, incomplete profiles go to setup, sign-out
leaves protected screens, and preview still works without Firebase access.
Poojani reviews this integration PR.

## Step 5 — Connect the live room and session UI

Requires Aradhana's merged room stream/admission operations; session wiring follows
once its contract implementation is ready. Coordinate the exact controller and
widget files first so two Codex sessions do not edit the room presentation together.

```text
Connect the existing room scene and session presentation to Aradhana's real
providers. Map backend seat/current-user/connection states to RoomSeat display
inputs and forward actions to the one shared admission/session service.
Keep RoomLobbyPreview and its 450ms simulated selection confined to preview.
Remove all preview success paths from connected room behavior. Do not change
transaction logic, credit policy or finalization schema. Verify two-device updates,
failed admission, reconnect presentation and safe Android back behavior.
```

Done: real success comes from the service result, not a tap; both devices render
one shared state; a busy/conflicting claim recovers without an extra local seat.
You own UI adaptation; Aradhana diagnoses backend races with Poojani.

## Step 6 — Integrate Sandali's screens, polish and rehearse

Sandali supplies scanner result/preview callbacks, history screen constructor and
route requirements. You add shared routes, invitation intent and progress-tab
wiring. For each merge, test the connected path and preview separately.

```text
Integrate Sandali's merged invite/history screens through the existing router
and providers. Preserve Aradhana's single checked room-admission method for QR
and manual entry. Reuse Poojani's identity state and keep private history scoped
to the current user. Do not rewrite scanner code or award completions in the UI.
Then fix only observed layout/accessibility/navigation defects on demo devices.
Report the exact candidate APK command, verification results and remaining gaps.
```

Done: the common plan's five-minute route works on the exact installed APK.
Freeze new features; use remaining time for regressions and repetition. Verify
contrast, TalkBack seat actions, long names/goals, text scale and keyboard/back.
Only create final room art after the connected path is stable; keep occupants,
names/timers and touch targets separate from the background.

## Dependencies and your next independent action

| Waiting for | What it unlocks | Work you can do meanwhile |
|---|---|---|
| Poojani identity/bootstrap | Connected entry point and auth guard | UI state specs, gallery, session fixture views |
| Aradhana room/session contracts | Correct UI bindings | Room scaling, accessibility, artwork prototype |
| Aradhana live operations | Two-device room/session flow | Fixture presentation and navigation tests |
| Sandali invite/history screens | Complete route integration | Device review and known UI fixes |

Review one small batch of PRs per work block. Reserve shared files visibly before
editing; release the reservation after merge. If another owner is stuck, take one
explicitly transferred task, not their entire module. Your first task now is Step 1.
