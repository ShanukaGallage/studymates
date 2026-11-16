# Tomorrow's five-minute Android demo

If taking a desk reports already seated, use the room's reserved-seat recovery
panel. Open the prior room or explicitly release the reserved desk. If an unfinished
session is shown, Return to unfinished session → End and save participation first,
then release its desk. Finishing a timer or navigating to another room does not
automatically release a reservation. The one-seat-per-account rule stays enforced.

Normal room cycles default to 25-minute focus + 5-minute break. For the short live
rehearsal, the host must deliberately enable **60-second demo cycle** before starting
a new cycle. The room shows the shared current countdown, normal cycles done and
separate demo cycles done. Existing cycles keep their original duration. After a
cycle ends, save participation before joining the next host-started cycle.

Use account mode (`lib/main.dart`) for connected features. `main_preview.dart`
remains a separate, labelled in-memory UI preview. Local backend mode is also
explicitly labelled and uses Firebase emulators, never production accounts/data.

## Local backend rehearsal

```bash
npm exec --yes --package firebase-tools -- firebase emulators:start \
  --only auth,firestore --project studymates-dev --config firebase.emulators.json
adb reverse tcp:8080 tcp:8080
adb reverse tcp:9099 tcp:9099
flutter run -t lib/main.dart --dart-define=STUDYMATES_EMULATOR_HOST=127.0.0.1
```

Run the commands with both USB devices selected using `adb -s DEVICE_ID reverse`
and `flutter run -d DEVICE_ID`. The same emulator project gives both phones one
shared backend. Emulator data is temporary unless explicitly exported/imported.
Do not confuse this with a production Firebase deployment.

## Automated backend checks

With emulators running:

```bash
node test/firestore_membership_rules_test.mjs
node test/firestore_study_rules_test.mjs
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node test/membership_cleanup_emulator_test.cjs
flutter test integration_test/connected_study_test.dart -d DEVICE_ID \
  --dart-define=STUDYMATES_EMULATOR_HOST=127.0.0.1
```

The Android integration test creates two independent test identities only in the
emulators and uses real Firebase SDK transactions. It must never target production.

## Hosted Firebase on Spark (no billing upgrade)

The connected app performs room/session operations and membership self-cleanup
with Firestore transactions and rules. Cloud Functions are optional and must not
be included in Spark deployment. Use the existing `studymates-dev` project.

```bash
npm exec --yes --package firebase-tools -- firebase login
npm exec --yes --package firebase-tools -- firebase deploy \
  --project studymates-dev --only firestore:rules,firestore:indexes
flutter run -t lib/main.dart
```

Leave SIG/subgroup ends the current user's related session as goal unfinished,
releases their seat, transfers hosting to the oldest eligible occupant (or closes empty hosted rooms), acknowledges their own
pending request and finalizes membership removal. It never edits another user's
seat or goal. Other participants can save their own participation and release
their seats; a closed room cannot start/admit another session. SIG ownership still
transfers or the SIG closes according to M2's existing protocol. Room host handover runs through the ordered seating queue on Spark.

For a request that timed out in the old version, deploy the updated rules and
open Discover → Pending leave requests. Interrupted cleanup is retryable.
If a seat/session in another community is still active, finish/release it first.

## Five-minute sequence

1. Use two accounts. Host creates a community and subgroup; both join.
2. Host creates a room; both open it and claim different seats. Both phones must
   show the same occupancy. A second claim on an occupied seat must fail safely.
3. Set personal goals. Host starts the labelled 45s focus / 15s break demo;
   guest joins the same schedule. Explain that late joins do not receive earlier time.
4. Return Home, then Return to session. It checks membership, room, session and
   the same unexpired seat lease without starting or claiming again.
5. End/save each participation. Open Progress → Demo history; refresh/reopen must
   not duplicate the completion. Normal totals and annual heatmap exclude demos.
6. If time permits, show host invitation QR and scan/manual entry on the other
   phone. Invite preview requires explicit admission and fresh membership/capacity
   checks. Finish/release an existing seat before joining another room.

