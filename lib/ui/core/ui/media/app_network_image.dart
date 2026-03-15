import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/core/ui/media/image_size_bucket.dart';
import 'package:provider/provider.dart';

class AppNetworkImage extends StatefulWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    required this.imageWidth,
    required this.imageHeight,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
    this.onImageLoading,
  }) : _fullResolution = false;

  const AppNetworkImage.fullResolution({
    super.key,
    required this.url,
    required this.imageWidth,
    required this.imageHeight,
    this.fit = BoxFit.cover,
    this.onImageLoading,
  }) : width = 0,
       height = 0,
       _fullResolution = true;

  final String url;
  final double width;
  final double height;
  final int imageWidth;
  final int imageHeight;

  /// How to inscribe the image into the space allocated during layout.
  final BoxFit fit;

  final void Function(bool isLoading)? onImageLoading;

  /// Whether to load the image at its full resolution, ignoring the device
  /// pixel ratio and logical dimensions.
  final bool _fullResolution;

  @override
  State<AppNetworkImage> createState() => _AppNetworkImageState();
}

class _AppNetworkImageState extends State<AppNetworkImage> {
  @override
  Widget build(BuildContext context) {
    assert(
      widget.width.isFinite && widget.height.isFinite,
      'Invalid image dimensions: $widget.width x $widget.height',
    );
    // debugInvertOversizedImages = true;

    final cacheImageProvider = CachedNetworkImageProvider(
      widget.url,
      cacheManager: context.read(),
    );

    if (widget._fullResolution) {
      return Image(image: cacheImageProvider, fit: widget.fit);
    }

    final bucketSize = ImageSizeBucket.resolveAndClamp(
      logicalWidth: widget.width,
      logicalHeight: widget.height,
      devicePixelRatio: MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0,
    );

    final resizeImageProvider = ResizeImage(
      cacheImageProvider,
      width: bucketSize.width,
      height: bucketSize.height,
      policy: ResizeImagePolicy.fit,
    );

    return Image(
      image: resizeImageProvider,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      frameBuilder: (_, child, frame, wasSynchronouslyLoaded) {
        final loaded = frame != null || wasSynchronouslyLoaded;

        widget.onImageLoading?.call(!loaded);

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

        const child = Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Si è verificato un errore durante il caricamento.',
            overflow: TextOverflow.fade,
            maxLines: 3,
            style: TextStyle(color: color),
          ),
        );

        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: EmptyView(
            icon: const Icon(Symbols.image_not_supported, color: color),
            text: widget.height > 148 ? child : null,
          ),
        );
      },
    );
  }
}
