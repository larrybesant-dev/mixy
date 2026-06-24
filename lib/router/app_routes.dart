/// lib/router/app_routes.dart
///
/// Single source of truth for all MixVy route constants.
/// Re-exports from the canonical location so both import paths resolve.
///
/// Usage:
///   import 'package:mixvy/router/app_routes.dart';
///   Navigator.pushNamed(context, AppRoutes.home);
///   Navigator.pushNamed(context, AppRoutes.room, arguments: roomId);
library;

export 'package:mixvy/core/routing/app_routes.dart' show AppRoutes;

