import 'package:flutter/material.dart';

class CustomCircularProgressIndicator extends StatelessWidget {
  /// Creates a [CircularProgressIndicator] immediately.
  const CustomCircularProgressIndicator({super.key}) : _delay = null;

  /// Creates a [CircularProgressIndicator] after the requested [delay] has
  /// passed.
  ///
  /// Defaults to 330 ms of delay.
  const CustomCircularProgressIndicator.withDelay({
    super.key,
    Duration delay = const Duration(milliseconds: 330),
  }) : _delay = delay;

  /// The delay after which the [CircularProgressIndicator] will be shown.
  final Duration? _delay;

  @override
  Widget build(BuildContext context) {
    final child = _buildSpinner();

    if (_delay != null) {
      return FutureBuilder(
        future: Future.delayed(_delay),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return child;
          }

          return const SizedBox();
        },
      );
    }

    return child;
  }

  Widget _buildSpinner() {
    return const SizedBox(
      width: 40.0,
      height: 40.0,
      child: CircularProgressIndicator(),
    );
  }
}
