sealed class SpeechState {
  const SpeechState();
}

final class SpeechIdle extends SpeechState {
  const SpeechIdle();
}

final class SpeechListening extends SpeechState {
  const SpeechListening();
}

final class SpeechResult extends SpeechState {
  const SpeechResult(this.text);

  final String text;
}

final class SpeechFailure extends SpeechState {
  const SpeechFailure(this.message);

  final String message;
}