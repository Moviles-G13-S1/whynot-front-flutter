import 'package:flutter/material.dart';

import 'app/whynot_app.dart';
import 'app/whynot_theme.dart';

/// Starts the application after applying the global iOS system-bar style.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  WhyNotTheme.configureSystemUi();
  runApp(const WhyNotApp());
}
