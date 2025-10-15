import 'package:flutter/material.dart';

/// Displays short messages at the top of the screen using MaterialBanner.
/// Auto-dismisses after [duration].
class TopToast {
  static void _show(
    BuildContext context,
    String message, {
    required IconData icon,
    Color? iconColor,
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 4),
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearMaterialBanners();
    messenger.showMaterialBanner(
      MaterialBanner(
        content: Text(message),
        leading: Icon(icon, color: iconColor),
        backgroundColor:
            backgroundColor ?? Theme.of(context).colorScheme.surface,
        actions: [
          TextButton(
            onPressed: () => messenger.hideCurrentMaterialBanner(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
    // Auto-dismiss after [duration].
    Future.delayed(duration, () {
      // Ignore if already hidden
      try {
        messenger.hideCurrentMaterialBanner();
      } catch (_) {}
    });
  }

  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    _show(
      context,
      message,
      icon: Icons.info_outline,
      iconColor: Colors.blueGrey,
      backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(.98),
      duration: duration,
    );
  }

  static void success(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    _show(
      context,
      message,
      icon: Icons.check_circle,
      iconColor: Colors.green,
      backgroundColor: Colors.green.withOpacity(.08),
      duration: duration,
    );
  }

  static void error(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 5),
  }) {
    _show(
      context,
      message,
      icon: Icons.error_outline,
      iconColor: Colors.red,
      backgroundColor: Colors.red.withOpacity(.08),
      duration: duration,
    );
  }
}
