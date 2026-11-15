import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Computes a proportional cover request within source and 1728-axis bounds.
///
/// Both axes share one scale. Ceil retains cover detail; the final integer
/// guards limit quantization to one pixel and never request source upscaling.
/// The output ceiling can leave the short axis below the requested target.
/// Throws [ArgumentError] for nonpositive intrinsic or target dimensions.
({int width, int height}) boundedCoverSize({
  required int intrinsicWidth,
  required int intrinsicHeight,
  required int targetWidth,
  required int targetHeight,
}) {
  if (intrinsicWidth <= 0 ||
      intrinsicHeight <= 0 ||
      targetWidth <= 0 ||
      targetHeight <= 0) {
    throw ArgumentError('Image and target dimensions must be positive.');
  }
  final scale = math.min(
    1,
    math.min(
      math.max(targetWidth / intrinsicWidth, targetHeight / intrinsicHeight),
      1728 / math.max(intrinsicWidth, intrinsicHeight),
    ),
  );
  return (
    width: (intrinsicWidth * scale).ceil().clamp(
      1,
      math.min(intrinsicWidth, 1728),
    ),
    height: (intrinsicHeight * scale).ceil().clamp(
      1,
      math.min(intrinsicHeight, 1728),
    ),
  );
}

/// Delegates acquisition and codecs, changing only cover decode targets.
///
/// Use with an unresized provider and [BoxFit.cover]. This does not change disk
/// identity or animation settings. Codecs that ignore target sizing (including
/// multiframe codecs on the current engine) retain their existing behavior.
@immutable
class BoundedCoverImage extends ImageProvider<BoundedCoverImageKey> {
  /// Creates a cover request for positive physical [width] and [height].
  const BoundedCoverImage(
    this.imageProvider, {
    required this.width,
    required this.height,
  }) : assert(width > 0, 'Target width must be positive.'),
       assert(height > 0, 'Target height must be positive.');

  /// The original source; its acquisition and animation behavior are retained.
  final ImageProvider imageProvider;

  /// Physical target width before intrinsic/output bounds.
  final int width;

  /// Physical target height before intrinsic/output bounds.
  final int height;

  @override
  Future<BoundedCoverImageKey> obtainKey(ImageConfiguration configuration) =>
      imageProvider
          .obtainKey(configuration)
          .then<BoundedCoverImageKey>(
            (source) => BoundedCoverImageKey._(source, width, height),
          );

  @override
  ImageStreamCompleter loadImage(
    BoundedCoverImageKey key,
    ImageDecoderCallback decode,
  ) {
    final completer =
        imageProvider.loadImage(key._source, (buffer, {getTargetSize}) {
          assert(getTargetSize == null, 'Use an unresized source provider.');
          return decode(
            buffer,
            getTargetSize: (width, height) {
              final size = boundedCoverSize(
                intrinsicWidth: width,
                intrinsicHeight: height,
                targetWidth: key._width,
                targetHeight: key._height,
              );
              return ui.TargetImageSize(width: size.width, height: size.height);
            },
          );
        })..addEphemeralErrorListener((error, stack) {
          // Wait for ImageCache to register the outer key before eviction.
          scheduleMicrotask(
            () => PaintingBinding.instance.imageCache.evict(key),
          );
        });
    return completer;
  }

  @override
  bool operator ==(Object other) =>
      other is BoundedCoverImage &&
      imageProvider == other.imageProvider &&
      width == other.width &&
      height == other.height;

  @override
  int get hashCode => Object.hash(imageProvider, width, height);
}

/// Distinguishes cover streams from stock resizing and incompatible targets.
@immutable
class BoundedCoverImageKey {
  const BoundedCoverImageKey._(this._source, this._width, this._height);

  final Object _source;
  final int _width;
  final int _height;

  @override
  bool operator ==(Object other) =>
      other is BoundedCoverImageKey &&
      _source == other._source &&
      _width == other._width &&
      _height == other._height;

  @override
  int get hashCode => Object.hash(_source, _width, _height);
}
