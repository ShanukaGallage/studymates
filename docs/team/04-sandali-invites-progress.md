# M4 — Sandali: QR invitations and personal progress

Read the [common plan](00-common-plan.md) first. You own two bounded features:
getting a second learner into the room through a camera/manual invitation, and
showing personal history. These were separate roles in the old five-member plan;
you now own both. Prioritize the real-phone camera spike, then basic history. Charts
and decorations are optional and should not compete with these core features.

## Your files and boundaries

Own `features/invites/presentation`, parser-specific invitation files agreed with
Aradhana, and `features/progress` including its read-only repository adapter.
Use separate invite/progress fixture and test files. Implement your own screens
using Shanuka's shared controls and state references.

Aradhana owns invitation token issuance/resolution/admission and completion writes.
Poojani owns identity, membership rules and Firestore rule/index coordination.
Shanuka owns routes, shared components, central preview bindings and dependencies.
Do not create a second room-join method, change the completion schema or award time.

## Step 1 — Run the identical baseline and reserve a camera spike

Your phone already runs the app. Confirm the exact new baseline commit, Android
version and that the latest room preview opens. Record these facts; do not reinstall
or regenerate a working project. Request a short scanner dependency/Android-config
slot from Shanuka after Poojani's Firebase package PR, or agree the reverse order.
Only one person edits `pubspec.yaml`, lockfile or manifest at a time.

```text
I am Sandali. Inspect the shared baseline and existing invite/progress folders.
Plan only an isolated Android camera scan spike. Identify the necessary scanner
and QR-rendering dependencies and Android requirements using their current official
documentation, checking the existing lockfile/toolchain. Do not change shared
package or Android config before our reserved slot. No authentication, routing,
room admission or session implementation is part of this task.
```

Done: a bounded dependency/config PR is merged and everyone pulls its lockfile.
The existing scanner candidates in the old guide are suggestions, not verified
versions. Keep package additions minimal and verify on the actual phone.

## Step 2 — Prove scanning on a real phone

Use a known test QR and an explicit callback. Before the production invitation
format is agreed, treat this as a standalone scanner spike, not a valid StudyMates
invitation. Pause/release the camera when the page is covered, backgrounded or left.

```text
Implement only the scanner screen using the agreed package. Request camera access
when scanning is opened, handle denied permission with retry/settings guidance,
and provide manual input fallback. Accept at most one result per interaction;
stop/pause scanning before handing a token to the callback, and dispose resources
on exit. Use a test callback; do not navigate globally or join a room directly.
Test parsing/debounce logic independently and give a real-phone permission,
background/resume and repeated-detection checklist.
```

Done: read a known QR once, cancel/reopen safely, deny and retry permission, and
return the result without repeated joins. An emulator/parser test does not prove
camera hardware. Tell Shanuka immediately if this spike is blocked; do not wait
until the final demonstration week.

## Step 3 — Build basic history from agreed fixtures

This can proceed while Aradhana finishes admission. Wait for the merged completion
model/contract, not the live history stream. Ask Aradhana for empty, single/multiple,
long-goal, completed/early-left and demo records. Do not invent another CompletionRecord.

```text
Implement only the read-only progress screen from the agreed CompletionRecord
fixtures and repository boundary. Show eligible recorded-time total, completed
session count and history, with loading/empty/error/retry states. Deduplicate by
the agreed stable record identity. Keep goal outcome independent of timer status;
an unfinished goal must not erase valid credited time. Exclude demo records from
normal totals and provide a clearly labelled demo-history view for the rehearsal.
Do not change finalization, auth, schema or global routing. No chart or rewards yet.
```

Done: totals match the exact unique fixture records; cancelled/early-left records
follow the agreed credit/count policy; demo records are visible separately and
cannot inflate normal totals. Give Shanuka the screen constructor/provider request.

## Step 4 — Invitation display, parsing and preview

Requires Aradhana's agreed versioned QR/manual-token format and lookup fixtures.
Build a room invitation display with manual code, parser and explicit preview.
The preview explains membership required/full/invalid/expired/revoked/unavailable.
Do not encode passwords, personal details or client authority into the QR payload.

```text
Implement only invitation display, the agreed payload parser and preview screens
against Aradhana's invitation contract/fixtures. QR and typed code must normalize
to the same opaque token. Reject malformed/unsupported payloads safely; never open
arbitrary scanned links automatically. Show the room and parent communities before
an explicit Join action. Membership enrollment needs clear consent. Use the shared
admission callback and handle a room becoming full after preview. Send route and
pending-login intent requirements to Shanuka; do not edit the router yourself.
```

Done: valid, invalid, expired/revoked, full and membership-required cases are
reviewable without Firebase. Preserve the token across login through Shanuka's
navigation integration, then revalidate. Manual entry and QR must not diverge into
two different join implementations.

## Step 5 — Connect real invitation and history services

Invite integration waits for Aradhana's merged resolver/admission and Poojani's
identity/membership behavior. History integration waits for Aradhana's finalization
records and Poojani's history read rules/indexes. Wire them as separate small PRs.

```text
Connect only [invitation flow OR history reader] to the merged service contract.
For invitations, use Aradhana's shared checked admission and keep explicit consent;
verify the avatar appears on both devices after actual success.
For history, implement a current-user-scoped read adapter over the agreed schema,
using a bounded recent query/pagination. Do not label a partial page sum as an
all-time total: agree a complete total source/query with Aradhana and Poojani.
Clear old account data on sign-out/account change and handle loading/error/retry.
Keep fixture previews available. Do not write completions or change shared schema.
```

Replace the bracketed choice and keep only its relevant paragraph. Done: QR on
phone A → scan/preview/Join on B → real room admission; and after a real session,
history persists across restart with correct totals and user isolation. If an
all-time aggregate is not ready, display an honestly labelled recent-period total
until the team supplies one; do not silently misrepresent it as total study time.

## Step 6 — Rehearse and close edge cases

```text
Review only the integrated invite/history feature against the common demo path.
Verify denied permission/retry, scanner background/resume, repeated recognition,
manual input, invalid/full/revoked invitations and network failures. Check history
restart, account switching, duplicate completions, long text and demo separation.
Fix reproducible defects within my feature paths and report cross-owner issues
with exact reproduction steps. Do not add charts, decorations or extra features.
```

Done: a repeatable phone checklist and screenshots of the final screens, plus a
short explanation you can give live: scanner → token → preview → shared admission;
completion records → private history → eligible totals. No slides/report required.

## Dependencies and conflict avoidance

| Waiting for | Needed for | Independent work |
|---|---|---|
| Shared dependency slot | Scanner package/manifest | Screen layout and token parser plan |
| Aradhana's invitation format | Final parser/display | Known-test-QR camera spike |
| Aradhana's completion model | History fields/totals | Scanner permission and lifecycle checks |
| Aradhana's real services | Live join/history data | Fixture/error screens and independent tests |
| Poojani's rules/indexes | Private history query | Fixture totals, account-change handling tests |
| Shanuka's route wiring | Product navigation | Screen/callback handoff and feature QA |

Tell teammates the precise method/field/route you need. Add `invites_*` and
`progress_*` tests instead of editing shared suites. If both features become too
large, finish camera + minimal history first; transfer one named presentation task
to Shanuka by agreement rather than allowing concurrent edits.
