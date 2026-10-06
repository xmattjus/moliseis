import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/ui/explore/widgets/explore_screen.dart';

import 'support/sync_harness.dart';

void main() {
  for (final platform in [TargetPlatform.macOS, TargetPlatform.iOS]) {
    for (final stalePosition in [Offset.zero, const Offset(0, 300)]) {
      testWidgets(
        'FLUTTER-7B: ${platform.name} scroll ignores '
        'stale sample $stalePosition',
        (tester) async {
          debugDefaultTargetPlatformOverride = platform;
          addTearDown(() => debugDefaultTargetPlatformOverride = null);
          await tester.pumpWidget(buildRealSyncApp(SyncHarness()));
          await tester.pumpAndSettle();

          final context = tester.element(find.byType(ExploreScreen));
          final tracker = ScrollConfiguration.of(
            context,
          ).velocityTrackerBuilder(context)(const PointerDownEvent());
          final reference = platform == TargetPlatform.macOS
              ? MacOSScrollViewFlingVelocityTracker(PointerDeviceKind.touch)
              : IOSScrollViewFlingVelocityTracker(PointerDeviceKind.touch);
          for (var i = 0; i < 5; i++) {
            final time = Duration(milliseconds: 100 + i * 10);
            final position = Offset(0, i * 10);
            tracker.addPosition(time, position);
            reference.addPosition(time, position);
          }

          // Synthetic reproduction of the 13 microsecond reversal in Sentry.
          expect(
            () => tracker.addPosition(
              const Duration(microseconds: 139987),
              stalePosition,
            ),
            returnsNormally,
          );
          tracker.addPosition(
            const Duration(milliseconds: 150),
            const Offset(0, 50),
          );
          reference.addPosition(
            const Duration(milliseconds: 150),
            const Offset(0, 50),
          );
          final estimate = tracker.getVelocityEstimate()!;
          final expected = reference.getVelocityEstimate();
          expect(estimate.pixelsPerSecond, expected.pixelsPerSecond);
          expect(estimate.duration, expected.duration);
          expect(estimate.offset, expected.offset);
          expect(estimate.pixelsPerSecond.dy, greaterThan(0));

          await tester.pumpWidget(const SizedBox.shrink());
          debugDefaultTargetPlatformOverride = null;
        },
      );
    }

    for (final kind in [
      PointerDeviceKind.touch,
      if (platform == TargetPlatform.macOS) PointerDeviceKind.trackpad,
    ]) {
      testWidgets(
        'FLUTTER-7B: real ${platform.name} ${kind.name} scroll survives '
        'reversed pointer timestamps',
        (tester) async {
          debugDefaultTargetPlatformOverride = platform;
          addTearDown(() => debugDefaultTargetPlatformOverride = null);
          final controller = ScrollController();
          addTearDown(controller.dispose);
          await tester.pumpWidget(buildRealSyncApp(SyncHarness()));
          await tester.pumpAndSettle();
          final context = tester.element(find.byType(ExploreScreen));
          Navigator.of(context, rootNavigator: true).push<void>(
            PageRouteBuilder<void>(
              pageBuilder: (_, _, _) => ListView(
                key: const Key('regression-scroll'),
                controller: controller,
                children: const [SizedBox(height: 3000)],
              ),
            ),
          );
          await tester.pumpAndSettle();
          final start = tester.getCenter(
            find.byKey(const Key('regression-scroll')),
          );
          final gesture = await tester.createGesture(kind: kind);
          if (kind == PointerDeviceKind.trackpad) {
            await gesture.panZoomStart(
              start,
              timeStamp: const Duration(milliseconds: 100),
            );
          } else {
            await gesture.down(
              start,
              timeStamp: const Duration(milliseconds: 100),
            );
          }
          await gesture.moveBy(
            const Offset(0, -40),
            timeStamp: const Duration(milliseconds: 120),
          );
          await gesture.moveBy(
            const Offset(0, -10),
            timeStamp: const Duration(microseconds: 119987),
          );
          final exception = tester.takeException();
          await gesture.moveBy(
            const Offset(0, -50),
            timeStamp: const Duration(milliseconds: 140),
          );
          await gesture.up(timeStamp: const Duration(milliseconds: 150));
          await tester.pumpAndSettle();

          expect(exception, isNull);
          expect(tester.takeException(), isNull);
          expect(controller.offset, greaterThan(0));
          await tester.pumpWidget(const SizedBox.shrink());
          debugDefaultTargetPlatformOverride = null;
        },
      );
    }
  }
}
