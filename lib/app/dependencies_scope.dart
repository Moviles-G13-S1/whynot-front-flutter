import 'package:flutter/widgets.dart';

import 'app_dependencies.dart';

class DependenciesScope extends InheritedWidget {
  const DependenciesScope({
    required this.dependencies,
    required super.child,
    super.key,
  });

  final AppDependencies dependencies;

  static AppDependencies of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<DependenciesScope>();
    assert(scope != null, 'DependenciesScope is missing above this widget.');
    return scope!.dependencies;
  }

  @override
  bool updateShouldNotify(DependenciesScope oldWidget) =>
      dependencies != oldWidget.dependencies;
}

extension DependenciesContext on BuildContext {
  AppDependencies get dependencies => DependenciesScope.of(this);
}
