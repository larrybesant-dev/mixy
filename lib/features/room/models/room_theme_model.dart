import 'package:mixvy/core/utils/network_image_url.dart';

/// Vibe preset keys. Used to drive animated/gradient backgrounds when no
/// custom image URL is set. New presets can be added without schema changes.
enum RoomVibePreset { none, club, lounge, neon, hype, space, ocean }

/// Per-room visual theme stored under `rooms/{roomId}.theme` in Firestore.
///
/// All fields are optional – a room with no theme document uses the app's
/// default dark background. Only the host or co-hosts may write this field
/// (enforced via [RoomPermissions.canEditRoomTheme] and Firestore rules).
class RoomTheme {
  /// Remote image / video / lottie URL used as the room background.
  /// Null → fall back to [vibePreset] or default dark surface.
  final String? backgroundUrl;

  /// Hex accent colour string (e.g. `"#D4A853"`). Null → brand gold default.
  final String? accentColor;

  /// Optional named preset that drives animated backgrounds.
  final RoomVibePreset vibePreset;

  const RoomTheme({
    this.backgroundUrl,
    this.accentColor,
    this.vibePreset = RoomVibePreset.none,
  });

  /// Sentinel that represents "no theme / reset to default".
  static const RoomTheme defaultTheme = RoomTheme();

  bool get hasBackground => backgroundUrl != null && backgroundUrl!.isNotEmpty;
  bool get hasAccent => accentColor != null && accentColor!.isNotEmpty;
  bool get isDefault =>
      !hasBackground && !hasAccent && vibePreset == RoomVibePreset.none;

  factory RoomTheme.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const RoomTheme();
    }
    final rawUrl = json['backgroundUrl'] is String
        ? json['backgroundUrl'] as String
        : null;
    final sanitizedUrl = sanitizeNetworkImageUrl(rawUrl);
    final rawPreset = json['vibePreset'] is String
        ? json['vibePreset'] as String
        : null;
    return RoomTheme(
      backgroundUrl: sanitizedUrl,
      accentColor: json['accentColor'] is String
          ? json['accentColor'] as String
          : null,
      vibePreset: _parseVibePreset(rawPreset),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'backgroundUrl': backgroundUrl,
      'accentColor': accentColor,
      'vibePreset': vibePreset.name,
    };
  }

  RoomTheme copyWith({
    String? backgroundUrl,
    String? accentColor,
    RoomVibePreset? vibePreset,
  }) {
    return RoomTheme(
      backgroundUrl: backgroundUrl ?? this.backgroundUrl,
      accentColor: accentColor ?? this.accentColor,
      vibePreset: vibePreset ?? this.vibePreset,
    );
  }

  static RoomVibePreset _parseVibePreset(String? raw) {
    if (raw == null) return RoomVibePreset.none;
    return RoomVibePreset.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => RoomVibePreset.none,
    );
  }
}




