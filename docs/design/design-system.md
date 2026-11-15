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

The [classroom mockup](room-classroom.html) is the approved visual direction:
two columns and three rows of illustrated desks. `RoomScene` now implements this
layout with original Flutter vector art and a classroom header in the room preview.
No external artwork, fonts or packages are needed. The HTML remains a design
reference; its live connection, host and focus samples are future integrations.

Each desk separates scenery/avatar art from names, statuses and touch targets.
Keep six stable seat numbers and existing `RoomScene` inputs/callbacks; Shanuka
owns the rendering change and live-data adapter. Aradhana's live repository should
not depend on grid geometry, artwork or presentation-only pending/failed states.
The scene uses responsive cards with natural text height, capped at 640 logical
pixels overall. Below 280 pixels of available width or above 150% body-text
scaling it uses one column. Cards retain 48px minimum actions and vertical scrolling.

The reference includes nine sample states: lobby, local selection, pending,
confirmed sample seat, conflict, failure, reconnecting, full and focus. Host/member
controls are distinct. Focus time is frozen; no backend/session behavior runs.
Personal goals remain in the current user's panel; public goals would require a
separate visibility agreement. Do not infer sharing from the supplied image.

The existing preview selection, goal entry, conflict simulation and gallery remain
operational. Review desk size, scrolling and avatar appearance on the phone before
connecting live data. Preset IDs determine avatar appearance; no game engine or
walkable world is needed. Personal names and statuses are ordinary Flutter text.

Mockup verification: inspected desktop and phone renders in headless Chrome;
108 combinations of state/role, 320/390/1280px viewport and 100%/200% text size
passed six-seat and page-overflow checks. Selection/clear and host focus navigation
passed. Android, TalkBack and Flutter behavior are not validated by this HTML.

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
