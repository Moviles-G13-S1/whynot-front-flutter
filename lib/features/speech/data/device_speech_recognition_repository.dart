import 'dart:async';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../domain/speech_recognition_repository.dart';

/// Device implementation of WhyNot's speech-recognition contract.
///
/// The plugin delegates recognition to the operating system:
/// - iOS uses Apple's speech recognition service.
/// - Android uses Android's speech recognition service.
/// - Web uses the browser implementation when available.
///
/// Audio is not persisted by WhyNot. The application only receives the
/// resulting transcription.
class DeviceSpeechRecognitionRepository
    implements SpeechRecognitionRepository {
  DeviceSpeechRecognitionRepository({SpeechToText? speechToText})
    : _speechToText = speechToText ?? SpeechToText();

  final SpeechToText _speechToText;

  bool _initialized = false;
  bool _available = false;

  Completer<String>? _activeResult;
  String _latestText = '';

  @override
  Future<bool> isAvailable() async {
    if (_initialized) {
      return _available;
    }

    _available = await _speechToText.initialize(
      onError: _handleError,
    );

    _initialized = true;

    return _available;
  }

  @override
  Future<String> recognize() async {
    if (_activeResult != null) {
      throw const SpeechRecognitionException(
        'Voice input is busy. Try again in a moment.',
      );
    }

    final available = await isAvailable();

    if (!available) {
      throw const SpeechRecognitionException(
        'Microphone and speech recognition permission are required to use voice input.',
      );
    }

    final completer = Completer<String>();

    _activeResult = completer;
    _latestText = '';

    try {
      await _speechToText.listen(
        onResult: _handleResult,
        listenOptions: SpeechListenOptions(
          partialResults: false,
          cancelOnError: true,
          listenFor: const Duration(seconds: 20),
          pauseFor: const Duration(seconds: 3),
        ),
      );

      return await completer.future.timeout(
        const Duration(seconds: 25),
        onTimeout: () async {
          await _speechToText.cancel();

          throw const SpeechRecognitionException(
            "Didn't catch that. Try again.",
          );
        },
      );
    } finally {
      if (identical(_activeResult, completer)) {
        _activeResult = null;
      }
    }
  }

  @override
  Future<void> cancel() async {
    final activeResult = _activeResult;

    await _speechToText.cancel();

    if (activeResult != null && !activeResult.isCompleted) {
      activeResult.completeError(
        const SpeechRecognitionCancelledException(),
      );
    }
  }

  void _handleResult(SpeechRecognitionResult result) {
    final activeResult = _activeResult;

    if (activeResult == null || activeResult.isCompleted) {
      return;
    }

    final text = result.recognizedWords.trim();

    if (text.isNotEmpty) {
      _latestText = text;
    }

    if (!result.finalResult) {
      return;
    }

    if (_latestText.isEmpty) {
      activeResult.completeError(
        const SpeechRecognitionException(
          "Didn't catch that. Try again.",
        ),
      );
      return;
    }

    activeResult.complete(_latestText);
  }

  void _handleError(SpeechRecognitionError error) {
    final activeResult = _activeResult;

    if (activeResult == null || activeResult.isCompleted) {
      return;
    }

    activeResult.completeError(
      SpeechRecognitionException(
        _messageForError(error.errorMsg),
      ),
    );
  }

  String _messageForError(String errorCode) {
    final normalized = errorCode.toLowerCase();

    if (normalized.contains('permission')) {
      return 'Microphone permission is required to use voice input.';
    }

    if (normalized.contains('no_match') ||
        normalized.contains('speech_timeout')) {
      return "Didn't catch that. Try again.";
    }

    if (normalized.contains('network')) {
      return 'Voice input needs an internet connection.';
    }

    if (normalized.contains('busy')) {
      return 'Voice input is busy. Try again in a moment.';
    }

    return 'Voice input failed. Try again.';
  }
}