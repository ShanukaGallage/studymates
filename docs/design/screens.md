# StudyMates screen and flow wireframe

Status: **design proposal for team review**, not a claim of implemented backend
behavior. Open [the clickable wireframe](studymates-wireframe.html) directly in a
browser. No server, external assets or network connection is needed.

## How to review

1. Start with **Overall flow**. Select a card to inspect its screen.
2. Use **Screen walkthrough** to follow account → Discover → SIG → subgroup →
   room → goal → focus → break → summary → progress.
3. The right-side inspector shows ownership, current implementation status, route
   and state choices. It can jump directly to a screen without satisfying normal
   prerequisites; this is a design-review tool, not an access-control test.
4. Try **Invite someone → open on a signed-out phone → sign in → consent → room**.
   QR scanning and phase advancement use explicitly labelled prototype controls
   outside the phone. No actual camera, timer, invite or completion service runs.
5. Use **UI design plan** for components, palette, implementation order and the
   decisions to review. Brand colors are optional; neutral mode emphasizes layout.

The editable master is the standalone HTML. All form data stays in memory and
resets on refresh. Use sample credentials only. Browser Back is not the simulated
Android Back control. The wireframe does not modify the Flutter application.

For the newer room visual direction, open the [classroom mockup](room-classroom.html).
It complements this overall flow with six illustrated desks, nine room states and
host/member controls. Use the external state selector to inspect samples; desk
taps only select locally. The focus timer is frozen and no reservation is made.
The Flutter scene now uses this classroom layout; review artwork, desk size and
scrolling on a phone. Its callbacks and preview interactions remain unchanged;
the HTML's connection/host/focus scenarios are still design references only.

## Main navigation and screen placement

- Home: return to joined communities, room shortcuts and progress. A new user sees
  a Discover action, not a page of empty statistics.
- Discover: search and browse new communities; SIG/subgroup/room pages belong to
  this branch. Use stable IDs for actual routes, not whole database snapshots.
- Progress: normal totals/history and a separate, clearly labelled demo view.
- Profile: name, preset avatar, interests, editing and sign-out.
- Authentication, scanner, focus/break and summary are focused surfaces outside
  the bottom tabs. Hide tabs during an active session; leaving needs confirmation.
- Goal and invitation are intended as sheets over the room. The wireframe displays
  each sheet's content as an isolated phone surface so its layout is easy to review.
- SIG ownership and room hosting are separate permissions; the inspector has
  separate controls for both. They must not be conflated in implementation.

## Inventory

| Surface | Route / placement | Owner | Current status | States to review |
|---|---|---|---|---|
| Startup gate | `Entry-point state` | Shanuka + Poojani | Planned behavior | Default, Error |
| Welcome | `/welcome` | Poojani | Planned screen | Default |
| Sign in | `/login` | Poojani; Shanuka routing | Planned screen | Default, Loading, Error |
| Create account | `/signup` | Poojani | Planned screen | Default, Loading, Error |
| Reset password | `/reset-password` | Poojani | Planned screen | Default, Error |
| Profile setup | `/setup` | Poojani | Planned screen | Default, Loading, Error |
| Home | `/home` | Shanuka UI; Poojani data | Placeholder exists; proposed layout | Default, Empty, Loading, Error |
| Discover | `/discover` | Poojani | Local Flutter preview exists | Default, Empty, Loading, Error |
| SIG detail | `/sigs/:sigId` | Poojani | Local Flutter preview exists | Default, Empty, Loading, Error |
| Create SIG | `/sigs/new` | Poojani | Planned form | Default, Error |
| Subgroup detail | `/subgroups/:subgroupId` | Poojani UI; Aradhana rooms | Local Flutter preview exists | Default, Empty, Loading, Error |
| Create subgroup | `/sigs/:sigId/subgroups/new` | Poojani | Planned owner-only form | Default, Error |
| Create room | `/subgroups/:subgroupId/rooms/new` | Shanuka UI + Aradhana behavior | Planned form | Default, Error |
| Room lobby | `/rooms/:roomId` | Shanuka UI + Aradhana services | Scene/local interactions exist | Default, Full, Seat conflict, Reconnecting |
| Personal goal | `Sheet over room` | Shanuka UI + Aradhana data | Local goal sheet exists | Default, Error |
| Focus | `/rooms/:roomId/session/:sessionId` | Shanuka UI + Aradhana engine | Planned screen | Default, Reconnecting |
| Break | `Same session route, break phase` | Shanuka UI + Aradhana engine | Planned screen | Default, Reconnecting |
| Session summary | `/sessions/:sessionId/summary` | Shanuka UI + Aradhana completion | Planned screen | Default, Saving, Error |
| Invite someone | `Sheet over room` | Sandali UI + Aradhana service | Planned sheet | Default, Loading, Error |
| Scan / enter code | `/scan` | Sandali | Planned screen | Default, Permission denied, Invalid code |
| Invitation preview | `/invite/:token` | Sandali UI; Aradhana admission | Planned screen | Default, Full, Expired, Error |
| Progress | `/progress` | Sandali | Placeholder exists; proposed layout | Default, Empty, Loading, Error |
| Profile | `/profile` | Poojani | Placeholder exists; proposed layout | Default, Error |

## Screen behavior handoffs

- **Account:** Poojani provides explicit identity/profile states. Shanuka handles
  loading, signed-out, incomplete-profile and ready routing, preserves pending
  invitation intent through login and revalidates the invitation afterward.
- **Community:** Poojani extends existing consumers. Parent membership is required
  for subgroup membership; room creation is member-only and subgroup creation is
  owner-only. Leaving with an active room/session needs a coordinated policy.
- **Room:** reuse RoomScene. Seats need available/occupied/pending/yours/conflict
  feedback and an accessible label/action. Only a real admission result can mark
  a user's seat reserved. The HTML selection is purely simulated.
- **Session:** Aradhana supplies shared timestamps and participation state; Shanuka
  renders focus/break/summary. No global pause. Late join, disconnect and host
  departure do not create a new local schedule. Exact eligibility is a service rule.
- **Summary:** preserve goal outcome independently of timer completion. Saving and
  retry use a stable completion identity; never create another completion on retry.
- **Invitation:** Sandali owns camera/manual UI; Aradhana owns resolution/admission.
  Preview before joining, ask consent for memberships, then revalidate capacity.
- **Progress:** Sandali reads private records; demo records cannot inflate normal
  totals. Do not label a bounded history-page sum as an all-time total.

## Decisions to confirm before detailed UI

- Approve distinct Home/Discover purposes and the four main navigation tabs.
- Approve room action hierarchy: seat → personal goal → host Start; Invite is a
  secondary action. Members see waiting-for-host status, not a host Start button.
- Approve separate demo-history visibility and invitation consent wording.
- Confirm the proposed 60-second demo split (45s focus + 15s break); retain the
  25m + 5m normal cycle. The split is not yet a backend contract.
- Confirm which empty/error/reconnect states are included in each first feature PR.

Optional chart, milestone decorations, resource links and extra onboarding pages
are deliberately excluded. No chat, voice/video, notifications bell or unimplemented
settings switches are proposed.

## Verification and limits

The HTML script passes syntax validation. All 23 surfaces and 65 screen-state
combinations rendered in a DOM-stub check. Script-level checks passed for account /
community / seat / goal / session / history transitions, invitation login/consent,
independent owner/host controls, invalid code handling and offline resource use.
A connected browser surface was unavailable, so actual browser layout, keyboard
interaction and responsive visual review are still pending. These checks do not
validate Flutter, Firebase, real camera use, browser native validation or services.
