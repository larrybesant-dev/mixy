import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

Future<void> prepareAppCheckTokenForWrite({
  String operation = 'firestore_write',
}) async {
  if (!kIsWeb) {
    return;
  }

  try {
    final token = await FirebaseAppCheck.instance.getToken(false);
    if (token == null || token.isEmpty) {
      debugPrint(
        '[Firebase] App Check token preflight empty for $operation (non-fatal).',
      );
    }
    return;
  } catch (error) {
    final lower = error.toString().toLowerCase();
    final retryable =
        lower.contains('appcheck')
        || lower.contains('recaptcha')
        || lower.contains('captcha')
        || lower.contains('503');

    if (!retryable) {
      debugPrint(
        '[Firebase] App Check token preflight failed for $operation (non-retryable, non-fatal): $error',
      );
      return;
    }

    try {
      await Future.delayed(const Duration(milliseconds: 350));
      await FirebaseAppCheck.instance.getToken(true);
    } catch (retryError) {
      debugPrint(
        '[Firebase] App Check token retry failed for $operation (non-fatal): $retryError',
      );
    }
  }
}

Future<void> prepareAppCheckTokenForRead({
  String operation = 'firestore_read',
}) async {
  if (!kIsWeb) {
    return;
  }

  try {
    final token = await FirebaseAppCheck.instance.getToken(false);
    if (token == null || token.isEmpty) {
      debugPrint(
        '[Firebase] App Check token preflight empty for $operation (non-fatal).',
      );
    }
    return;
  } catch (error) {
    final lower = error.toString().toLowerCase();
    final retryable =
        lower.contains('appcheck') ||
        lower.contains('recaptcha') ||
        lower.contains('captcha') ||
        lower.contains('503');

    if (!retryable) {
      debugPrint(
        '[Firebase] App Check token preflight failed for $operation (non-retryable, non-fatal): $error',
      );
      return;
    }

    try {
      await Future.delayed(const Duration(milliseconds: 350));
      await FirebaseAppCheck.instance.getToken(true);
    } catch (retryError) {
      debugPrint(
        '[Firebase] App Check token retry failed for $operation (non-fatal): $retryError',
      );
    }
  }
}
