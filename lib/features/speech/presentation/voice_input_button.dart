import 'package:flutter/material.dart';

import '../../../app/whynot_theme.dart';

class VoiceInputButton extends StatelessWidget {
  const VoiceInputButton({
    required this.onPressed,
    required this.isListening,
    this.enabled = true,
    super.key,
  });

  final VoidCallback onPressed;
  final bool isListening;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: enabled && !isListening ? onPressed : null,
      tooltip: isListening ? 'Listening' : 'Voice input',
      iconSize: 21,
      visualDensity: VisualDensity.compact,
      icon: Icon(
        isListening ? Icons.mic : Icons.mic_none,
        color: isListening ? Colors.black : WhyNotColors.muted,
      ),
    );
  }
}