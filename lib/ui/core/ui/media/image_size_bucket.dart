// ignore_for_file: avoid_classes_with_only_static_members

/// Maps logical pixel dimensions to discrete physical-pixel "buckets",
/// preventing image reloads on every window-resize tick while still avoiding
/// full-resolution decoding outside the gallery screen.
///
/// Separate bucket lists are kept for width and height so each axis can be
/// tuned independently (e.g. tall mobile screens need larger height buckets).
///
/// Usage
/// -----
/// ```dart
/// return LayoutBuilder(
///   builder: (BuildContext context, BoxConstraints constraints) {
///     final bucket = ImageSizeBucket.resolve(
///       logicalWidth:  constraints.maxWidth,
///       logicalHeight: constraints.maxHeight,
///       devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
///     );
///
///     return CachedNetworkImage(
///       // ...
///       memCacheWidth: bucket.width,
///       memCacheHeight: bucket.height,
///     );
///   }
/// );
/// ```
abstract final class ImageSizeBucket {
  // ---------------------------------------------------------------------------
  // Bucket thresholds – physical pixels (logical × DPR).
  static const List<int> _widthBuckets = [
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
  static const List<int> _heightBuckets = [
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

  /// Resolves both axes at once and returns an [ImageBucketSize].
  ///
  /// Either field may be `null` when the required physical size exceeds all
  /// buckets for that axis, signalling full resolution for that dimension.
  /// Use [resolveAndClamp] to never return null values.
  static ImageBucketSize resolve({
    required double logicalWidth,
    required double logicalHeight,
    required double devicePixelRatio,
  }) => ImageBucketSize(
    width: _snap(logicalWidth, devicePixelRatio, _widthBuckets),
    height: _snap(logicalHeight, devicePixelRatio, _heightBuckets),
  );

  /// Like [resolve] but clamps to the largest bucket instead of returning null
  /// when a dimension exceeds all thresholds.
  static ImageBucketSize resolveAndClamp({
    required double logicalWidth,
    required double logicalHeight,
    required double devicePixelRatio,
  }) => ImageBucketSize(
    width:
        _snap(logicalWidth, devicePixelRatio, _widthBuckets) ??
        _widthBuckets.last,
    height:
        _snap(logicalHeight, devicePixelRatio, _heightBuckets) ??
        _heightBuckets.last,
  );

  static int? _snap(
    double logicalSize,
    double devicePixelRatio,
    List<int> buckets,
  ) {
    final physical = (logicalSize * devicePixelRatio).ceil();
    for (final bucket in buckets) {
      if (physical <= bucket) return bucket;
    }
    return null;
  }
}

/// Bucketed physical-pixel dimensions for a single image slot.
///
/// A null value on either axis means "no constraint on that axis" (full res).
final class ImageBucketSize {
  const ImageBucketSize({this.width, this.height});

  /// Bucketed physical width in pixels, or null for full resolution.
  final int? width;

  /// Bucketed physical height in pixels, or null for full resolution.
  final int? height;

  @override
  String toString() => 'ImageBucketSize(${width}w × ${height}h)';

  @override
  bool operator ==(Object other) =>
      other is ImageBucketSize &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(width, height);
}
