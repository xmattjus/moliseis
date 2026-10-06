import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/ui/core/app_scroll_behavior.dart';

void main() {
  for (final platform in TargetPlatform.values) {
    testWidgets('preserves native scrolling on ${platform.name}', (
      tester,
    ) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Builder(
            builder: (value) {
              context = value;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      const behavior = AppScrollBehavior();
      const native = MaterialScrollBehavior();
      final tracker = behavior.velocityTrackerBuilder(context)(
        const PointerDownEvent(kind: PointerDeviceKind.stylus),
      );
      final reference = native.velocityTrackerBuilder(context)(
        const PointerDownEvent(kind: PointerDeviceKind.stylus),
      );
      expect(tracker.kind, PointerDeviceKind.stylus);
      expect(behavior.dragDevices, native.dragDevices);
      expect(
        behavior.getScrollPhysics(context).runtimeType,
        native.getScrollPhysics(context).runtimeType,
      );
      if (platform != TargetPlatform.iOS && platform != TargetPlatform.macOS) {
        expect(tracker.runtimeType, reference.runtimeType);
      }
      // Accelerating samples distinguish macOS and iOS velocity weights;
      // include equal timestamps and more samples than the history buffer.
      for (var i = 0; i < 30; i++) {
        final time = Duration(milliseconds: (i ~/ 2) * 10);
        final position = Offset(0, i * i * 10);
        tracker.addPosition(time, position);
        reference.addPosition(time, position);
      }
      final estimate = tracker.getVelocityEstimate()!;
      final expected = reference.getVelocityEstimate()!;
      expect(estimate.pixelsPerSecond, expected.pixelsPerSecond);
      expect(estimate.duration, expected.duration);
      expect(estimate.offset, expected.offset);
    });
  }

  testWidgets('iOS timestamp history belongs to each pointer tracker', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: Builder(
          builder: (value) {
            context = value;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    final builder = const AppScrollBehavior().velocityTrackerBuilder(context);
    final first = builder(const PointerDownEvent(pointer: 1));
    final second = builder(const PointerDownEvent(pointer: 2));
    first.addPosition(const Duration(seconds: 10), Offset.zero);
    second
      ..addPosition(Duration.zero, Offset.zero)
      ..addPosition(const Duration(milliseconds: 10), const Offset(0, 10));
    expect(second.getVelocityEstimate()!.offset, const Offset(0, 10));
    expect(first.getVelocityEstimate()!.offset, Offset.zero);
  });
}
