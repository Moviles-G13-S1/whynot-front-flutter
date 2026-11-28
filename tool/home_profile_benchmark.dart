// Browser-only, deterministic profiling entry point; never used by lib/main.dart.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter, invalid_use_of_visible_for_testing_member
import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:whynot_mobile/app/dependencies_scope.dart';
import 'package:whynot_mobile/app/whynot_theme.dart';
import 'package:whynot_mobile/controllers/connectivity_status.dart';
import 'package:whynot_mobile/controllers/rebuild_trace.dart';
import 'package:whynot_mobile/models/user_profile.dart';
import 'package:whynot_mobile/views/screens/home_screen.dart';
import 'package:whynot_mobile/views/screens/profile_screen.dart';
import '../test/fakes/app_dependencies_fixture.dart';
import '../test/fakes/in_memory_repositories.dart';

class BenchmarkUsers extends InMemoryUserRepository {
  UserProfile profile = makeProfile();
  final updates = StreamController<UserProfile?>.broadcast(sync: true);
  @override
  Stream<UserProfile?> watch(String userId) async* {
    yield profile;
    yield* updates.stream;
  }

  void emit(UserProfile value) {
    profile = value;
    updates.add(value);
  }
}

UserProfile makeProfile({
  String name = 'Jerónimo Test',
  int age = 24,
  bool cached = false,
  bool pending = false,
}) => UserProfile(
  id: 'test-user',
  name: name,
  email: 'benchmark@example.invalid',
  gender: 'Male',
  age: age,
  preferredCategoryId: 'technology',
  cityId: 'bogota',
  fromCache: cached,
  hasPendingWrites: pending,
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BenchmarkApp());
}

class BenchmarkApp extends StatefulWidget {
  const BenchmarkApp({super.key});
  @override
  State<BenchmarkApp> createState() => _BenchmarkAppState();
}

class _BenchmarkAppState extends State<BenchmarkApp> {
  final network = ConnectivityStatus(observe: false)
    ..setStatus(NetworkStatus.available);
  final users = BenchmarkUsers();
  late final dependencies = createTestDependencies(
    signedIn: true,
    connectivity: network,
    userRepositoryOverride: users,
  );
  late final home = DependenciesScope(
    dependencies: dependencies,
    child: const HomeScreen(),
  );
  late final profile = DependenciesScope(
    dependencies: dependencies,
    child: const ProfileScreen(),
  );
  bool showHome = true;
  bool running = false;
  String result =
      'Ready: same synthetic profile, no Firebase or location requests.';
  final samples = <Map<String, Object?>>[];
  String get variant => const String.fromEnvironment(
    'BENCHMARK_VARIANT',
    defaultValue: 'unknown',
  );

  Future<void> settle() async {
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 80));
  }

  Future<void> runScenario() async {
    if (running) return;
    setState(() {
      running = true;
      result = 'Running controlled scenario…';
    });
    await Future<void>.delayed(const Duration(seconds: 2));
    samples.clear();
    for (final screen in ['Home', 'Profile']) {
      users.emit(makeProfile());
      network.setStatus(NetworkStatus.available);
      setState(() => showHome = screen == 'Home');
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await settle();
      await settle();
      for (final scenario in [
        'unrelated_age',
        'metadata',
        'connectivity',
        'name',
      ]) {
        RebuildTrace.phase = 'warmup';
        users.emit(makeProfile());
        network.setStatus(NetworkStatus.available);
        await settle();
        await settle();
        RebuildTrace.phase = '$screen/$scenario';
        RebuildTrace.counts.clear();
        final start = html.window.performance.now();
        final task = TimelineTask()
          ..start('WhyNot scenario: $screen/$scenario');
        for (var i = 0; i < 12; i++) {
          if (scenario == 'unrelated_age') users.emit(makeProfile(age: 25 + i));
          if (scenario == 'metadata') {
            users.emit(makeProfile(cached: i.isEven, pending: i.isEven));
          }
          if (scenario == 'connectivity') {
            network.setStatus(
              i.isEven ? NetworkStatus.offline : NetworkStatus.available,
            );
          }
          if (scenario == 'name') {
            users.emit(
              makeProfile(name: i.isEven ? 'Ana Test' : 'Jerónimo Test'),
            );
          }
          await settle();
        }
        task.finish();
        samples.add({
          'screen': screen,
          'scenario': scenario,
          'updates': 12,
          'elapsedMs': html.window.performance.now() - start,
          'builds': Map<String, int>.of(RebuildTrace.counts),
        });
      }
    }
    RebuildTrace.phase = 'finished';
    setState(() {
      running = false;
      result = const JsonEncoder.withIndent('  ').convert(samples);
    });
  }

  void export() {
    final entries = html.window.performance
        .getEntries()
        .where((entry) => entry.name.contains('WhyNot'))
        .map(
          (entry) => {
            'name': entry.name,
            'entryType': entry.entryType,
            'startTime': entry.startTime,
            'duration': entry.duration,
          },
        )
        .toList();
    final json = const JsonEncoder.withIndent('  ').convert({
      'variant': variant,
      'platform': 'Flutter Web / Chrome',
      'userAgent': html.window.navigator.userAgent,
      'viewport': [html.window.innerWidth, html.window.innerHeight],
      'samples': samples,
      'userTimingEntries': entries,
      'note':
          'Elapsed scenario time includes 80 ms pacing per update; it is not build time or user latency.',
    });
    final url = html.Url.createObjectUrlFromBlob(
      html.Blob([json], 'application/json'),
    );
    html.AnchorElement(href: url)
      ..download = '${variant}_user_timing.json'
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: WhyNotTheme.data,
    home: Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            SizedBox(
              width: 390,
              child: Column(
                children: [
                  Text(
                    '$variant · Home/Profile profiling',
                    style: const TextStyle(fontSize: 18),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton(
                        onPressed: running ? null : runScenario,
                        child: const Text('Run scenario'),
                      ),
                      OutlinedButton(
                        onPressed: samples.isEmpty || running ? null : export,
                        child: const Text('Export measurements'),
                      ),
                      TextButton(
                        onPressed: running
                            ? null
                            : () => setState(() => showHome = !showHome),
                        child: const Text('Switch screen'),
                      ),
                    ],
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(
                        result,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: SizedBox(
                  width: 402,
                  height: 874,
                  child: showHome ? home : profile,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
