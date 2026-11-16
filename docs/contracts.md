# StudyMates contracts — preview and backend agreements

## Current connected implementation (16 November 2026)

Reconciliation checkpoint: the connected implementation is now merged with PRs
#25/#26/#31. M2's retry-safe membership changes and M3's TypeScript room helpers,
Firestore adapter and tests are retained. The active application binds
`FirestoreStudyRepository`; the separate `FirestoreLiveRoomRepository` remains an
unbound alternative whose claim method is intentionally unavailable. Do not bind
that alternative to production until its proposed callable path is implemented.
The TypeScript deployment entry point exports `cleanupMembership` and the Firebase
predeploy hook compiles it. Backend packages are installed from the lockfile and
`functions/node_modules` is no longer tracked.


This checkpoint supersedes earlier “not implemented” statements below. Shanuka
is covering M3 while Aradhana travels. `features/study/data/firestore_study_repository.dart`
binds LiveRoomRepository, SeatLeaseRepository, ActiveSessionRepository and
CompletionHistoryRepository. The original feature interfaces and fixtures remain.
`firestore_invitation_service.dart` uses the same transactional seat admission.
Production deployment/physical two-phone review remain separate verification gates.

Persistence: existing `sigs`/`subgroups`; `subgroups/{id}/rooms/{room}/seats/{seat}`;
`roomDirectory/{room}` locates subgroup; `activeSeatClaims/{uid}` holds a paired
claim ID and expiry. Public seat projections contain display name/avatar only.
Shared immutable `roomSessions/{session}` store server start and demo flag; exact
45/15-second or 25/5-minute phase ends derive from that start. Private
`users/{uid}/activeSession/current` stores participation/goal and claim identity.
`users/{uid}/completions/{session}` stores one immutable result. Opaque
`roomInvites/{token}` are bounded-lifetime, revocable room locators, not authorization.

`SeatLeaseRepository` gives typed release/renewal results with expected claim ID.
Return revalidates current membership, room/session association and the same
unexpired seat. No automatic re-claim or schedule reset. A finalized user cannot
rejoin the same cycle. History pages and complete summary remain independent.
See [demo runbook](demo-runbook.md) for the conservative credit policy and limits.

Spark membership departure uses authenticated self-cleanup: finish related
participation, release the user's seat, close hosted rooms and acknowledge the
matching pending request. See the Spark departure contract below. The optional
Admin cleanup worker retains its separate host-transfer behavior and tests;
it is not required or deployed on Spark.

## Earlier agreements and implementation history

The local preview models and repository boundaries below are implemented.
Identity/membership proposals still need M2/M3 review; the room/seat section
records their agreed decisions and remaining questions. Its proposed Firestore
structure is not deployed. There is no real authentication, authorization, seat
admission or synchronization yet.

## Implemented models

Shared definitions: `lib/core/models/community_models.dart`. All fields are final;
catalog/profile collections are immutable. Membership belongs to the current
preview profile, not to every user.

| Model | Fields / meaning |
| --- | --- |
| UserProfile | id, displayName, avatarId, interestIds; sample identity only |
| SigSummary | id, name, category, description, ownerId, membership |
| SubgroupSummary | id, sigId, name, description, membership |
| CommunityCatalog | profile plus SIG/subgroup lists; lookups return null for unknown IDs |
| RoomSummary | id, subgroupId, title, occupiedSeats, capacity (six); discovery only |
| MembershipState | notJoined / joined; owner permissions are not modeled yet |
| RepositoryException | notFound, membershipRequired or unavailable; no raw errors shown in UI |

## Identity and membership details (confirmed and pending)

The preview already implements `UserProfile`, `SigSummary`, `SubgroupSummary`
and `MembershipState` in `lib/core/models/community_models.dart`. Reuse and evolve
these types; do not create parallel models. The authenticated identity and backend
membership behavior below remain service-level contracts, independent of Firebase
snapshot types. Agreed behavior is marked below; none of it is implemented against
Firebase or live users yet.

