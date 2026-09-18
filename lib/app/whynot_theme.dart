import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Colors shared by the WhyNot visual language.
abstract final class WhyNotColors {
  static const background = Color(0xFFFEFDFB);
  static const muted = Color(0xFF817D78);
  static const card = Color(0xFFEFE6D7);
  static const search = Color(0xFFE9E8E7);
  static const divider = Color(0xFFE0DEDB);
  static const form = Color(0xFFF4EFE8);
  static const field = Color(0xFFFFFEFE);
  static const border = Color(0xFFC6C0BB);
}

/// Reusable text styles from the Figma design.
abstract final class WhyNotTextStyles {
  /// Editorial style used by headings and field labels.
  static TextStyle serif({required double size, Color color = Colors.black}) {
    return TextStyle(
      fontFamily: 'Frank Ruhl Libre',
      color: color,
      fontSize: size,
      height: 1,
      fontWeight: FontWeight.w400,
    );
  }

  /// Lightweight Poppins style used by secondary text.
  static TextStyle muted({required double size}) {
    return TextStyle(
      fontFamily: 'Poppins',
      color: WhyNotColors.muted,
      fontSize: size,
      height: 1.15,
      fontWeight: FontWeight.w300,
    );
  }
}

/// Global theme and platform chrome configuration.
abstract final class WhyNotTheme {
  /// Material theme consumed by [MaterialApp].
  static ThemeData get data => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: WhyNotColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.black,
      surface: WhyNotColors.background,
    ),
    fontFamily: 'Poppins',
  );

  /// Makes the native iOS bars blend with the application's background.
  static void configureSystemUi() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: WhyNotColors.background,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }
}

/// Border shared by text fields and dropdowns.
OutlineInputBorder fieldBorder({Color color = WhyNotColors.border}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: color),
  );
}

/// Compact text-button style used by secondary actions.
ButtonStyle linkButtonStyle() {
  return TextButton.styleFrom(
    foregroundColor: WhyNotColors.muted,
    padding: EdgeInsets.zero,
    minimumSize: Size.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    textStyle: const TextStyle(
      fontFamily: 'Poppins',
      fontSize: 15,
      fontWeight: FontWeight.w300,
    ),
  );
}
