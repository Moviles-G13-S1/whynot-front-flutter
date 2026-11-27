import 'package:flutter/material.dart';

import '../../app/dependencies_scope.dart';

/// Offers local biometric unlock after successful login or registration.
/// A declined or failed opt-in never prevents normal account access.
Future<void> offerFaceId(BuildContext context) async {
  final dependencies = context.dependencies;
  final controller = dependencies.faceIdController;
  final userId = dependencies.authController.currentUser?.id;
  if (controller == null || userId == null || !controller.supportedPlatform) {
    return;
  }

  try {
    final enabled = await controller.isEnabled(userId);
    final available = await controller.isAvailable();
    if (!context.mounted || (!enabled && !available)) return;
    if (dependencies.authController.currentUser?.id != userId) return;

    final choice = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Face ID'),
        content: Text(
          enabled
              ? 'Keep Face ID enabled for this account?'
              : 'Use Face ID to unlock WhyNot next time you open the app?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(enabled ? 'Turn off' : 'Not now'),
          ),
          if (enabled || available)
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(enabled ? 'Keep enabled' : 'Enable Face ID'),
            ),
        ],
      ),
    );

    if (!context.mounted ||
        dependencies.authController.currentUser?.id != userId) {
      return;
    }
    if (choice == false && enabled) {
      await controller.disable(userId);
    } else if (choice == true && !enabled) {
      final activated = await controller.enable(userId);
      if (!activated && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Face ID was not enabled. You can try again next login.',
            ),
          ),
        );
      }
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update Face ID settings.')),
      );
    }
  }
}
