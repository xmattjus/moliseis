import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

/// Preserves Material scrolling while tolerating stale Apple velocity samples.
class AppScrollBehavior extends MaterialScrollBehavior {
  /// Creates the app's platform-specific scroll configuration.
  const AppScrollBehavior();

  @override
  GestureVelocityTrackerBuilder velocityTrackerBuilder(BuildContext context) {
    final platform = getPlatform(context);
    final nativeBuilder = super.velocityTrackerBuilder(context);
    if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
      return (event) => _OrderedScrollVelocityTracker(nativeBuilder(event));
    }
    return nativeBuilder;
  }
}

/// Keeps FLUTTER-7B's reversed timestamps out of Apple's velocity estimators.
///
/// Dropping stale samples avoids both Flutter's ordering assertion and invalid
/// velocity intervals. Valid samples retain each platform's native estimation.
/// macOS inherits the ordering assertion from the iOS tracker, but estimates
/// velocity with different weights, so both native algorithms are delegated.
/// Each drag pointer owns a separate tracker through the gesture recognizer.
class _OrderedScrollVelocityTracker extends VelocityTracker {
  _OrderedScrollVelocityTracker(this._delegate)
    : super.withKind(_delegate.kind);

  final VelocityTracker _delegate;
  Duration? _lastTime;

  @override
  void addPosition(Duration time, Offset position) {
    final lastTime = _lastTime;
    if (lastTime != null && time < lastTime) return;
    _delegate.addPosition(time, position);
    _lastTime = time;
  }

  @override
  VelocityEstimate? getVelocityEstimate() => _delegate.getVelocityEstimate();

  @override
  Velocity getVelocity() => _delegate.getVelocity();
}
