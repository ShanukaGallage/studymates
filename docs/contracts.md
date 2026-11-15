# Initial contracts — foundation milestone

**Status:** Room and seat decisions below are agreed by M2/M3; implementation is
pending. Other proposed models and boundaries remain subject to review. No
domain models, repository interfaces, Firebase implementations or in-memory
feature services have been implemented. Placeholders do not imply loaded data
or authentication.

Implemented now: `AppMode` (`foundation`, `preview`), its Riverpod provider,
router provider and four named routes (`home`, `discover`, `progress`, `profile`),
and the pure session timing calculation. Preview additionally exposes
`components`. Mode is configured at the entry point.

## Proposed shared models

| Model | Initial fields/meaning |
| --- | --- |
| UserProfile | id, displayName, avatarId, interestIds |
| SigSummary | id, name, description, ownerId, membershipState |
| SubgroupSummary | id, sigId, name, description, membershipState |
| RoomSnapshot | roomId, subgroupId, title, createdBy, hostUid,<br>status (`waiting`, `active`, `completed`, `closed`),<br>createdAt, updatedAt |
| SeatState | seatId, nullable userId, status (`available`, `occupied`),<br>claimedAt, leaseExpiresAt, lastRenewedAt;<br>exactly six seat records per room |
| SessionSnapshot | id, roomId, phase, startsAt, focusEndsAt, breakEndsAt |
| Participation | userId, sessionId, personal goal, join/leave intervals,<br>creditedSeconds, goal outcome |
| CompletionRecord | stable id, userId, sessionId, endedAt,<br>creditedSeconds, outcome, isDemo |
| InvitationPreview | token lookup result, room/parent summaries,<br>eligibility or explicit error |

## Proposed repository boundaries (not implemented)

| Owner | Boundary and planned operations |
| --- | --- |
| M2 | Auth/profile: observe identity/profile, signup/login/logout/reset,<br>save profile |
| M2 | Communities: list/create SIGs, owner-created subgroups,<br>join/leave membership |
| M3 using M2 | Rooms: create and observe rooms; claim, release and renew seats<br>transactionally; enforce room/seat rules and expose room data<br>to consumers |
| M3 | Sessions: observe shared schedule, save goal, start session,<br>finalize participation once |
| M3 → M4 | History: read current user's unique completions and derive eligible totals |
| M3/M2 → M5 | Invitations: resolve token to preview; shared checked join operation<br>for QR/manual codes |

Feature contracts and implementations will initially live in each feature's
`data/`; providers/controllers connect them to presentation. Share domain models
in `lib/core/models` rather than passing database snapshots through routes.
Future preview repositories must implement the same contracts and be explicitly
injected; never use UI-embedded copies of domain data.

## Room and seat management agreement

### Responsibilities

| Owner | Responsibility |
| --- | --- |
| M2 (Poojani) | Firebase Authentication, user profiles, a service exposing the<br>current Firebase UID, subgroup membership service/repository, Firebase<br>structure coordination and Firestore security rules |
| M3 (Aradhana) | Room and seat business logic, room repository, seat<br>claim/release/renewal behavior, room data services and related tests; reuse<br>M2 authentication and membership services rather than duplicating them |
| M1 (Shanuka) | Room scene presentation and navigation; UI consumes room data and<br>operations through presentation-facing providers/controllers, not direct<br>database operations |
| M5 | QR scanning UI; use the same checked room admission path as other join<br>methods |

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
room UI; widgets do not access Firestore. M5's QR flow must enter through the
same membership-checked admission operation.

Expected operations are: create a titled room for a subgroup; observe rooms in a
subgroup; observe a room and its seat changes; claim a seat; release the current
user's seat; and renew the current user's lease. These are responsibilities,
not implemented method signatures.

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

Use stable string IDs, UTC timestamps and local display. Define explicit errors
such as `membershipRequired`, `seatTaken`, `alreadySeated`, `fullRoom`,
`invalidInvite` and `unavailable`. Goal outcome is separate from timer
completion.
Completion identity must prevent duplicate credit; demo records stay outside
normal totals. Participation credit rules remain M2/M3 decisions after the
two-device spike. These notes do not implement enforcement.
