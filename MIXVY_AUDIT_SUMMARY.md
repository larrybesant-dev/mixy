# MixVy Project Deep Audit & Onboarding Summary

## Project Structure & Features
- Modular Flutter app with features in `lib/features/` (auth, feed, home, room, payments, chat, events, onboarding, speed_dating, social, ads, etc.)
- Data models in `lib/models/` and `lib/data/models/` (user, room, transaction, presence, MessageModel, etc.)
- Business logic/services in `lib/services/` (auth, payments, analytics, agora, stripe, chat, moderation, notification, etc.)
- State management via Riverpod providers in `lib/presentation/providers/` and `lib/features/providers/`
- UI widgets in `lib/widgets/`
- Theming in `lib/theme/`
- Utilities in `lib/utils/`
- Config/constants in `lib/config/` (environment, payment, app constants)
- Tests in `test/` (mostly controller tests)

## Integrations
- Firebase (Auth, Firestore, Analytics)
- Agora (video/audio)
- Stripe (payments)
- Some legacy Supabase logic (should be removed)
- Lottie, Google Fonts, Image Picker, etc.

## Environment & Deployment
- `lib/config/environment.dart` for dev/prod switching
- `firebase.json` for Firebase hosting/emulator config
- `pubspec.yaml` for dependencies
- Hardcoded API keys (should be secured)

## Technical Debt & Issues
- Mixed Firebase/Supabase usage (standardize on Firebase)
- Duplicate models in multiple folders
- Empty/placeholder services
- Hardcoded secrets
- Only controller tests, limited test coverage
- Documentation could be improved (README, ONBOARDING)

## Recommendations
- Remove Supabase and unused code
- Consolidate models
- Secure API keys
- Expand tests and documentation
- Use providers for all Firestore access
- Clean up deprecated Flutter API usage

## HTML Login Page
- Modern, branded login page using Tailwind CSS and Google Fonts
- Email/password and social login UI (Google, Apple)
- Not yet wired to backend; needs integration with Firebase Auth or other backend
- Color palette and fonts match MixVy brand; should be reflected in Flutter theme

## Next Steps for Stitch AI
- Review this summary and the codebase
- Standardize backend, clean up code, secure secrets
- Expand test coverage and documentation
- Port HTML login to Flutter or connect to backend as needed

---
This file is ready for upload to Stitch AI or for onboarding any new developer.
