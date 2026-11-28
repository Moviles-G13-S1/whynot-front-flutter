import 'dart:developer';

/// Opt-in profiling only; the constant false branch is removed in normal builds.
abstract final class RebuildTrace {
  static const enabled = bool.fromEnvironment('PROFILE_REBUILDS');
  static String phase = 'warmup';
  static final counts = <String, int>{};

  static void record(String widget) {
    if (!enabled) return;
    final name = '$phase/$widget';
    counts.update(name, (value) => value + 1, ifAbsent: () => 1);
    Timeline.instantSync('WhyNot build: $name');
  }
}
