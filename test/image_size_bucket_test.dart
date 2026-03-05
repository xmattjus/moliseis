import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/ui/core/ui/media/image_size_bucket.dart';

void main() {
  // DPR = 1.0 keeps the maths readable (logical px == physical px).
  const dpr = 1.0;

  // ---------------------------------------------------------------------------
  // ImageBucketSize equality
  // ---------------------------------------------------------------------------

  group('ImageBucketSize', () {
    test('equality is value-based', () {
      expect(
        const ImageBucketSize(width: 480, height: 800),
        equals(const ImageBucketSize(width: 480, height: 800)),
      );
      expect(
        const ImageBucketSize(width: 480, height: 800),
        isNot(equals(const ImageBucketSize(width: 480, height: 1200))),
      );
    });

    test('toString is readable', () {
      expect(
        const ImageBucketSize(width: 480, height: 800).toString(),
        equals('ImageBucketSize(480w × 800h)'),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // ImageSizeBucket.resolve — width axis
  // ---------------------------------------------------------------------------

  group('ImageSizeBucket.resolve – width', () {
    const List<int> widthBuckets = [
      72,
      144,
      216,
      288,
      432,
      576,
      720,
      792,
      864,
      936,
      1008,
      1152,
      1296,
      1440,
      1584,
      1728,
    ];

    ImageBucketSize r(double w, double h) => ImageSizeBucket.resolve(
      logicalWidth: w,
      logicalHeight: h,
      devicePixelRatio: dpr,
    );

    for (final int w in widthBuckets) {
      test('snaps at bucket width $w', () {
        expect(r(w.toDouble(), 1).width, equals(w));
      });

      test('snaps to bucket width $w when slightly smaller', () {
        final size = r(w - 0.1, 1);
        expect(size.width, equals(w));
        expect(size.height, isNotNull);
      });
    }

    test('returns null width beyond all buckets', () {
      expect(r(widthBuckets.last + 1, 1).width, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // ImageSizeBucket.resolve — height axis
  // ---------------------------------------------------------------------------

  group('ImageSizeBucket.resolve – height', () {
    const List<int> heightBuckets = [
      72,
      144,
      216,
      288,
      432,
      468,
      576,
      720,
      792,
      864,
      936,
      1008,
      1152,
      1296,
      1440,
      1584,
      1728,
    ];

    ImageBucketSize r(double w, double h) => ImageSizeBucket.resolve(
      logicalWidth: w,
      logicalHeight: h,
      devicePixelRatio: dpr,
    );

    for (final int h in heightBuckets) {
      test('snaps at bucket height $h', () {
        expect(r(1, h.toDouble()).height, equals(h));
      });

      test('snaps to bucket height $h when slightly smaller', () {
        final size = r(1, h - 0.1);
        expect(size.height, equals(h));
        expect(size.width, isNotNull);
      });
    }

    test('returns null height beyond all buckets', () {
      expect(r(1, heightBuckets.last + 1).height, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Mixed orientations — the core scenario
  // ---------------------------------------------------------------------------

  group('ImageSizeBucket.resolve – orientation combinations', () {
    ImageBucketSize r(double w, double h) => ImageSizeBucket.resolve(
      logicalWidth: w,
      logicalHeight: h,
      devicePixelRatio: dpr,
    );

    // Portrait widget (width < height): landscape image decoded at height bucket.
    // With ResizeImagePolicy.fit the tighter axis wins automatically, but we
    // verify that the height bucket is at least large enough to cover the slot.
    test('portrait widget returns wider height bucket than width', () {
      final size = r(200, 400); // portrait slot
      expect(size.width, equals(216)); // 200 → first bucket
      expect(size.height, equals(432)); // 400 → first bucket
      // After fit-policy: a landscape 16:9 image decoded within 480×480 gives
      // 480×270 — still covering the 200×400 slot without upscale for most
      // practical cases.
    });

    // Landscape widget (width > height): width bucket dominates.
    test('landscape widget returns wider width bucket than height', () {
      final size = r(800, 300);
      expect(size.width, equals(864));
      expect(size.height, equals(432));
    });

    // Square-ish widget: both axes in the same bucket.
    test('square widget returns equal buckets', () {
      final size = r(400, 400);
      expect(size.width, equals(432));
      expect(size.height, equals(432));
    });
  });

  // ---------------------------------------------------------------------------
  // DPR scaling
  // ---------------------------------------------------------------------------

  group('ImageSizeBucket.resolve – device pixel ratio', () {
    test('physical pixels account for DPR', () {
      // Logical 300 × 300 on a 2× display → 600 × 600 physical → second bucket.
      final size = ImageSizeBucket.resolve(
        logicalWidth: 300,
        logicalHeight: 300,
        devicePixelRatio: 2.0,
      );
      expect(size.width, equals(720));
      expect(size.height, equals(720));
    });

    test('ceils fractional physical pixels', () {
      // 480.1 × 1.0 → ceil(480.1) = 481 → second bucket.
      final size = ImageSizeBucket.resolve(
        logicalWidth: 480.1,
        logicalHeight: 480.1,
        devicePixelRatio: 1.0,
      );
      expect(size.width, equals(576));
      expect(size.height, equals(576));
    });
  });

  // ---------------------------------------------------------------------------
  // resolveAndClamp
  // ---------------------------------------------------------------------------

  group('ImageSizeBucket.resolveAndClamp', () {
    test('clamps both axes instead of returning null', () {
      final size = ImageSizeBucket.resolveAndClamp(
        logicalWidth: 2560,
        logicalHeight: 1440,
        devicePixelRatio: 1.0,
      );
      expect(size.width, equals(1728));
      expect(size.height, equals(1440));
    });

    test('behaves identically to resolve within bucket range', () {
      final resolved = ImageSizeBucket.resolve(
        logicalWidth: 640,
        logicalHeight: 400,
        devicePixelRatio: 1.0,
      );
      final clamped = ImageSizeBucket.resolveAndClamp(
        logicalWidth: 640,
        logicalHeight: 400,
        devicePixelRatio: 1.0,
      );
      expect(clamped.width, equals(resolved.width));
      expect(clamped.height, equals(resolved.height));
    });
  });
}