| Contract concept | Meaning |
| --- | --- |
| Auth/profile state | `loading`, `signedOut`, `incompleteProfile`, or `ready`. `loading` means the initial auth/profile lookup has not resolved; `signedOut` means no authenticated user; `incompleteProfile` means an authenticated user lacks a display name; `ready` means the authenticated user's profile is available with a display name. A backend failure is an error/unavailable result, not a fifth identity state or a fake signed-out user. |
| User identity | Stable `userId` is the Firebase Authentication UID. Profile data carries that same ID, required `displayName`, optional `avatarId`, and optional `interestIds`. If no avatar is selected, use a default avatar. Email remains an auth credential/contact field, not the identity key. Avatar is a preset identifier; image upload/URL is out of scope for this contract. |
| SIG identity | Stable `sigId`; `SigSummary.ownerId` is the user ID of its owner. The owner automatically counts as a member of the SIG. |
| Subgroup identity | Stable `subgroupId` plus its parent `sigId`; subgroup ownership is inherited from the parent SIG owner in the first version, not a separate subgroup owner. |
| Membership | SIG membership is keyed by `(userId, sigId)`; the SIG owner automatically counts as a SIG member. Subgroup membership is keyed by `(userId, sigId, subgroupId)` and must reference a subgroup under that SIG. SIG membership does not by itself imply subgroup membership. Existing summaries expose `membership` as `MembershipState.joined` or `notJoined`. The proposed backend concepts `member` / `nonMember` should map to these values; agree any API rename before changing consumers. Missing, denied, and unavailable data must remain distinguishable from non-membership. |
| Membership verification | M2 provides authoritative SIG and subgroup membership information for the authenticated user. M3 requires active membership in both the room's parent SIG and subgroup for room creation and seat claims. Do not trust preview state or a user ID supplied by the UI. M2 and M3 must agree on the service interface; its names and signatures are not finalized. Membership absence and inability to verify must remain distinguishable. |
| Subgroup owner permission | Only the owner of the parent SIG may create, edit or delete its subgroups in the first version. Membership alone grants no subgroup administration permission. Enforce this in repository/backend access rules, not just by hiding UI controls. |
| Leaving a parent SIG (agreed M2/M3 behavior; implementation pending) | Leaving a SIG also removes the user's subgroup memberships and denies future room admission through them. If the user occupies a room seat or participates in a session, M2's SIG-leave operation coordinates with M3, who removes the user from the room, releases the seat, and ends their participation at the leave time. If the user is host, M3 transfers hosting to another eligible participant; if none is available, M3 closes the room. |
| SIG owner leaving (agreed behavior; implementation pending) | Ownership transfers to another eligible SIG member. If no eligible member exists, M2 marks the SIG `Closed` and notifies its remaining members. Existing membership records, subgroup information, and historical activity are retained. A closed SIG accepts no new memberships and allows no subgroup or room creation. |

## Proposed cross-feature operations

Names and signatures below describe responsibilities, not implemented APIs.
M2 owns auth/profile and community repositories; screens/controllers should
consume those boundaries rather than Firebase directly.

| Proposed operation | Responsibility / consumer |
| --- | --- |
| Observe identity/profile state | M2 exposes the four states above and the current `userId`/profile when available. Shanuka can use this state for the startup gate: show loading while resolving, route signed-out users to welcome/sign-in, route incomplete profiles to setup, and allow ready users into the authenticated app. M2/M1 agree on route names and pending-link behavior before any global routing changes. |
| `isMember(userId, sigId, subgroupId?)` or equivalent | M2 provides authoritative membership lookup for UI and other feature repositories. It is not itself sufficient authorization if data can change between check and action. |
| `checkRoomAdmission(sigId, subgroupId)` or equivalent | M2/M3 agree a single membership-aware boundary for Aradhana (M3) to use during room admission. It derives the caller from authenticated state, checks both parent SIG and subgroup membership, and the backend rechecks membership at the point of seating to avoid stale-check races. Return `membershipRequired` when either membership is absent and `unavailable` when membership cannot be verified. A UI membership lookup alone is not authorization. |
| Leave SIG | M2 owns the SIG membership change and subgroup cascade, including ownership transfer or closure status and member notifications, and coordinates with M3. M3 owns room removal, seat release, ending session participation at the leave time, and host transfer or room closure as described above. Do not treat a client-side membership cache as authoritative. |

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
confirmation. These local rules are preview behavior, not server-side enforcement;
M2/M3 must agree on their live backend enforcement before production membership
is enabled.

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
scenario or restarting clears the draft and cancels pending timers. Invite remains explanatory. Start opens the local session UI harness described
below; neither action creates a server session or completion.
M3 should supply the same scene inputs/callbacks from real room state later.

