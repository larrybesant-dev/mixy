# Play Console Release Notes - v1.0.1+2

Date: 2026-07-27
Branch: develop
Commit: 2f4f01456811043f0bc3bbb14edeaa8c9d302cfc

## Short Notes (80-500 chars)
Improves room reliability, profile completion flow, and Android release stability. Includes join/rejoin hardening, clearer participant metadata, schema-aligned profile persistence, and packaging/signing fixes for safer rollout.

## Full Notes
- Improved room join, reconnect, and session stability.
- Improved participant metadata visibility and roster clarity.
- Upgraded profile completion flow and schema-aligned persistence behavior.
- Added platform-safe feed cache adapters for web and non-web builds.
- Stabilized key widget/unit tests around profile and room flows.
- Hardened Android release packaging, signing, and ProGuard/Play dependency setup.

## Internal Testing Focus
- Join a room, leave, and rejoin at least once.
- Validate chat and mic controls in normal usage.
- Report confusing states, delayed updates, duplicates, missing data, or trust issues.

## Artifact References
- APK: build/app/outputs/flutter-apk/app-release.apk
- AAB: build/app/outputs/bundle/release/app-release.aab

## Artifact SHA-256
- APK: 3B0742B313ED0BE610DD931513491B8913E640E7849950B2D167F8C84310E367
- AAB: 115C64375A3A1E3DC60F1DF7B4BEF4BB27148499543FAA2600A3D106E36FF65B
