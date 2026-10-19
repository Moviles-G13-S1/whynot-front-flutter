import 'package:flutter/material.dart';

import '../../app/whynot_theme.dart';

/// Text treatment used as the application's wordmark.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text(
      'WHYNOT',
      style: TextStyle(
        fontFamily: 'Poppins',
        color: WhyNotColors.muted,
        fontSize: 16,
        letterSpacing: 4,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}