## Room and seat management agreement

The room/seat decisions in Aradhana's contract commit `afd0093` are recorded as
agreed by M2/M3; implementation is pending. They extend the preview boundaries
above without replacing the existing UI models or repository consumers.

### Planned live models (not implemented)

| Model | Fields / meaning |
| --- | --- |
| RoomSnapshot | roomId, subgroupId, title, createdBy, hostUid, status (`waiting`, `active`, `completed`, `closed`), createdAt, updatedAt |
| SeatState | seatId, nullable userId, status (`available`, `occupied`), claimedAt, leaseExpiresAt, lastRenewedAt; exactly six records per room |

These describe live data; `RoomSummary` remains the discovery model and
`RoomSeat` remains a presentation input. Adapt live data to the existing scene.

### Responsibilities

| Owner | Responsibility |
| --- | --- |
| M2 (Poojani) | Firebase Authentication, user profiles, a service exposing the<br>current Firebase UID, subgroup membership service/repository, Firebase<br>structure coordination and Firestore security rules |
| M3 (Aradhana) | Room and seat business logic, room repository, seat<br>claim/release/renewal behavior, room data services and related tests; reuse<br>M2 authentication and membership services rather than duplicating them |
| M1 (Shanuka) | Room scene presentation and navigation; UI consumes room data and<br>operations through presentation-facing providers/controllers, not direct<br>database operations |
| M4 (Sandali) | QR scanning UI; use the same checked room admission path as other join<br>methods |

### Room and seat behavior

- An authenticated member of a subgroup may create a room in that subgroup.
  The creator is the initial host.
- Every room has exactly six seats. A user must be authenticated and an active
  subgroup member to claim a seat.
- The Firebase Authentication UID is the common user ID. A user may occupy only
  one active seat across all rooms. The Team Playbook calls for a coordinated
  active-room record; its storage and transaction implementation are not
  specified here.
- Seat claims, releases and renewals are protected by Firestore transactions.
  Claims check expired leases before deciding whether a seat is available.
- Claiming the same seat as its current occupant is an idempotent success.
  Claiming another user's occupied seat returns `seatTaken`; claiming when the
  user already occupies a different seat in this or another room returns
  `alreadySeated`. A room with no claimable seat returns `fullRoom`.
- A user may release only their own seat, subject to the host permissions still
  to be confirmed below.
- When a user leaves a subgroup, any seat they occupy in that subgroup's rooms
  must be released under the membership-leaving policy. Cleanup must remain
  possible after their membership becomes inactive. The authorizing actor and
  transaction coordination between membership removal and seat release are
  pending confirmation.
- A seat lease lasts two minutes from claim. Active users periodically renew
  their lease. A disconnected user's seat remains reserved until lease expiry.
- If the host leaves the subgroup, hosting transfers to another eligible member
  currently participating in the room. If none is available, the room closes
  and remaining participants are notified.

### Proposed Firestore structure

Store each room and its seats at these paths; seats are a subcollection, not
embedded seat records in the room document:

```text
subgroups/{subgroupId}/rooms/{roomId}
subgroups/{subgroupId}/rooms/{roomId}/seats/{seatId}
```

This is the agreed proposed structure for coordination with M2; it does not mean
that Firebase, the collections, transactions or security rules are configured.

### Repository responsibilities and operations

The M3 room repository uses M2's current-UID and membership services. It owns
room creation and observation, and transactional seat claim, release and renewal
operations. It reports agreed domain errors rather than exposing raw database
errors. Presentation-facing providers/controllers connect the repository to M1's
room UI; widgets do not access Firestore. M4's QR flow must enter through the
same membership-checked admission operation.

Expected operations are: create a titled room for a subgroup; observe rooms in a
subgroup; observe a room and its seat changes; claim a seat; release the current
user's seat; and renew the current user's lease. These are responsibilities,
not implemented method signatures.

### Provisional Firestore repository foundation

