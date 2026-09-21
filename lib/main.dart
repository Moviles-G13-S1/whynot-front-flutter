import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app/whynot_app.dart';
import 'app/whynot_theme.dart';
import 'firebase_options.dart';

/// Starts the application after initializing Firebase
/// and applying the global iOS system-bar style.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  WhyNotTheme.configureSystemUi();

  runApp(const WhyNotApp());
}