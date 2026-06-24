/// Feature flags for Mix & Mingle MVP
/// Use these to enable/disable features during development and deployment
class FeatureFlags {
  // Core MVP features (always enabled)
  static const bool auth = true;
  static const bool profiles = true;
  static const bool rooms = true;
  static const bool chat = true;

  // Advanced features (disabled for MVP)
  static const bool speedDating = true; // Too complex for MVP
  static const bool events = true; // Events are part of social features
  static const bool tipping = true; // Monetization feature - ENABLED
  static const bool liveStreaming = true; // Core video chat functionality

  // Beta features (can enable for testing)
  static const bool notifications = true; // Push notifications
  static const bool videoCalls = true; // Core video functionality
  static const bool messaging = true; // Core chat functionality

  // Admin features
  static const bool adminPanel = false;
  static const bool analytics = false;

  // Development features
  static const bool debugMode = true;
  static const bool testMode = false;
}
