import 'package:flutter/material.dart';

/// Centralized snackbar/toast helper.
class AppSnackbar {
  const AppSnackbar._();

  static void showError(BuildContext context, String message) {
    _show(context, message, Colors.red.shade600);
  }

  static void showSuccess(BuildContext context, String message) {
    _show(context, message, Colors.green.shade600);
  }

  static void _show(BuildContext context, String message, Color color) {
    if (message.isEmpty) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
