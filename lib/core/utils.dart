import 'dart:async';
import 'package:flutter/material.dart';

// Utility functions for Mix & Mingle
class AppUtils {
  // Format duration for display
  static String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  // Format viewer count
  static String formatViewerCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  // Validate email
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  // Validate username
  static bool isValidUsername(String username) {
    return username.length >= 3 &&
        username.length <= 20 &&
        RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username);
  }

  // Generate room code
  static String generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return String.fromCharCodes(
      Iterable.generate(
        6,
        (_) => chars.codeUnitAt(
          DateTime.now().millisecondsSinceEpoch % chars.length,
        ),
      ),
    );
  }

  // Show snackbar
  static void showSnackBar(BuildContext context, String message,
      {Color backgroundColor = Colors.red}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
      ),
    );
  }

  // Show "Coming Soon" snackbar
  static void showComingSoonSnackBar(BuildContext context) {
    showSnackBar(
      context,
      'Coming Soon! This feature is under development.',
      backgroundColor: const Color(0xFFFFD700),
    );
  }

  // Show loading dialog
  static void showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  // Hide loading dialog
  static void hideLoadingDialog(BuildContext context) {
    Navigator.of(context).pop();
  }

  // Debounce function
  static Function debounce(Function func, Duration delay) {
    Timer? timer;
    return () {
      if (timer != null) {
        timer!.cancel();
      }
      timer = Timer(delay, () {
        func();
      });
    };
  }
}

// Extension methods
extension StringExtensions on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }

  String truncate(int maxLength) {
    return length <= maxLength ? this : '${substring(0, maxLength)}...';
  }
}

extension DateTimeExtensions on DateTime {
  String toRelativeTime() {
    final now = DateTime.now();
    final difference = now.difference(this);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
