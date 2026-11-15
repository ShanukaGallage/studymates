# Community preview contracts

Implemented for the local preview; **M2/M3 review is still pending** before backend
integration. These are UI/service contracts, not a Firestore schema. There is no
real authentication, authorization, seat admission or synchronization yet.

## Implemented models

Shared definitions: `lib/core/models/community_models.dart`. All fields are final;
catalog/profile collections are immutable. Membership belongs to the current
preview profile, not to every user.

| Model | Fields / meaning |
|---|---|
| UserProfile | id, displayName, avatarId, interestIds; sample identity only |
| SigSummary | id, name, category, description, ownerId, membership |
| SubgroupSummary | id, sigId, name, description, membership |
| CommunityCatalog | profile plus SIG/subgroup lists; lookups return null for unknown IDs |
| RoomSummary | id, subgroupId, title, occupiedSeats, capacity (six); discovery only |
| MembershipState | notJoined / joined; owner permissions are not modeled yet |
| RepositoryException | notFound, membershipRequired or unavailable; no raw errors shown in UI |

## Implemented repository boundaries

- **CommunityRepository** (`features/communities/data`, M2): `loadCatalog`,
  `setSigMembership(id, value)`, `setSubgroupMembership(id, value)`. Mutations return
  a fresh snapshot. `CommunityController` publishes that snapshot through Riverpod
  so lists and detail screens share membership state. Failure preserves old data.
- **RoomRepository** (`features/rooms/data`, M3): `listRooms(subgroupId)` and
  `getRoom(id)`. Missing room lookup returns null; an empty list means no rooms.
  Room summaries may be previewed before membership; opening one never admits
  the user or reserves a seat. Providers expose loading/data/error states.
- **Composition:** `PreviewScope` overrides both repository providers with
  in-memory implementations from `lib/preview`. The normal entry point has no
  feature repository binding and does not expose these routes. No silent fallback.

Preview membership rules: joining a subgroup requires its parent SIG membership;
leaving a SIG clears all its subgroup memberships; rejoining does not restore
those memberships. Explicit set operations are idempotent. Leave actions ask for
confirmation. These local rules need M2/M3 review, then server-side enforcement.

## Fixtures and routes

`community_fixtures.dart` supplies sample profile Alex, IoT → ESP32,
Programming → Flutter/Dart basics, and a long-title Design SIG with no subgroups.
Rooms include First Sensor Project (3/6), Quiet Electronics Lab (0/6),
Sensor Study Club (6/6) and My First Flutter Screen (0/6). Dart basics has no rooms.

Routes carry IDs only: `/sigs/:sigId`, `/subgroups/:subgroupId`, `/rooms/:roomId`.
They belong to the Discover branch and preserve its stack when switching tabs.
Missing IDs offer recovery to Discover. Normal mode does not expose these routes.

`/preview-data` provides sample, empty, indefinitely loading and error-once
scenarios. Switching scenarios or resetting creates fresh repositories and clears
memberships. Error-once fails the first read of each repository; Retry reads again
without replacing that repository. Restart resets all data. Nothing is persisted
or transmitted. These controls are development-only, outside product navigation.

## Room presentation inputs (implemented, local UI only)

`RoomScene` accepts six `RoomSeat` values numbered 1–6, an `onSeatTap` callback
and `selectionEnabled`. `RoomSeatStatus` is available / occupied / selected /
yours / pending / failed. `SeatOccupant` contains a display name and avatar ID.
These types live beside the feature widgets, not in the shared backend models.

`roomSceneSeatsProvider` has no default source. PreviewScope explicitly binds it
to `room_scene_fixtures.dart`, derived from existing room occupancy summaries.
Changing the room repository/scenario recreates the inputs and clears local drafts.
No room repository operations or backend contracts were changed for this scene.

`RoomLobbyPreview` demonstrates callbacks with a local 450ms selection delay,
one selected seat, a one-shot simulated conflict and a local goal. Membership
controls UI availability only. No transaction, lease, presence or admission is
implemented; sample occupancy never changes when selecting a seat. The “yours”
state is gallery-only. The goal is trimmed and limited to 160 characters.

Drafts last only while the page remains mounted and membership is retained.
Switching tabs preserves the page. Popping it, losing membership, resetting the
scenario or restarting clears the draft and cancels pending timers. Invite and
Start open explanatory placeholders; they create no code, session or completion.
M3 should supply the same scene inputs/callbacks from real room state later.

## Later contracts — not implemented

Auth/profile services, community creation/owner edits, RoomSnapshot/SeatState,
SessionSnapshot, Participation, CompletionRecord and InvitationPreview remain
future work. Aradhana (M3) owns live seat claims, timing, completion writes and invitation
services; Sandali (M4) consumes completion history and invitation lookup/admission.
See the [current four-member plan](team/00-common-plan.md) for ownership and gates.

Use stable IDs, UTC timestamps and local display in future persistence. Admission
must enforce membership and atomic seating, and finalization must prevent duplicate
credit. Goal outcome is separate from timer completion. Demo records stay outside
normal totals. Lease durations, credit policy and storage schema need the M2/M3
two-device spike; this preview does not implement those guarantees.
