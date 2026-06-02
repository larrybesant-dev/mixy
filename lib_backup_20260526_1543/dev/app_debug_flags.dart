import 'package:flutter/foundation.dart';

/// Central switch for UI-state diagnostics and visibility overlays.
///
/// Keep this tied to debug builds so observability never becomes
/// production behavior by accident.
const bool kEnableVisibilityDiagnostics = kDebugMode;
