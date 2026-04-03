import 'package:flutter/material.dart';

/// Manages slideshow autoplay visibility based on scroll position.
///
/// Encapsulates the visibility state notifier and scroll threshold logic,
/// reducing duplication when coordinating autoplay across multiple screens.
class SlideshowVisibilityNotifier {
  /// Creates a notifier with the given scroll threshold.
  ///
  /// When scroll position exceeds [threshold], autoplay is disabled.
  SlideshowVisibilityNotifier({required this.threshold})
    : _notifier = ValueNotifier<bool>(true);

  /// The scroll position threshold at which to disable autoplay.
  final double threshold;

  final ValueNotifier<bool> _notifier;

  /// Notifies listeners of visibility state changes.
  ValueNotifier<bool> get notifier => _notifier;

  /// Updates visibility based on scroll notification metrics.
  void updateVisibilityFromNotification(ScrollNotification notification) {
    final pixels = notification.metrics.pixels;
    if (pixels > threshold) {
      _notifier.value = false;
    } else if (pixels <= threshold) {
      _notifier.value = true;
    }
  }

  /// Disposes the underlying notifier.
  void dispose() {
    _notifier.dispose();
  }
}