## Scope and credit policy

The foreground app renews its single seat lease every 30 seconds. Claims have an
approximately two-minute lease (rules cap client timestamps at server time +125s;
large device-clock drift fails safely). No hidden client success replaces a server
result. Reconnection never automatically reclaims an expired seat.

Credit is conservative elapsed focus time from the server-recorded participation
join to focus end or save time, reduced by one second for clock/rounding tolerance,
and bounded again by rules. The same unexpired claim must still be valid when
saving; lost/expired/reassigned leases receive zero credit. This is a participation
measure, not attention detection. Background intervals within a still-valid lease
are not independently measured. Goal completion is a separate user-reported outcome.

Sessions and participant goals survive app restart. Shared schedules are immutable;
only the host starts a new cycle after the old one ends. Phase boundaries are
derived from the single persisted server start; client wall clocks never write
focus/break endpoints. Completion document IDs
are the session ID within the current user's private collection. Retrying a save
returns the existing record. Rejoining an already finalized cycle is blocked.

History summary currently reads the user's complete completion collection; pages
are bounded to 30 records. This is adequate for the small assignment dataset;
large-scale aggregates/indexes remain future work. The annual heatmap explicitly
marks partial pages. Room/seat display names and minimal claim locators are visible
to signed-in learners; private profiles, goals and completion histories stay scoped
to the authenticated owner. No public goals or whole profile documents are exposed.

## Local cleanup rehearsal

If Functions are not deployed, membership leave requests remain pending until
the trusted worker runs. Keep leave out of the demo, or run the following local
worker against emulators only after each request:

```bash
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node functions/run-local-cleanup.js
```

This is an explicit local administrative helper, not a client-side authorization
bypass. Do not set it to a production endpoint.

## Verified checkpoint

16 November: analysis clean; 262 Flutter tests passed; real-SDK Android integration
passed on 23129RAA4G / Android 15 against Auth/Firestore emulators with two separate
identities. Membership and room/session rule suites passed. Trusted cleanup test
passed including host transfer and repeated execution. A full manual walkthrough
on two physical phones and production deployment remain pending.

## Starting hosted Firebase after reconciliation

Use the existing `studymates-dev` project. Authenticate in your own terminal:

```bash
npm exec --yes --package firebase-tools -- firebase login
npm exec --yes --package firebase-tools -- firebase projects:list
```

Confirm Email/Password Authentication and the default Firestore database in the
console. Deploy the rules/indexes only with the command above.
Cloud Functions requires Blaze and is optional; keep Spark and deploy Firestore only.
Do not run `firebase init` over this existing configuration. Run `lib/main.dart`
without the emulator define after successful deployment. Local emulator test users
are separate from hosted Firebase users.

## Capacity/private-room check

Create a 40-desk public room and confirm the last desk is reachable. Create a
two-desk private room. The second member should see a lock label and invitation
prompt when opening its tile or direct route. A wrong/expired/revoked/other-room
code must fail; a host-issued code grants room access and the atomic seating operation confirms
one seat before returning admitted. Both
phones then see the same two desks. All membership requirements still apply.
Previously admitted users can return without retyping the invitation. Redeploy
Firestore rules for this update; no new Function or billing plan is needed.

## Host handover and revoked-code rehearsal

Deploy the new Firestore rules and install the same updated APK on both phones.
For an existing room, first open it with its current host to initialize the queue.
Have A host and claim a desk, then B sit, then C if available. Releasing A's desk
passes hosting to B; releasing B's passes it to C. Rejoining places A last. The
shared cycle continues unchanged. For a power-off/logout test, allow the old host's
lease to expire (~2 minutes) and another foreground client's next 30-second check.
A new room gives an unseated creator 125 seconds of setup grace. No app open means
no client reconciliation until a seated learner returns; there is no paid scheduler.

Open **Manage invitations**, issue/share a code, then revoke it. A previously
opened preview must fail admission after revocation. Confirm existing learners
keep their seats/access. A successor host must also be able to revoke an earlier
host's code. New codes and revocations require confirmed backend success.
