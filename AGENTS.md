# Custom Instructions for Gemini Agent Mode

## Architecture Rules
- This project utilizes **Riverpod** for explicit state management. Do not inject mutable state variables inside stateless widgets.
- Always implement explicit interface contracts (abstract classes) under `lib/services/` before writing concrete implementations (e.g., `WebRTCRoomService implements RtcRoomService`).

## Coding Styles & Guards
- **Strict Null Safety:** Never force-unwrap (`!`) a Firestore document field unless it has been explicitly validated right before invocation. Use fallback constants or optional chaining (`?`).
- **Flutter Web Compliance:** Always check if values are finite (`isFinite`) before processing audio file dimensions or media durations to prevent web-specific runtime crashes.
- **Theme Consistency:** All `Color` instantiation blocks must use 8-digit ARGB hexadecimal integers (e.g., `Color(0xFF...)`). Do not use 6-digit variants.
