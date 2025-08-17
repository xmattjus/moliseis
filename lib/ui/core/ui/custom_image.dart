import 'dart:io' show File;
import 'dart:math' show sqrt;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';

class CustomImage extends StatelessWidget {
  const CustomImage(
    this.provider, {
    super.key,
    required this.width,
    required this.height,
    required this.imageWidth,
    required this.imageHeight,
    this.fit,
    this.onImageLoading,
  });

  CustomImage.network(
    String url, {
    required this.width,
    required this.height,
    required this.imageWidth,
    required this.imageHeight,
    this.fit,
    this.onImageLoading,
  }) : provider = CachedNetworkImageProvider(url);

  CustomImage.file(
    File file, {
    required this.width,
    required this.height,
    required this.imageWidth,
    required this.imageHeight,
    this.fit,
    this.onImageLoading,
  }) : provider = FileImage(file);

  final ImageProvider provider;

  /// Require the image to have this width (in logical pixels, a.k.a screen
  /// independent pixels).
  final double width;

  /// Require the image to have this height (in logical pixels, a.k.a screen
  /// independent pixels).
  final double height;

  /// The image width.
  final int imageWidth;

  /// The image height.
  final int imageHeight;

  /// How to inscribe the image into the space allocated during layout.
  final BoxFit? fit;

  final void Function(bool isLoading)? onImageLoading;

  @override
  Widget build(BuildContext context) {
    assert(
      width.isFinite && height.isFinite,
      'Invalid image dimensions: $width x $height',
    );
    // debugInvertOversizedImages = true;

    final devicePixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0;
    final widgetWidthPx = width * devicePixelRatio;
    final widgetHeightPx = height * devicePixelRatio;
    final widgetAspectRatio = widgetWidthPx / widgetHeightPx;
    final srcAspectRatio = imageWidth / imageHeight;

    double targetWidthPx;
    double targetHeightPx;

    // Calculates the width and the height the image must be decoded to.
    //
    // Sources:
    // https://medium.com/make-android/save-your-memory-usage-by-optimizing-network-image-in-flutter-cbc9f8af47cd
    // https://github.com/BigTimo/auto_resize_image/blob/master/lib/src/auto_resize_image.dart
    if (imageWidth * imageHeight <= widgetWidthPx * widgetHeightPx) {
      targetWidthPx = imageWidth.toDouble();
      targetHeightPx = imageHeight.toDouble();
    } else {
      if (srcAspectRatio / widgetAspectRatio > 2 ||
          (1 / srcAspectRatio) / (1 / widgetAspectRatio) > 2) {
        if (srcAspectRatio > 1) {
          // Landscape
          targetWidthPx = widgetHeightPx * srcAspectRatio;
          targetHeightPx = widgetHeightPx;
        } else {
          // Portrait
          targetWidthPx = widgetWidthPx;
          targetHeightPx = widgetWidthPx / srcAspectRatio;
        }
      } else {
        final scale = sqrt(
          (widgetWidthPx * widgetHeightPx) / (imageWidth * imageHeight),
        );
        targetWidthPx = imageWidth * scale;
        targetHeightPx = imageHeight * scale;
      }
    }

    return Image(
      image: ResizeImage(
        provider,
        width: targetWidthPx.toInt(),
        height: targetHeightPx.toInt(),
      ),
      frameBuilder: (_, child, frame, wasSynchronouslyLoaded) {
        final loaded = frame != null || wasSynchronouslyLoaded;

        onImageLoading?.call(!loaded);

        if (wasSynchronouslyLoaded) {
          return child;
        }

        return AnimatedOpacity(
          opacity: loaded ? 1 : 0,
          duration: Durations.extralong4,
          curve: Curves.easeInOutCubicEmphasized,
          child: child,
        );
      },
      errorBuilder: (context, error, stackTrace) {
        final log = Logger('CustomImage');

        log.severe('An error during image loading.', error, stackTrace);

        const color = Colors.grey;

        const widget = Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Si è verificato un errore durante il caricamento.',
            overflow: TextOverflow.fade,
            maxLines: 3,
            style: TextStyle(color: color),
          ),
        );

        return SizedBox(
          width: width,
          height: height,
          child: EmptyView(
            icon: const Icon(Icons.image_not_supported_outlined, color: color),
            text: height > 148 ? widget : null,
          ),
        );
      },
      width: width,
      height: height,
      fit: fit,
    );
  }
}
