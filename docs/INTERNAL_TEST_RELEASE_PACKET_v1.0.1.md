# Internal Test Release Packet

## Release Metadata
- Timestamp: 2026-07-27
- Commit: 94647ff5fa30ea789f577f1c5d07a5234409a832
- App version: 1.0.1+2
- Pull request: https://github.com/larrybesant-dev/mixy/pull/11
- Merge state: merged into `develop`

## Android Release Artifacts
- APK: `build/app/outputs/flutter-apk/app-release.apk` (264,031,355 bytes)
- AAB: `build/app/outputs/bundle/release/app-release.aab` (165,870,317 bytes)

## Validation Summary
- `flutter analyze`: completed with non-blocking info/lint output only
- Focused post-merge tests passed:
  - `test/profile_controller_test.dart`
  - `test/edit_profile_screen_test.dart`
  - `test/production_stage_stress_test.dart`
- Release APK built and signature verification passed
- Release AAB generated for Play Console internal testing

## What Changed
- hardens room join/session behavior, roster alias handling, camera density, and chat metadata presentation
- replaces the lightweight profile completion dialog with a fuller completion form
- aligns profile completion and persistence behavior with schema rules
- adds platform-safe feed cache adapters for web and non-web builds
- stabilizes widget/unit tests around auth bootstrap, timers, and layout-sensitive UI
- fixes Android release configuration for signing, ProGuard, and Play feature-delivery dependencies

## Play Console Release Notes
### Short Version
1.0.1 improves room stability, profile completion, and Android release reliability.

### Detailed Version
- improved room join, reconnect, and session stability
- improved participant metadata visibility and roster clarity
- upgraded profile completion flow and schema-aligned profile persistence
- fixed Android release packaging and signing path for internal testing
- stabilized key widget and unit test coverage around profile and room flows

## Tester Message
Hey — I am starting internal testing for the current MixVy Android build and want a small trusted group to use it naturally.

What changed in this build:
- room stability and join/rejoin behavior were hardened
- profile completion flow was upgraded
- Android release packaging was finalized for testing

What I need from you:
- join rooms normally
- leave and rejoin at least once
- use chat and mic controls naturally
- tell me immediately if anything feels confusing, delayed, duplicated, missing, or untrustworthy

I am not only looking for crashes.
I want to know whether the app feels clear, stable, and trustworthy in normal use.

## Recommended Rollout
- Start with internal testing now
- Use a 2 to 7 day soak window before production promotion
- Stop rollout immediately if users report confusing room ownership, duplicates, broken chat, or unstable reconnect behavior

## Release-Date Recommendation
- Internal test release date: 2026-07-27
- Suggested earliest production release date: 2026-07-29
- Safer production release date: 2026-08-03