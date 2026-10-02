import 'package:flutter/foundation.dart';

import '../domain/speech_recognition_repository.dart';
import '../domain/speech_state.dart';

/// Coordinates the one-shot voice-input flow used by product forms.
///
/// Presentation
/// → SpeechController
/// → SpeechRecognitionRepository
/// → Device speech recognition
class SpeechController extends ChangeNotifier {
  SpeechController({
    required SpeechRecognitionRepository speechRecognitionRepository,
  }) : _speechRecognitionRepository = speechRecognitionRepository;

  final SpeechRecognitionRepository _speechRecognitionRepository;

  SpeechState _state = const SpeechIdle();

  SpeechState get state => _state;

  bool get isListening => _state is SpeechListening;

  Future<void> startListening() async {
    if (isListening) {
      return;
    }

    _setState(const SpeechListening());

    try {
      final text = await _speechRecognitionRepository.recognize();

      _setState(SpeechResult(text));
    } on SpeechRecognitionCancelledException {
      _setState(const SpeechIdle());
    } on SpeechRecognitionException catch (error) {
      _setState(SpeechFailure(error.message));
    } catch (_) {
      _setState(
        const SpeechFailure(
          'Voice input failed. Try again.',
        ),
      );
    }
  }

  Future<void> cancelListening() async {
    await _speechRecognitionRepository.cancel();

    _setState(const SpeechIdle());
  }

  void reset() {
    _setState(const SpeechIdle());
  }

  void _setState(SpeechState newState) {
    _state = newState;
    notifyListeners();
  }
}