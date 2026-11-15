import 'dart:async';

import 'package:flutter/painting.dart';

/// Records real source decodes without changing the resolved source identity.
class CountingImageProvider extends ImageProvider<Object> {
  CountingImageProvider(this.source);

  final ImageProvider source;
  int decodes = 0;

  @override
  Future<Object> obtainKey(ImageConfiguration configuration) =>
      source.obtainKey(configuration);

  @override
  ImageStreamCompleter loadImage(Object key, ImageDecoderCallback decode) {
    decodes++;
    return source.loadImage(key, decode);
  }
}

/// Exercises asynchronous key failure, which production sources do not emit.
class FailingKeyImageProvider extends ImageProvider<Object> {
  FailingKeyImageProvider(this.error);

  final Object error;

  @override
  Future<Object> obtainKey(ImageConfiguration configuration) =>
      Future<Object>.error(error);
}

/// Resolves the first actual frame and releases its listener on every outcome.
///
/// The caller owns the returned [ImageInfo] and must dispose it.
Future<ImageInfo> decodeImage(ImageProvider provider) async {
  final stream = provider.resolve(ImageConfiguration.empty);
  final frame = Completer<ImageInfo>();
  final listener = ImageStreamListener(
    (image, _) {
      if (!frame.isCompleted) {
        frame.complete(image);
      } else {
        image.dispose();
      }
    },
    onError: (error, stack) {
      if (!frame.isCompleted) frame.completeError(error, stack);
    },
  );
  stream.addListener(listener);
  try {
    return await frame.future.timeout(const Duration(seconds: 10));
  } finally {
    stream.removeListener(listener);
  }
}
