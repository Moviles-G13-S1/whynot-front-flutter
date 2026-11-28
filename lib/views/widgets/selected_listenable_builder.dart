import 'package:flutter/widgets.dart';

/// Rebuilds only when the selected immutable value changes by ==.
class SelectedListenableBuilder<T> extends StatefulWidget {
  const SelectedListenableBuilder({
    required this.listenable,
    required this.select,
    required this.builder,
    this.child,
    super.key,
  });
  final Listenable listenable;
  final T Function() select;
  final Widget Function(BuildContext, T, Widget?) builder;
  final Widget? child;
  @override
  State<SelectedListenableBuilder<T>> createState() =>
      _SelectedListenableBuilderState<T>();
}

class _SelectedListenableBuilderState<T>
    extends State<SelectedListenableBuilder<T>> {
  late T _value;
  @override
  void initState() {
    super.initState();
    _value = widget.select();
    widget.listenable.addListener(_changed);
  }

  void _changed() {
    final next = widget.select();
    if (next == _value) return;
    setState(() => _value = next);
  }

  @override
  void didUpdateWidget(SelectedListenableBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listenable != widget.listenable) {
      oldWidget.listenable.removeListener(_changed);
      widget.listenable.addListener(_changed);
    }
    _value = widget.select();
  }

  @override
  void dispose() {
    widget.listenable.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _value, widget.child);
}
