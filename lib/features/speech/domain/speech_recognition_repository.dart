abstract interface class SpeechRecognitionRepository {
  /// Returns whether speech recognition can be used on this device.
  ///
  /// On iOS this also initializes the native speech recognition service and
  /// triggers the system permission flow when required.
  Future<bool> isAvailable();

  /// Listens once and returns the final recognized phrase.
  ///
  /// WhyNot uses this for short product fields such as name and brand rather
  /// than continuous dictation.
  Future<String> recognize();

  /// Cancels the current recognition session, if one exists.
  Future<void> cancel();
}

class SpeechRecognitionException implements Exception {
  const SpeechRecognitionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SpeechRecognitionCancelledException
    extends SpeechRecognitionException {
  const SpeechRecognitionCancelledException()
    : super('Voice input was cancelled.');
}