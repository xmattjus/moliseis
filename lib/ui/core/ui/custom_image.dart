import 'dart:math' show sqrt;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/molis_image/molis_image.dart';
import 'package:moliseis/main.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/utils/log_events.dart';

class CustomImage extends StatelessWidget {
  const CustomImage(
    this.imageData, {
    super.key,
    required this.width,
    required this.height,
    this.fit,
    this.onImageLoading,
  });

  final MolisImage imageData;

  /// If non-null, require the image to have this width (in logical pixels,
  /// a.k.a screen independent pixels).
  ///
  /// If null, the image will pick a size that best preserves its intrinsic
  /// aspect ratio.
  final double width;

  /// If non-null, require the image to have this height (in logical pixels,
  /// a.k.a screen independent pixels).
  ///
  /// If null, the image will pick a size that best preserves its intrinsic
  /// aspect ratio.
  final double height;

  /// How to inscribe the image into the space allocated during layout.
  final BoxFit? fit;

  final void Function(bool isLoading)? onImageLoading;

  @override
  Widget build(BuildContext context) {
    // debugInvertOversizedImages = true;

    final devicePixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0;
    final widgetWidthPx = width * devicePixelRatio;
    final widgetHeightPx = height * devicePixelRatio;
    final widgetAspectRatio = widgetWidthPx / widgetHeightPx;
    final srcAspectRatio = imageData.width / imageData.height;

    double targetWidthPx;
    double targetHeightPx;

    /// Calculates the width and the height the image must be decoded to.
    ///
    /// Source: https://medium.com/make-android/save-your-memory-usage-by-optimizing-network-image-in-flutter-cbc9f8af47cd
    /// Source: https://github.com/BigTimo/auto_resize_image/blob/master/lib/src/auto_resize_image.dart
    if (imageData.width * imageData.height <= widgetWidthPx * widgetHeightPx) {
      targetWidthPx = imageData.width.toDouble();
      targetHeightPx = imageData.height.toDouble();
    } else {
      if (srcAspectRatio / widgetAspectRatio > 2 ||
          (1 / srcAspectRatio) / (1 / widgetAspectRatio) > 2) {
        if (srcAspectRatio > 1) {
          //wide
          targetWidthPx = widgetHeightPx * srcAspectRatio;
          targetHeightPx = widgetHeightPx;
        } else {
          //long
          targetWidthPx = widgetWidthPx;
          targetHeightPx = widgetWidthPx / srcAspectRatio;
        }
      } else {
        final scale = sqrt(
          (widgetWidthPx * widgetHeightPx) /
              (imageData.width * imageData.height),
        );
        targetWidthPx = imageData.width * scale;
        targetHeightPx = imageData.height * scale;
      }
    }

    return Image(
      image: ResizeImage(
        CachedNetworkImageProvider(imageData.url),
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
        logger.severe(LogEvents.imageLoadingError, error, stackTrace);

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
