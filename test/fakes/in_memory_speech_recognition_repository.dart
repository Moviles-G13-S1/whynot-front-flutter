import 'package:whynot_mobile/features/speech/domain/speech_recognition_repository.dart';

class InMemorySpeechRecognitionRepository
    implements SpeechRecognitionRepository {
  InMemorySpeechRecognitionRepository({
    this.available = true,
    this.result = 'Test product',
    this.error,
  });

  bool available;
  String result;
  Object? error;

  int recognitionCalls = 0;
  bool cancelled = false;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<String> recognize() async {
    recognitionCalls += 1;

    if (!available) {
      throw const SpeechRecognitionException(
        'Voice input is not available on this device.',
      );
    }

    final configuredError = error;

    if (configuredError != null) {
      throw configuredError;
    }

    return result;
  }

  @override
  Future<void> cancel() async {
    cancelled = true;
  }
}