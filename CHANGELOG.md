# Changelog

## 1.0.4+9 - 2026-11-03

### Added
- Creator memberships with Stripe Connect onboarding, configurable monthly
  offers, subscriber analytics, subscriber-only updates, reporting, and
  cancellation-at-period-end.
- Speed Dating preferences, location-aware discovery, and queue hardening.
- Desktop Messenger windows, buddy list, status controls, Buzz messages, room
  invitations, and profile photo viewing.
- Configurable live-room camera layouts, viewer-local tile sizing and focus,
  draggable floating camera windows, room artwork backgrounds, and local
  room-audio muting.
- Local Firebase emulator Playwright coverage for authentication, room
  creation, and real-time direct messaging.

### Changed
- Updated compact navigation to Home, Messages, Rooms, Dating, and Profile,
  while preserving desktop Settings and beta feedback destinations.
- Improved canonical profile identity and avatar fallback behavior throughout
  rooms, messaging, stories, and dating.
- Hardened WebRTC signaling, sender bitrate adaptation, media permissions, and
  route-scoped stream lifecycle behavior.
- Refreshed live-room and discovery counts using recent participant
  heartbeats.

### Fixed
- Restored Google sign-in on web and stabilized profile completion and uploads.
- Prevented stale scheduled E2E runs from republishing an older production
  Hosting build.
- Pinned core Playwright jobs to Ubuntu 24.04 for reliable WebKit execution.
- Improved Flutter web startup, cache revalidation, and production deployment
  revision validation.

### Release notes
- Version metadata advances from `1.0.3+8` to `1.0.4+9`.
- Creator payouts remain gated by the existing beta feature flags.
