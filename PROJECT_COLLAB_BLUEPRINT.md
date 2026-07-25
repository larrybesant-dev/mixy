# PROJECT COLLAB BLUEPRINT

This file is the single collaboration source of truth for feature intent, UI direction, workflow behavior, and acceptance checks.

Use this file whenever we:
- Add or modify product features
- Implement or adjust UI layouts/styles
- Change room participation or mic workflows
- Validate requirements before merging

## 1) Product Direction

Primary product: MIXVY (Velvet Noir)

Design system baseline:
- Surface: Jet Black (#0B0B0B)
- Primary: Gold (#D4AF37)
- Secondary: Deep Wine Red (#781E2B)
- Text on dark: Soft Cream (#F7EDE2)
- Live glow: #9B2535
- Typography: Playfair Display (headline), Raleway (body/UI)

## 2) Yahoo Messenger-Style Friends Panel Requirements

Goal:
- Deliver a nostalgia-forward social panel with modern responsiveness.

Must-have structure:
- Left panel with collapsible groups (Online, Away, Offline, Favorites)
- Presence indicators per friend (status dot + text)
- Quick actions per friend (message, invite to room, view profile)
- Search/filter at top of panel
- Context menu support for friend actions

Interaction requirements:
- Keyboard accessible navigation through friend rows
- Mobile behavior: panel converts to slide-over drawer
- Preserve selected friend/context when panel is collapsed and re-opened

Visual direction:
- Distinct buddy-list visual language (not generic cards)
- Gold-accented actionable controls
- Wine red used for attention states and live room invitations

## 3) Room Mic Workflow Requirements

Backend behavior requirements:
- grabMic must support member-only fallback when participant doc is missing
- Banned users must be denied mic access
- Participant self-heal must backfill participant data from member data when required

Client behavior requirements:
- Mic errors must map to actionable user messages
- Permission-denied, unauthenticated, and rate-limited states must be distinct
- Logs should include enough context to correlate client attempts with backend outcomes

Session repair requirements:
- Heartbeat flow should recover missing participant docs from member docs
- Recovered participant role should derive from member role mapping

## 4) Change Request Format (Use This Every Time)

For each requested update, capture:
1. Scope: feature, file/module, and user-visible impact
2. UX intent: what the user should feel/see/do
3. Data behavior: reads/writes, side effects, failure handling
4. Acceptance checks: exact pass/fail criteria
5. Regression coverage: tests to add or update

## 5) Current Verified Hardening Baseline

Verified commit:
- 2ee28df3

Included files:
- functions/index.js
- functions/test/payments.spec.js
- lib/features/room/repository/room_repository.dart
- lib/features/room/services/room_session_service.dart

Validated by:
- node --test test/payments.spec.js --test-name-pattern grabMicHandler
- Expected result: 2 passed, 0 failed

## 6) Working Agreement

Before implementation:
- Check this file and align scope to sections 2-4.

During implementation:
- Keep changes minimal and traceable.
- Add or update tests for behavior changes.

After implementation:
- Report changed files, validation commands, and outcomes.
- Note any environment-only failures separately from code regressions.

## 7) Linked References

Related docs:
- BETA_BEHAVIORAL_BLUEPRINT.md
- lib/stitch_ui/mixvy_product_specification.md
- docs/ROOM_HEALTH_MONITOR_SPEC.md

If conflicts exist between documents, this file governs collaboration decisions unless explicitly overridden in writing.
