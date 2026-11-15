# StudyMates — initial UI design plan

This plan extends the existing Flutter design system. Use it with
[screens and states](screens.md), the [wireframe](studymates-wireframe.html) and the
[current four-member ownership plan](../team/00-common-plan.md).
The wireframe is a proposal to review, not final artwork or a new app implementation.

## Existing foundation to reuse

Source of truth: `lib/core/theme/app_theme.dart` and `lib/core/widgets`.
Use Material UI, Riverpod and go_router already in the lockfile. No new design
library or competing theme is needed. Start with light mode and the platform font.

| Token | Existing value | Intended use |
|---|---|---|
| Primary | #225B3B | Main action, selected state |
| Background | #FAF7F0 | Page background |
| Surface | #FFFFFF | Forms/cards |
| Soft accent | #E4F0DF | Supportive and selected surfaces |
| Main text | #1E2B24 | Body/headings |
| Secondary text | #5F6D64 | Supporting labels |

Use the existing error token for failures. Pair color with a label/icon; test actual
foreground/background combinations when adding component states. Existing active
text-pair tests passed, but that does not validate every future combination.

Typography: page title 26–28, section 20, card title 18, body 16, secondary 14 logical
pixels. Spacing: 4/8/12/16/24/32. Page padding 16–20, card radius 16, control radius
12. These are existing targets, not reasons to scatter constants into screens.

## Component handoff

| Reuse | Owner / integration |
|---|---|
| AppButton, AppTextField, AppCard, AvatarBadge | Shanuka maintains; all members consume |
| LoadingView, EmptyView, ErrorView/retry | Shared consistent recovery behavior |
| Community card / membership action | Poojani's existing feature widgets; keep domain-specific |
| Room card and occupancy text | Aradhana supplies state; reuse the community/room consumer pattern |
| RoomScene and goal sheet | Shanuka owns rendering; Aradhana supplies connected state/callbacks |
| Focus/break/summary views | Shanuka creates against Aradhana's agreed fixtures/contracts |
| Invite/scanner/history views | Sandali implements using the same shared controls |

One primary action per surface. Supporting actions should not compete with it.
Don't add decorative controls that imply missing functionality. Feature owners
provide screen constructors/provider requirements; Shanuka alone coordinates
shared routes, main entry points and central preview composition.

## Responsive and accessibility behavior

Use 390 × 844 only as a reference canvas, never a fixed Flutter screen size.
Review at 320px width, wider phones, landscape, larger system text and keyboard
open. Content and forms scroll. Keep safe areas and at least 48 logical-pixel
interactive targets. Do not disable text scaling to fit artwork.

Seat and icon controls need screen-reader labels and tap actions. Password visibility
needs a meaningful tooltip. Validation stays near its field; errors retain drafts.
Loading disables duplicate submission; return/back/leave behavior is explicit.
Test TalkBack on the actual Android device before the demo candidate is frozen.

## Room illustration direction

Use one calm, fixed-camera 2D room with six desks. The existing Flutter-drawn room
is the structure prototype. Later artwork must be an empty room with separate
avatar/decoration layers; keep all names, timers, statuses and actions as widgets.

Use normalized coordinates within the painted scene for avatars and touch targets.
Keep depth/layer order consistent and preserve tap alignment at every width.
Start with a small set of preset avatars; no walkable world, game engine or extra
room scenes. Track asset sources/licenses or generation provenance when art arrives.

## Design work sequence for Shanuka

1. Review flow, screen hierarchy, role-specific actions and error states with the
   team. Resolve the decisions listed in screens.md.
2. Refine Discover → SIG → subgroup using the current Flutter preview. Keep
   Poojani's consumers and repository boundaries intact.
3. Refine room lobby and focus/break/summary layouts together. Use Aradhana's
   session fixtures; do not implement another clock origin or completion writer.
4. Provide compact auth/profile, scanner/invite and history references to their
   owners: screenshot/layout, inputs, actions, loading/empty/error and back behavior.
5. Polish the room art after the connected path is reliable. Retest text, seating
   alignment and keyboard layout; rehearse the five-minute demo on two phones.

Publish one small reference/state change at a time. Changes to shared widget APIs
or route contracts need the coordinating owner's handoff before teammates adapt.
No report, slides or formal rubric are added by this design work.