`FirestoreLiveRoomRepository` in
`lib/features/rooms/data/firestore_live_room_repository.dart` implements the
existing room create/list/lookup/observation contract using the proposed paths
above and field names from `RoomSnapshot` and `SeatState`. It creates six
available seat documents with the room in a client transaction, after M2's
`verifyRoomEligibilityInTransaction()` returns `member`; this is not a security
guarantee until M2 approves matching rules. The current `firestore.rules` has no
room/seat matches. The adapter's schema, `roomId` query field, timestamp encoding
and null fields on available seats are provisional. It does not persist
`occupiedSeats`; discovery summaries derive occupancy from the six seat docs.
`claimSeat()` remains unavailable until the trusted callable contract is
implemented. No active-seat path or fields are defined by this adapter.

### Errors and remaining decisions

Use explicit errors: `membershipRequired` when the user has no active subgroup
membership, `seatTaken` when another user occupies the requested seat,
`alreadySeated` when the user occupies another seat in this or another room,
`fullRoom` when no seat is available, and `unavailable` when an operation cannot
be completed.

These errors and policies are not yet implemented.

Still requiring team confirmation:

- The exact host permissions for releasing another user's seat.
- How to choose among multiple eligible participants when transferring host,
  and how the room-close notification is delivered.
- Whether membership must still be active to renew an existing seat. Membership
  removal must not prevent release of that user's seat; the authorization and
  transaction coordination for this cleanup remain pending confirmation.
- The renewal cadence within the two-minute lease, and whether any grace period
  applies after expiry.
- The behavior of repeated release/renew requests and a repeated claim after
  that seat's previous lease has expired.
- Whether and how to schedule backend cleanup of expired seats. Cleanup is only
  a consideration; no scheduled process is agreed or implemented.
- The exact nullability and update semantics of seat timestamps when a seat is
  available, and the final Firestore schema details.

## Completion and history handoff

`CompletionRecord` is defined in `lib/core/models/completion_record.dart` for
M3 finalization and M4 read-only history. It contains a stable `recordId`,
`userId`, `sessionId`, the original personal `goalText`, UTC `endedAt`,
`creditedSeconds`, a typed timer completion status, a separate `GoalOutcome`
(`completed` or `unfinished`), and `isDemo`.
The model validates non-empty identity fields and non-negative credited seconds;
it does not enforce persistence uniqueness or calculate credited time. The stable
completion identity is per `(userId, sessionId)`; the exact ID encoding remains
an implementation detail, and duplicate finalization must be prevented by M3's
write path.

`TimerCompletionStatus` distinguishes `completed`, `endedEarly`, and `cancelled`.
These statuses describe the timer/session result only. The history summary's
`completedSessionCount` counts only non-demo records with
`timerStatus == completed`, independently of `goalOutcome`; early-left and
cancelled records are not completed sessions. An unfinished goal may retain
positive valid `creditedSeconds`. Demo records are excluded from normal totals
and counts.

`CompletionHistoryRepository` in
`lib/features/sessions/data/completion_history_repository.dart` is read-only and
has separate operations for the current user's history page and all-history
summary. It accepts no caller-supplied user ID; the production adapter must use
M2's current identity and enforce private user scope. Production auth/current-user
and membership interfaces are M2 integration dependencies and are not finalized.
The page token is opaque.
The all-history summary must come from the complete source, not a sum of the
currently loaded page, and must remain independent of page loading. The interface
and fixtures do not implement a production history adapter or authorization.
Sadali's M4 history adapter is responsible for defensive read deduplication by
`recordId`, as required by [the M4 guide](team/04-sandali-invites-progress.md).
This does not enforce unique persistence or replace M3's pending idempotent
write implementation.

Fixtures in `lib/preview/completion_fixtures.dart` cover empty history, multiple
normal records, an unfinished goal with retained credited time, early-left,
provisional cancelled, and demo records. Expected normal summary examples:

| Fixture | Normal credited seconds | Completed sessions |
| --- | ---: | ---: |
| Empty history | 0 | 0 |
| Multiple normal records | 3000 | 2 |
| Early-left record | 900 | 0 |
| Provisional cancelled record | 0 | 0 |
| Demo record alone | 0 | 0 |
| Duplicate read of one normal record | 1200 after deduplication | 1 after deduplication |

