import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whynot_mobile/app/dependencies_scope.dart';
import 'package:whynot_mobile/app/whynot_theme.dart';
import 'package:whynot_mobile/models/input_policy.dart';
import 'package:whynot_mobile/models/user_profile.dart';
import 'package:whynot_mobile/views/screens/change_password_screen.dart';
import 'package:whynot_mobile/views/screens/create_account_screen.dart';
import 'package:whynot_mobile/views/screens/login_screen.dart';
import 'package:whynot_mobile/views/widgets/form_controls.dart';

import 'fakes/app_dependencies_fixture.dart';

void main() {
  test('auth validation reports the exact field requirement', () {
    expect(
      InputPolicy.nameValidationError(
        '1234567890123456',
        maxLength: UserProfileConstraints.maximumNameLength,
      ),
      'Name cannot exceed 15 characters.',
    );
    expect(
      InputPolicy.emailValidationError('user🎁@example.com'),
      'You cannot include emojis in your email.',
    );
    expect(
      InputPolicy.passwordValidationError('secret🎁'),
      'You cannot include emojis in your password.',
    );
    expect(
      InputPolicy.passwordValidationError('short', requireMinimumLength: true),
      'Password must be at least 8 characters.',
    );
  });

  testWidgets('login renders email and password errors below their fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      DependenciesScope(
        dependencies: createTestDependencies(),
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), 'user🎁@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'secret🎁');
    await tester.tap(find.text('Log in').last);
    await tester.pump();

    expect(
      find.text('You cannot include emojis in your email.'),
      findsOneWidget,
    );
    expect(
      find.text('You cannot include emojis in your password.'),
      findsOneWidget,
    );
    final passwordError = tester.widget<Text>(
      find.text('You cannot include emojis in your password.'),
    );
    expect(passwordError.style?.color, WhyNotColors.error);
    final passwordField = tester.widget<TextField>(
      find.byType(TextField).at(1),
    );
    expect(passwordField.decoration?.fillColor, WhyNotColors.errorSurface);
    expect(passwordField.decoration?.suffixIcon, isNotNull);
    final border =
        passwordField.decoration?.enabledBorder as OutlineInputBorder;
    expect(border.borderSide.color, WhyNotColors.error);
  });

  testWidgets('password is visible only while the eye is pressed', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'secret123');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.windows),
        home: Scaffold(
          body: DesignField(controller: controller, obscureText: true),
        ),
      ),
    );

    expect(
      tester.widget<TextField>(find.byType(TextField)).obscureText,
      isTrue,
    );
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.visibility_outlined)),
    );
    await tester.pump();

    expect(
      tester.widget<TextField>(find.byType(TextField)).obscureText,
      isFalse,
    );
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

    await gesture.up();
    await tester.pump();

    expect(
      tester.widget<TextField>(find.byType(TextField)).obscureText,
      isTrue,
    );
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
  });

  testWidgets('mobile toggles password visibility with each eye tap', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'secret123');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: Scaffold(
          body: DesignField(controller: controller, obscureText: true),
        ),
      ),
    );

    expect(
      tester.widget<TextField>(find.byType(TextField)).obscureText,
      isTrue,
    );

    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).obscureText,
      isFalse,
    );
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).obscureText,
      isTrue,
    );
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
  });

  testWidgets('registration renders field-specific validation messages', (
    tester,
  ) async {
    await tester.pumpWidget(
      DependenciesScope(
        dependencies: createTestDependencies(),
        child: const MaterialApp(home: CreateAccountScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '1234567890123456');
    await tester.enterText(fields.at(1), 'user🎁@example.com');
    await tester.enterText(fields.at(4), 'secret🎁');
    await tester.ensureVisible(find.text('Create an account').last);
    await tester.tap(find.text('Create an account').last);
    await tester.pump();

    expect(find.text('Name cannot exceed 15 characters.'), findsOneWidget);
    expect(
      find.text('You cannot include emojis in your email.'),
      findsOneWidget,
    );
    expect(
      find.text('You cannot include emojis in your password.'),
      findsOneWidget,
    );
  });

  testWidgets('change password renders errors below the related fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      DependenciesScope(
        dependencies: createTestDependencies(signedIn: true),
        child: const MaterialApp(home: ChangePasswordScreen()),
      ),
    );

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'currentpassword');
    await tester.enterText(fields.at(1), 'new🎁password');
    await tester.enterText(fields.at(2), 'new🎁password');
    await tester.ensureVisible(find.text('Update password'));
    await tester.tap(find.text('Update password'));
    await tester.pump();

    expect(
      find.text('You cannot include emojis in your password.'),
      findsNWidgets(2),
    );
  });
}
