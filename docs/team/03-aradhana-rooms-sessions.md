# M3 — Aradhana: live rooms, sessions and invitation services

Read the [common plan](00-common-plan.md) first. You own the logic that makes two
phones agree: admission, occupancy, shared timing, eligible participation and unique
completion writes. Shanuka owns room/session presentation. This is the most
backend-heavy role; deliver one verified operation at a time, not the entire engine.

## Your files and boundaries

Own `features/rooms/data`, new live-room controllers, `features/sessions/data` and
session controllers, plus invitation service contracts/remote implementation in
`features/invites/data`. Agree specific filenames with Sandali before her parser
work. Produce separate room/session/invite test files and feature fixture files.

Reuse the existing RoomRepository discovery contract and RoomScene inputs.
`RoomLobbyPreview`, its local timer, `RoomSeat` display types and the existing
`room_scene_provider.dart` belong to Shanuka; they are not real admission logic.
Poojani coordinates shared models, memberships and rules; Shanuka owns app routes
and central composition. Do not build a competing scene, auth service or router.

## Step 1 — Publish small contracts and fixture handoffs

Inspect the shared baseline and `docs/contracts.md`. Agree with Poojani on IDs,
identity, membership enforcement and data ownership. Supply a proposed room/session/
completion/invitation contract to her for one consolidated PR. Sandali must review
invite and completion fields; Shanuka reviews state/callback usability.

```text
I am Aradhana. Inspect existing room discovery code, RoomScene display inputs,
preview fixtures and docs/contracts.md. Propose the smallest live-room, session,
completion and invitation service contracts needed for the common demo path.
Separate existing APIs from new proposals. Include errors, stable IDs, timestamps,
and example states for Shanuka and Sandali. Do not edit the shared contracts/models
file concurrently with Poojani; give me the proposed changes and integration impact
first. Do not implement Firestore logic or replace the room scene in this task.
```

Then implement the agreed feature interfaces/fixtures in a small PR. Provide empty,
half-full/full room states, host/member, late join, reconnect, summary saving/error,
and empty/normal/demo completion examples. No second shared model definitions.

Done: Shanuka can build session UI and Sandali can build invite/history consumers
without knowing your eventual database implementation. Decide the demo split
(proposed 45+15 seconds), unique completion key, credit policy and leave rules here.

## Step 2 — First room stream and atomic seating

Requires Poojani's real identity/membership check and a coordinated rules slice.
You can first implement emulator/fixture tests while those services are unfinished.
Start with room create/list/observe, then claim/release, not timing yet.

```text
Implement only the agreed room stream and checked claimSeat/releaseSeat slice
behind the room contract. Coordinate an active-room record so one user cannot
hold multiple active seats. Use transactions and matching access rules; no local
UI success assumption. Preserve six-seat capacity and explicit full/seatTaken/
membershipRequired/unavailable errors. Write meaningful concurrent-claim,
multiple-room and non-member tests. Send rule changes to Poojani's reserved PR
and expose state/callbacks for Shanuka. Do not add session timing yet.
```

Done: two authenticated phones show the same occupants; racing for one seat admits
only one; repeated requests are safe; leaving releases the user's seat. Tests must
exercise the real transaction/rules behavior, not just mocked success responses.

## Step 3 — Deliver invitation service early for Sandali

Do this as soon as admission works, before finishing all timer work. Agree the exact
versioned QR payload and manual-code representation with Sandali/Poojani. Both
must resolve to the same opaque invitation and shared admission operation.

```text
Implement only invitation creation/resolution and its adapter to the existing
checked room-admission operation. Use the agreed token format and preview/error
contract. Handle invalid, expired/revoked, full and membership-required outcomes.
A scan only opens a preview; joining requires explicit user action and any needed
membership consent. Revalidate at admission because room state can change after
preview. Do not implement camera UI, duplicate membership storage or bypass rules.
Provide valid/error fixtures and integration instructions to Sandali and Shanuka.
```

Done: Sandali can replace fake lookup callbacks with your real API. Invite preview
success does not reserve a seat. Poojani owns membership operations; coordinate the
consent flow rather than silently enrolling users by reading a QR code.

## Step 4 — Shared focus/break schedule and personal participation

Requires agreed schedule and participation policy, stable occupancy and Shanuka's
UI consumers. Implement start/observe/goal/leave in small increments. The session
continues when its original host leaves; future host reassignment is coordinated.

```text
Implement only the agreed shared session schedule and participation tracking.
Use shared UTC start/focus-end/break-end timestamps, not per-second database writes
or a separate timer origin on each phone. Handle unresolved time/loading honestly.
No participant can pause everyone. Track eligible late-join/early-leave intervals,
background/resume and the documented treatment of unknown disconnected intervals.
Keep demo cycles explicitly flagged and separate. Expose state for Shanuka's UI;
do not implement another focus screen or completion award path in widgets.
```

Done: both devices show the same phase; restarting/resuming does not restart the
schedule; late join and early leave follow recorded rules. UI ticks are display
updates only. Never automatically credit the full room duration to every participant.

## Step 5 — Exactly-once completion and Sandali's history handoff

You write completions; Sandali reads them. Agree a stable identity for each
user/session completion and an explicit distinction between a completed interval,
an early leave/cancellation, and the user's goal outcome.

```text
Implement only idempotent participation finalization and its completion record
using the agreed schema. Repeated calls, summary reopening and retry after a
network interruption must not award another completion. Derive credited time from
the documented participation policy; keep goal outcome separate and preserve
isDemo. Supply emulator tests for duplicate/concurrent finalization and private
ownership, plus seeded records and a query example for Sandali. Do not implement
progress totals or alter their schema independently after the handoff.
```

Done: reopening a summary/retrying leaves history count/time unchanged. Sandali
can query the current user's records and clearly separate demo history. Missing
records or save failures have a retry state; UI must not claim saved before success.

## Step 6 — Reconnect, leases and integrated reliability

Document exact renewable seat lease/grace durations after the first two-phone
spike. A lease is cleanup policy, not reliable foreground/background presence.
Use an unknown/reconnecting state rather than asserting someone is definitely
online. Expired-seat reclamation and future host claims must be coordinated.

```text
Review the connected room/session path for reconnect, expired seat reclaim,
background/resume, host departure and repeat finalization. Change only the named
failure case, using the agreed lease/credit policy. Revalidate membership on
admission and coordinate active-session community leave with Poojani.
Add tests that reproduce the failure and a two-phone manual sequence. Do not
weaken rules, auto-credit disconnected time or make UI-only host reassignment.
```

Done: the candidate handles conflicts/reconnects without duplicate seats or credit.
Test the exact demo APK with Shanuka and Sandali, including a near-end reconnect.

## Dependencies and conflict avoidance

| Waiting for | Needed for | Independent work |
|---|---|---|
| Poojani's identity/membership/schema agreement | Real room authorization | Contracts, fixtures and transaction/rules tests |
| Poojani's rules edit slot | Shared development integration | Isolated emulator tests and rule-change proposal |
| Shanuka's UI adapter | User-visible occupancy/session behavior | Service tests and logged two-client state comparison |
| Sandali's parser/preview consumer | End-to-end QR flow | Token resolver and race-at-admission tests |

Have Poojani review transaction/rule changes, and Shanuka review the UI contract.
Keep tests feature-specific. If timing correctness falls behind, freeze optional
features and ask for a bounded pairing task rather than giving Shanuka all backend
work. Your first deliverable is the contract/fixture handoff, then real seating.