The demo record has 75 credited seconds and one completed timer for the separate
demo view; it contributes neither to normal total nor normal completed count.
Combined normal fixtures total 3900 credited seconds and two completed sessions.
The cancelled example assumes, provisionally, that cancellation means
participation with no eligible credit. This is not an approved policy. Other
fixture values are illustrative, not credit rules.

Still pending M2/M3 confirmation: the definition of cancellation used by the
provisional fixture; eligible-time calculation, including early-left and
disconnected/background intervals; and the authoritative all-time summary
query/source. M2's production auth/current-user and membership interfaces also
remain integration dependencies. Stable identity is required per user/session.
Duplicate finalization is not enforced by the model or repository interface; M3
must implement and test idempotent persistence before claiming exactly-once
completion.

## Implemented session timing

`features/sessions/data/session_timing.dart` provides the pure
`calculateSessionTiming` function: UTC boundaries determine waiting, focus,
breakTime or completed, with explicit invalid-timestamp results. It does not
start a live session, synchronize devices or write completion records.

## Active session contract and preview fixture

`ActiveRoomSession` in `lib/core/models/active_room_session.dart` carries the
current user's session schedule and derives participation as `valid` only from a
verified, matching occupied seat whose lease expiry is later than the supplied
UTC time. Missing, unverified, mismatched or expired seat evidence requires
revalidation. The constructor normalizes schedule timestamps to UTC and uses
`calculateSessionTiming` to reject invalid boundary order.

M1 can watch the current-account state through
`currentUserActiveSessionProvider` from
`lib/features/sessions/data/active_session_providers.dart`:

```dart
final activeSession = ref.watch(currentUserActiveSessionProvider);
return activeSession.when(
  loading: () => const LoadingView(),
  error: (error, stackTrace) => const SessionUnavailableView(),
  data: (session) {
    if (session == null) return const NoActiveSessionView();
    if (session.participationStatus == ParticipationStatus.requiresRevalidation) {
      return const RevalidatingSessionView();
    }
    return ActiveSessionView(session: session);
  },
);
```

`null` is confirmed absence; loading is a Riverpod state and errors mean the
lookup failed. The UID-keyed provider cancels/rebinds on account changes and
filters events whose session user does not match the current UID. The explicit
`activeSessionRepositoryProvider` has no default implementation. The
`FixtureActiveSessionRepository` in `lib/preview/active_session_fixtures.dart`
is test/preview-only. This milestone does not implement persistence, live
synchronization or app-restart restoration.

## App integration

The normal entry point initializes Firebase before auth/profile consumers mount.
`lib/app/account_access.dart` combines M2's authenticated UID and
`currentProfileProvider`: resolving → loading; no UID → signed out; missing profile
→ setup; matching valid profile → ready; lookup failure → unavailable. The latter
is an access error, not an additional identity state. Auth display name is not the
profile-completion signal. Existing auth/profile repository APIs are unchanged.

PreviewScope explicitly binds M4's history fixture repository for the Progress tab.
The scanner preview forwards raw capture to an unverified result view through a
root Navigator route observer; it does not parse or admit invitations. Persistent
history, invitation format and admission remain owned by their feature contracts.

RoomSnapshot and SeatState are implemented models in `core/models/room_models.dart`;
this does not imply live observation or transactional seat operations exist.

## Later contracts — not implemented

Community creation/owner edits, live room/seat operations,
session persistence and cross-device observation, completion finalization/history adapter and
production invitation lookup/admission remain future work. Aradhana (M3) owns live seat claims, timing,
completion writes and invitation services; Sandali (M4) consumes completion
history and invitation lookup/admission.
See the [current four-member plan](team/00-common-plan.md) for ownership and gates.

Use stable IDs, UTC timestamps and local display in future persistence. Admission
must enforce membership and atomic seating, and finalization must prevent duplicate
credit. Goal outcome is separate from timer completion. Demo records stay outside
normal totals. The agreed seat lease is two minutes; renewal cadence, cleanup,
credit policy and final storage details remain subject to the decisions above
and the M2/M3 two-device spike. This preview does not implement those guarantees.

## Session presentation handoff (local preview)

