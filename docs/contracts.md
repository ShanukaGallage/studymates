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
