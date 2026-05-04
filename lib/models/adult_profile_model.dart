enum AdultRelationshipIntent { love, fun, hookups, openConnection }

enum AdultProfileVisibility { optedInAdultsOnly, privateOnly }

String _asString(dynamic value, {String fallback = ''}) {
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return fallback;
}

bool _asBool(dynamic value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') {
      return true;
    }
    if (normalized == 'false' || normalized == '0') {
      return false;
    }
  }
  return fallback;
}

DateTime? _parseNullableDateTime(dynamic value) {
  if (value == null) {
    return null;
  }
  return DateTime.tryParse(value.toString());
}

List<String> _asStringList(dynamic value) {
  if (value is List) {
    return value
        .map(
          (item) =>
              item is String ? item.trim() : item?.toString().trim() ?? '',
        )
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  return const <String>[];
}

class AdultProfileModel {
  const AdultProfileModel({
    required this.userId,
    this.enabled = false,
    this.adultConsentAccepted = false,
    this.visibility = AdultProfileVisibility.optedInAdultsOnly,
    this.kinks = const [],
    this.preferences = const [],
    this.boundaries = const [],
    this.lookingFor = const [],
    this.updatedAt,
  });

  final String userId;
  final bool enabled;
  final bool adultConsentAccepted;
  final AdultProfileVisibility visibility;
  final List<String> kinks;
  final List<String> preferences;
  final List<String> boundaries;
  final List<AdultRelationshipIntent> lookingFor;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'enabled': enabled,
      'adultConsentAccepted': adultConsentAccepted,
      'visibility': visibility.name,
      'kinks': kinks,
      'preferences': preferences,
      'boundaries': boundaries,
      'lookingFor': lookingFor.map((item) => item.name).toList(growable: false),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory AdultProfileModel.fromJson(Map<String, dynamic> json) {
    final visibilityRaw = _asString(json['visibility']);
    return AdultProfileModel(
      userId: _asString(json['userId']),
      enabled: _asBool(json['enabled']),
      adultConsentAccepted: _asBool(json['adultConsentAccepted']),
      visibility: AdultProfileVisibility.values.firstWhere(
        (value) => value.name == visibilityRaw,
        orElse: () => AdultProfileVisibility.optedInAdultsOnly,
      ),
      kinks: _asStringList(json['kinks']),
      preferences: _asStringList(json['preferences']),
      boundaries: _asStringList(json['boundaries']),
      lookingFor: _asStringList(json['lookingFor'])
          .map(
            (value) => AdultRelationshipIntent.values.firstWhere(
              (item) => item.name == value,
              orElse: () => AdultRelationshipIntent.fun,
            ),
          )
          .toList(growable: false),
      updatedAt: _parseNullableDateTime(json['updatedAt']),
    );
  }
}