`SessionView` and `SessionSummaryView` in
`features/sessions/presentation/widgets/session_views.dart` render supplied timing,
goal, seat, elapsed display duration and the existing timer/goal outcome enums.
`preview/session_preview_screen.dart` owns disposable display ticks, fixed UTC
fixture boundaries, confirmation and failure simulations. RoomLobbyPreview forwards
`onStart(int seat, String goal)` only after a local selection and non-empty goal.
This callback is not admission. The preview uses a root Navigator page so tab
switching cannot silently bypass end confirmation.

No CompletionRecord is fabricated, persisted or injected into Progress. Summary
time is elapsed fixture time, not eligible credit. M3 must supply authoritative
session timestamps, admission/connection state and finalization results before
live integration. Production retry must use M3's idempotent finalization; the
preview's delayed summary callback only demonstrates pending/failure/retry UI.

## Room repository integration checkpoint

GitHub main's PR #19 adds `LiveRoomRepository` in
`features/rooms/data/room_repository.dart`: create/list/get room snapshots and
watch room lists, a room and its seats. `liveRoomRepositoryProvider` deliberately
has no default implementation. `FixtureLiveRoomRepository` is in-memory only;
merging it does not enable live rooms in account mode.

Next handoffs before connected room UI:
- Poojani: production current-user/membership verification and deployed access rules.
- Aradhana: backend binding for room streams, atomic claim/release, one-seat enforcement
  and lease handling. Confirm every stream subscriber receives an initial snapshot.
- Shanuka: map authoritative room/seat states into the existing scene after those
  operations are available; preserve the labelled local preview.
- Session integration follows authoritative timing and idempotent completion writes;
  Sandali then connects saved history.

`InvitationPreview`, result statuses and `InvitationService` already exist in
`features/invites/data/invitation_service.dart`. They are contracts with fixtures,
not a deployed lookup/admission backend. Scanner capture alone grants no admission.

## Configurable rooms and private admission

Connected creation accepts `capacity` (integer 2–40, default 6) and `isPrivate`
(default false). Both are immutable after creation. Existing documents without
these fields remain six-desk public rooms. Seats use stable `seat-1` through
`seat-{capacity}` IDs. The shared claim policy and room scene consume capacity;
preview fixtures stay six desks. Capacity and privacy are carried by RoomSnapshot
and RoomSummary; other feature repository interfaces remain compatible.

Public rooms retain SIG/subgroup eligibility checks. Private room metadata stays
discoverable with a lock indicator, but seats require a verified admission or room
creator/host identity. Opening a private tile/direct route prompts for an invitation
code unless already admitted. Codes must match that exact room and subgroup and
be unexpired/unrevoked. Code verification first creates the private room-access grant, allowing seat
reads. The following seat claim rechecks the token inside its transaction and uses
the same atomic claim path as public seating. Full/conflicting rooms never return
admitted without a confirmed seat. Host/creator may issue private-room invitations.

A private `users/{uid}/roomAccess/{roomId}` grant retains the original invitation
proof for that account, so returning does not require retyping a code. Tokens are
never copied into readable seat/claim projections. Only the account can read its
grant; rules validate its token on creation and forbid client mutation. Once
admitted, invitation expiry/revocation prevents new admissions, not existing grants.
Membership remains mandatory for every future seat claim and renewal. Metadata
visibility does not grant seat access or permission to start participation.

Deploy the updated Firestore rules before using these options on hosted Firebase.
These features use Firestore transactions and rules and do not require Blaze.

## Spark membership departure

The connected CommunityRepository supplies `completeOwnCleanup(requestId)` through
`SparkMembershipCleanup`. It runs after M2 creates/resumes removalPending and before
observing completion/finalizing. Only the authenticated user's records are touched.
Related participation is saved as goal unfinished, its seat is released, and rooms
the user hosts within the SIG/subgroup close. The account acknowledges only its
exact pending request with a server timestamp; rules require no active participation
or active claim and unchanged request ownership/scope. Another account cannot
acknowledge it. Parent ownership transfer/closure and subgroup membership cascade
remain M2 responsibilities. Room host transfer is not attempted on Spark.

Retrying SIG leave does not require the SIG to remain visible in the active catalog:
owner departure may already have closed it. Discover's pending-leave recovery
retries cleanup and idempotent finalization after response loss or app restart.
An unrelated active seat/session blocks acknowledgement until the user ends it.
Self-service acknowledgement/host-close permissions must be deployed in rules
before this version is installed; the optional Admin worker remains compatible.
