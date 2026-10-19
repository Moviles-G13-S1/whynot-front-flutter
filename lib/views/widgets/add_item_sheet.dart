import 'package:flutter/material.dart';

import '../../app/whynot_theme.dart';

/// Content shown when the user chooses Add in the bottom navigation.
class AddItemSheet extends StatelessWidget {
  const AddItemSheet({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add a new item', style: WhyNotTextStyles.serif(size: 26)),
            const SizedBox(height: 8),
            const Text(
              'Save something you love to one of your wishlists.',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: WhyNotColors.muted,
                fontSize: 14,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onContinue,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.black,
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
