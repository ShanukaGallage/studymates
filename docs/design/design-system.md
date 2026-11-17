# StudyMates — UI design direction

## Concise screen copy

Keep the current status and next action visible. Use one short instruction where
needed; do not repeat card values in paragraphs. Room/session controls and
explanations live in **Room options**, **How rooms work** and **Session options**.
Progress keeps totals once, with raw identifiers under **Session details**. Partial
history, demo labels, errors and blocked-seat recovery remain explicit. Normal
own-seat state does not show a blocking warning. Keep long goals readable.

Use `AppDetails` for secondary content and `AppContentWidth` to cap reading width
at 720 logical pixels. Preserve 48px targets, scrolling and system text scaling.
The official responsive-layout skill is installed at
`.agents/skills/flutter-build-responsive-layout/SKILL.md` for the team's Codex
agents; it is development guidance, not an application dependency.

Launch update: lavender Android launch resources (including night and API 31+)
replace the stock launch window. The original book/two-learner emblem continues in
`lib/app/startup_splash.dart` during real Firebase startup, with a brief fade-in
that respects reduced motion. Do not add a timer to keep the splash on screen;
startup errors retain the existing recovery action. No new package or raster
asset is required.

Launcher icon: `assets/branding/launcher-icon.svg` is the editable legacy artwork.
Android uses separate purple background/vector foreground layers on API 26+,
with a monochrome layer on API 33+ and density-specific legacy PNGs below API 26.
The launcher label is **StudyMates**. Keep the book/two-learner emblem consistent
with the native and Flutter splash; no launcher-icon dependency is needed.

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
| Primary | #6548C7 | Main action, selected state |
| Background | #F8F7FF | Page background |
| Surface | #FFFFFF | Forms/cards |
| Soft accent | #ECE6FF | Supportive and selected surfaces |
| Main text | #211B3D | Body/headings |
| Secondary text | #655F78 | Supporting labels |

Use the existing error token for failures. Pair color with a label/icon; test actual
foreground/background combinations when adding component states. Existing active
text-pair tests passed, but that does not validate every future combination.

Typography: page title 26–28, section 20, card title 18, body 16, secondary 14 logical
pixels. Spacing: 4/8/12/16/24/32. Page padding 16–20, card radius 24, control radius
18. These are existing targets, not reasons to scatter constants into screens.

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

## Lavender Home refresh

The user's StudyZen reference supersedes the original green/cream palette. Adopt
its lavender atmosphere, purple feature cards, rounded white surfaces and soft
blue (#E4EEFF) / mint (#DEF4EB) accents. Primary purple is deliberately darker
than the reference for readable white button text. Hero gradients end at #7560C8.
Use the shared tokens; do not add another theme or external font dependency.

Home belongs to Shanuka. Its greeting consumes the existing profile; preview
community cards observe the same catalog as Discover. Account mode explicitly
marks community services as not connected. No fabricated progress, plans, streaks,
AI tips or notification badges. Keep Home/Discover/Progress/Profile navigation;
there is no floating add action without a supported creation flow.

The book decoration is original Flutter-drawn artwork. This refresh does not copy
the reference's logo, mascot or branded assets. Earlier HTML wireframes remain
flow references and may show the superseded palette. Physical classroom scenery
retains its original materials; its surrounding controls inherit the new theme.

## Progress overview refresh

Progress uses Discover's light surfaces, plum text and purple actions. Period and
Normal/Demo controls sit at the top; All time remains the default. The equal-height
totals cards always show the repository's complete Normal summary, explicitly
labelled even in Demo mode. Demo never changes those totals. The existing
CompletionHistoryRepository/controller and credit calculations are unchanged.

The chart retains seven local dates with the selected period applied, and states
its exact range. Empty time does not hide goal outcomes or history. Compact goal
counts use all loaded records in the selected period. Newest-first Session history
rows open scrollable details; pagination/error recovery remains read-only. Records
have no community/room name, so rows keep the existing Study/Demo session fallback.
Partial-history notices stay beside charts, outcomes, history and calendar, never
the complete-source totals. About your progress is available from the title's info
action. At large text sizes controls wrap, totals stack at equal height, and chart
values become a readable date/value list.

## Annual study heatmap

Study calendar is collapsed below Session history. Its header shows selected year
and active days (plus partial coverage). Expansion shows a year selector and one
month grid with Monday–Sunday weeks. Day targets are at least 48dp; the month can
scroll horizontally when needed. Both grid taps and the existing exact-date
picker inspect day totals. Daily credited seconds are grouped by local
session end date and deduplicated by record ID. Intensity levels: zero, >0–<30m,
30m–<2h, 2–<4h, and 4h+. Future dates have no intensity and cannot be selected.
Normal and demo views stay separate.
The annual section is independent of short-period filters. While older pages
remain, all values are explicitly partial and unfilled dates are unverified.
A production year-aggregate query is still needed for complete coverage without
paging through history; no new database interface or aggregation policy is imposed.

17 November Progress verification: 349 Flutter tests and analysis passed; Android
APK built/installed. Rendered at 320dp/200% text and checked live Normal/Demo,
period changes, year/grid-day selection and the date-picker dialog on 23129RAA4G.
The phone account had no saved sessions. Zero-time unfinished records, populated
session details and paging/retry were verified through independent widget tests.

## Discover list redesign

Discover follows the supplied single-column mockup: compact purple StudyMates
wordmark/QR header, heading with Create, search with inline clear, equal-width
All/My tabs, result count and bordered white full-width community cards. Card
body and Open/Explore actions share the existing SIG details route. Names wrap
without truncation; actions stack at narrow widths or large text sizes. Count only
active subgroups. The green Joined label never relies on color alone.

Pending leave requests appears below results only for a matching removalPending
membership, including cleanup-completed requests awaiting finalization. Recovery
uses the existing Spark cleanup. Sign-out is in the Profile header. The normal
Connected strip is removed; cache/unverified or failed reads show contextual
attention/retry states. Preview/emulator mode labels remain explicit. No package,
permission, route, membership-write or backend-rule changes accompany this layout.

17 November verification: 324 Flutter tests and analysis passed. Layout checked at
320/390 logical pixels and 200% text scaling. On 23129RAA4G / Android 15, the final
build was installed and visually checked with hosted data; All/My counts, no-match
search and clear-to-restore passed. The pending-leave reader/finalization check
passed separately against Firebase emulators on Android. No memberships were
changed during the hosted UI check.

## Inline community rooms

Community details use one vertical scroll: Discover/back and community actions,
icon/name/description, then bordered expandable subgroup cards. Only one subgroup
is expanded. Its room list, retry/empty state and permitted creation action stay
inside the card. Room rows show total desks, never inferred free seats; private
labels and admission checks remain. Membership/owner actions stay in their scope.
The community route retains expansion/scroll when a room is pushed and popped.
Existing subgroup deep links share the same room section. Headers stack and text
wraps at large text sizes, without a second vertical scroll surface.

17 November verification: 347 Flutter tests and analysis passed; Android APK built
and installed. Reviewed live subgroup switching and room open/back on 23129RAA4G;
the expanded subgroup and room positions were restored. Also rendered at 320dp
with 200% text. Creation targeting, permission gating and section error/retry were
tested without Firebase. No hosted memberships, room creation or seat claims were
performed during this UI check.
