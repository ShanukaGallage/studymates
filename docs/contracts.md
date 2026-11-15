# Initial contracts — foundation milestone

**Status:** design agreements only, pending M2/M3 review. No domain models,
repository interfaces, Firebase implementations or in-memory feature services
have been implemented. Placeholders do not imply loaded data or authentication.

Implemented now: `AppMode` (`foundation`, `preview`), its Riverpod provider,
router provider and four named routes (`home`, `discover`, `progress`, `profile`).
Preview additionally exposes `components`. Mode is configured at the entry point.

## Proposed shared models

| Model | Initial fields/meaning |
|---|---|
| UserProfile | id, displayName, avatarId, interestIds |
| SigSummary | id, name, description, ownerId, membershipState |
| SubgroupSummary | id, sigId, name, description, membershipState |
| RoomSnapshot / SeatState | id, subgroupId, hostId, title, six seat states, activeSessionId; seatId and optional occupant |
| SessionSnapshot | id, roomId, phase, startsAt, focusEndsAt, breakEndsAt |
| Participation | userId, sessionId, personal goal, join/leave intervals, creditedSeconds, goal outcome |
| CompletionRecord | stable id, userId, sessionId, endedAt, creditedSeconds, outcome, isDemo |
| InvitationPreview | token lookup result, room/parent summaries, eligibility or explicit error |

### Proposed identity and membership details (for M2/M3 review)

There is no existing user identity model or community membership model in the
Flutter code. `UserProfile`, `SigSummary` and `SubgroupSummary` in the table
above are proposals only; do not create parallel types under another name.
Keep these contracts independent of Firebase snapshot types.

| Contract concept | Proposed meaning |
|---|---|
| Auth/profile state | `loading`, `signedOut`, `incompleteProfile`, or `ready`. `loading` means the initial auth/profile lookup has not resolved; `signedOut` means no authenticated user; `incompleteProfile` means an authenticated user lacks required profile fields; `ready` means the authenticated user's required profile is available. A backend failure is an error/unavailable result, not a fifth identity state or a fake signed-out user. |
| User identity | Stable `userId` is the Firebase Authentication UID. Profile data carries that same ID, required `displayName`, preset `avatarId`, and `interestIds`. Email remains an auth credential/contact field, not the identity key. Avatar is a preset identifier; image upload/URL is out of scope for this contract. |
| SIG identity | Stable `sigId`; `SigSummary.ownerId` is the user ID of its owner. |
| Subgroup identity | Stable `subgroupId` plus its parent `sigId`; subgroup ownership is inherited from the parent SIG owner in the first version, not a separate subgroup owner. |
| Membership | SIG membership is keyed by `(userId, sigId)`. Subgroup membership is keyed by `(userId, sigId, subgroupId)` and must reference a subgroup under that SIG. Summaries may expose `membershipState` as `member` or `nonMember`; missing, denied, and unavailable data must remain distinguishable from `nonMember`. |
| Membership query | Proposed repository operation: check whether `userId` is a member of the requested SIG and, when supplied, its subgroup. For room admission, check both the room's parent SIG and subgroup against the authenticated caller; do not trust a client-supplied user ID. Return a typed result/error so M3 can distinguish `membershipRequired` from `unavailable`. |
| Subgroup owner permission | Only the owner of the parent SIG may create, edit or delete its subgroups in the first version. Membership alone grants no subgroup administration permission. Enforce this in repository/backend access rules, not just by hiding UI controls. |
| Leaving a parent SIG | Proposed cascade: leaving a SIG also removes that user's memberships in its subgroups, so subgroup membership cannot outlive parent membership. This denies future room admission through either membership. Whether an already seated user is removed immediately, and whether a current SIG owner may leave before transferring ownership or deleting the SIG, require M2/M3 agreement (see open questions). |

### Proposed cross-feature operations

Names and signatures below describe responsibilities, not implemented APIs.
M2 owns auth/profile and community repositories; screens/controllers should
consume those boundaries rather than Firebase directly.

| Proposed operation | Responsibility / consumer |
|---|---|
| Observe identity/profile state | M2 exposes the four states above and the current `userId`/profile when available. Shanuka can use this state for the startup gate: show loading while resolving, route signed-out users to welcome/sign-in, route incomplete profiles to setup, and allow ready users into the authenticated app. M2/M1 agree on route names and pending-link behavior before any global routing changes. |
| `isMember(userId, sigId, subgroupId?)` or equivalent | M2 provides authoritative membership lookup for UI and other feature repositories. It is not itself sufficient authorization if data can change between check and action. |
| `checkRoomAdmission(authenticatedUserId, sigId, subgroupId)` or equivalent | M2/M3 agree a single membership-aware boundary for M3 room admission. M3 obtains the caller from authenticated state and invokes the check as part of the admission operation; the backend must re-check membership atomically/under access rules at the point of seating to avoid stale-check races. M3 returns `membershipRequired` when either required membership is absent, and `unavailable` when it cannot verify. |
| Leave SIG | M2 removes the parent membership and applies the agreed subgroup cascade. Coordinate with M3 for active seats/rooms; do not silently treat a client-side membership cache as authoritative. |

## Proposed repository boundaries (not implemented)

| Owner | Boundary and planned operations |
|---|---|
| M2 | Auth/profile: observe identity/profile, signup/login/logout/reset, save profile |
| M2 | Communities: list/create SIGs, owner-created subgroups, join/leave membership |
| M3 with M2 | Rooms: watch rooms/seats, create room, claim/release seat, membership-aware admission |
| M3 | Sessions: observe shared schedule, save goal, start session, finalize participation once |
| M3 → M4 | History: read current user's unique completions and derive eligible totals |
| M3/M2 → M5 | Invitations: resolve token to preview; shared checked join operation for QR/manual codes |

Feature contracts and implementations will initially live in each feature's
`data/`; providers/controllers connect them to presentation. Share domain models
in `lib/core/models` rather than passing database snapshots through routes.
Future preview repositories must implement the same contracts and be explicitly
injected; never use UI-embedded copies of domain data.

Use stable string IDs, UTC timestamps and local display. Define explicit errors
such as `membershipRequired`, `seatTaken`, `fullRoom`, `invalidInvite` and
`unavailable`. Goal outcome is separate from timer completion. Completion identity
must prevent duplicate credit; demo records stay outside normal totals.
Lease durations, participation credit rules and the final storage schema remain
M2/M3 decisions after the two-device spike. These notes do not implement enforcement.
