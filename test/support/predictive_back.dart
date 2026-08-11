import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sends a predictive-back gesture `start` message to the test binding.
///
/// The message is delivered through the same `flutter/backgesture` platform
/// channel the Android platform uses, so the framework's predictive-back
/// observers react exactly as they would on a device. Call
/// [updatePredictiveBack], [commitPredictiveBack], or [cancelPredictiveBack]
/// afterwards to continue or end the gesture.
///
/// Predictive-back channel messages are only meaningful with the Android
/// page-transitions builder, so tests that use these helpers must run under
/// `TargetPlatform.android`.
Future<void> startPredictiveBack(WidgetTester tester) async {
  final messenger = tester.binding.defaultBinaryMessenger;
  await messenger.handlePlatformMessage(
    'flutter/backgesture',
    const StandardMethodCodec().encodeMethodCall(
      const MethodCall('startBackGesture', <String, Object?>{
        'touchOffset': <double>[5, 300],
        'progress': 0.0,
        'swipeEdge': 0,
      }),
    ),
    (_) {},
  );
  await tester.pump();
}

/// Sends a predictive-back gesture `update` message with [progress].
///
/// [progress] must be between 0.0 and 1.0 and moves the route transition
/// towards the revealed source page without mutating the route stack.
Future<void> updatePredictiveBack(
  WidgetTester tester,
  double progress,
) async {
  final messenger = tester.binding.defaultBinaryMessenger;
  await messenger.handlePlatformMessage(
    'flutter/backgesture',
    StandardMethodCodec().encodeMethodCall(
      MethodCall('updateBackGestureProgress', <String, Object?>{
        'touchOffset': <double>[5, 300],
        'progress': progress,
        'swipeEdge': 0,
      }),
    ),
    (_) {},
  );
  await tester.pump();
}

/// Sends a predictive-back gesture `commit` message.
///
/// The gesture ends successfully and the handled route is popped. Set
/// [settle] to false when the tree under test never settles (for example an
/// infinite spinner), and drive the remaining frames explicitly.
Future<void> commitPredictiveBack(
  WidgetTester tester, {
  bool settle = true,
}) async {
  final messenger = tester.binding.defaultBinaryMessenger;
  await messenger.handlePlatformMessage(
    'flutter/backgesture',
    const StandardMethodCodec().encodeMethodCall(
      const MethodCall('commitBackGesture'),
    ),
    (_) {},
  );
  await tester.pump();
  if (settle) {
    await tester.pumpAndSettle();
  }
}

/// Sends a predictive-back gesture `cancel` message.
///
/// The gesture ends without popping and the previously covered route is
/// restored to full view.
Future<void> cancelPredictiveBack(WidgetTester tester) async {
  final messenger = tester.binding.defaultBinaryMessenger;
  await messenger.handlePlatformMessage(
    'flutter/backgesture',
    const StandardMethodCodec().encodeMethodCall(
      const MethodCall('cancelBackGesture'),
    ),
    (_) {},
  );
  await tester.pumpAndSettle();
}
