import 'package:flutter/foundation.dart';
import '../controllers/application_error_reporter.dart';

/// Preserves existing error presentation and propagation. Returns a restore
/// callback for isolated tests; raw messages and stack traces are never sent.
VoidCallback installApplicationErrorHandlers(
  ApplicationErrorReporter reporter,
) {
  final previousFlutter = FlutterError.onError;
  final previousPlatform = PlatformDispatcher.instance.onError;
  FlutterError.onError = (details) {
    reporter.report(
      details.exception,
      feature: 'runtime',
      operation: 'unhandled',
      source: 'framework',
    );
    if (previousFlutter != null) {
      previousFlutter(details);
    } else {
      FlutterError.presentError(details);
    }
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    reporter.report(
      error,
      feature: 'runtime',
      operation: 'unhandled',
      source: 'platform',
    );
    return previousPlatform?.call(error, stack) ?? false;
  };
  return () {
    FlutterError.onError = previousFlutter;
    PlatformDispatcher.instance.onError = previousPlatform;
  };
}
