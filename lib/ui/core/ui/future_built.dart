import 'package:flutter/material.dart';

class FutureBuilt<T> extends StatelessWidget {
  /// [FutureBuilder] helper widget to reduce boilerplate code.
  ///
  /// Creates a widget that builds itself based on the latest snapshot of
  /// interaction with a [Future].
  const FutureBuilt(
    this.future, {
    super.key,
    this.onLoading,
    required this.onSuccess,
    required this.onError,
  });

  /// The asynchronous computation to which the [onSuccess] and [onError] are
  /// currently connected, possibly null.
  ///
  /// If no future has yet completed, including in the case where [future] is
  /// null, the data provided to the [builder] will be set to [initialData].
  final Future<T>? future;

  /// The widget to build while the [Future] has not been completed yet.
  final Widget Function()? onLoading;

  /// The widget to build when the [Future] has been completed successfully.
  final Widget Function(T data) onSuccess;

  /// The widget to build when the [Future] has been completed with an error.
  final Widget Function(Object? error) onError;

  /// Whether the parent is a [RenderSliver] widget child or not.
  /// Defaults to false.
  // final bool isSliver;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (BuildContext context, AsyncSnapshot<T> snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return snapshot.hasData
              ? onSuccess(snapshot.data as T)
              : onError(snapshot.error);
        }
        return onLoading?.call() ?? const SizedBox();
      },
    );
  }
}
