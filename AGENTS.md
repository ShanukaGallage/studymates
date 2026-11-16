# StudyMates project guidance

- Read README.md, docs/contracts.md, docs/team/00-common-plan.md and the working
  member's individual guide in docs/team. The four-member plan supersedes old
  five-member assignments; the original StudyMates guides are design background.
  Current deliverable: five-minute live Android demo, no report/slides/rubric.
- Ownership: Shanuka coordinates shared UI/routes/integration; Poojani owns
  accounts/communities/Firebase; Aradhana owns live rooms/sessions/invite services;
  Sandali owns invitation UI/scanning and read-only history. Follow the common
  plan's file boundaries. Reserve shared-file changes; avoid concurrent edits.
- Extend this project; preserve unrelated uncommitted work and existing folders.
- Flutter 3.50.0 / Dart 3.14.0; keep the lockfile and avoid unnecessary upgrades.
- Use Riverpod and go_router; do not introduce competing state/router systems.
- Use `package:material_ui/material_ui.dart` for Material widgets, the shared
  light theme/spacing tokens, and controls in lib/core/widgets.
- Keep 48px minimum controls, safe areas, scrollable forms, keyboard handling,
  system text scaling and accessible labels. Check actual foreground/background
  contrast; do not communicate status only with color.
- App configuration/routes live in lib/app; development gallery/fixtures belong
  in lib/preview. Four tabs: Home, Discover, Progress, Profile.
- Keep preview explicitly labelled. Normal mode initializes Firebase for accounts
  and profiles; app access uses authenticated UID plus the matching Firestore profile.
  Study features there remain unconnected. Never substitute fixtures on backend failure.
- Keep feature presentation separate from data repositories. Shared domain models
  belong in lib/core/models only when needed by consumers. Agree contracts with
  M2/M3 before implementation; do not add speculative empty classes.
- Future room admission must enforce membership, atomic seating and one active
  seat per user. Use shared session timestamps and unique completion records;
  exclude demo sessions from normal progress. No database operations in widgets.
- The current preview implements community discovery/local membership, a six-seat
  room presentation and local goals. Selection is never a server reservation.
  Auth/profile screens are integrated in account mode. Progress fixtures and QR/manual
  capture are integrated in preview only. Live room/session services, invitation
  admission, community persistence and history persistence remain later work.
  No chat, AI, voice/video or game engine expansion.
- Run formatting, analysis and relevant independent tests; report unavailable
  Android runtime checks honestly. Never commit secrets or weaken access rules.
