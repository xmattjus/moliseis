import 'package:flutter/material.dart';

class CustomCircularProgressIndicator extends StatelessWidget {
  /// Creates a [CircularProgressIndicator] immediately.
  const CustomCircularProgressIndicator({super.key, this.size}) : _delay = null;

  /// Creates a [CircularProgressIndicator] after the requested [delay] has
  /// passed.
  ///
  /// Defaults to 330 ms of delay.
  const CustomCircularProgressIndicator.withDelay({
    super.key,
    Duration delay = Durations.medium2,
    this.size,
  }) : _delay = delay;

  /// The delay after which the [CircularProgressIndicator] will be shown.
  final Duration? _delay;

  final double? size;

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
    return SizedBox(
      width: size,
      height: size,
      child: const CircularProgressIndicator(),
    );
  }
}
