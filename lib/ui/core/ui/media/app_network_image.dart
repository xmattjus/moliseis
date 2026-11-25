import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/ui/core/ui/media/bounded_cover_image.dart';
import 'package:moliseis/ui/core/ui/media/image_error_placeholder.dart';
import 'package:moliseis/ui/core/ui/media/image_size_bucket.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:provider/provider.dart';

/// Displays the original cached URL with a bucketed, proportional decode.
///
/// Cover requests have a separate 1728-pixel output ceiling; other fits retain
/// stock fit decoding. Buckets affect decoded identity, never disk keys.
/// Original URLs are retained.
/// Existing multiframe behavior and the bounded loading fade remain.
class AppNetworkImage extends StatefulWidget {
  /// Uses logical [width]/[height] and DPR to select the unchanged size bucket.
  const AppNetworkImage({
    required this.url,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
    this.onImageLoading,
    super.key,
  }) : _fullResolution = false;

  /// Keeps the original unresized request for gallery zoom and pan.
  const AppNetworkImage.fullResolution({
    required this.url,
    this.fit = BoxFit.cover,
    this.onImageLoading,
    super.key,
  }) : width = 0,
       height = 0,
       _fullResolution = true;

  /// Original source and persistent-cache identity.
  final String url;

  /// Logical display width of a bounded request.
  final double width;

  /// Logical display height of a bounded request.
  final double height;

  /// How to inscribe the decoded image into its display rectangle.
  final BoxFit fit;

  /// Reports request transitions; success and failure both settle false.
  ///
  /// Notifications can occur during image building, including synchronous hits.
  /// Unchanged rebuilds and frames do not replay the same loading value.
  final ValueChanged<bool>? onImageLoading;

  final bool _fullResolution;

  @override
  State<AppNetworkImage> createState() => _AppNetworkImageState();
}

class _AppNetworkImageState extends State<AppNetworkImage> {
  Object? _request;
  Object _generation = Object();
  bool? _loading;
  bool _loggedError = false;

  void _publish(Object generation, bool loading) {
    if (!mounted) return;
    if (!identical(generation, _generation) || _loading == loading) return;
    _loading = loading;
    widget.onImageLoading?.call(loading);
  }

  @override
  Widget build(BuildContext context) {
    assert(
      widget.width.isFinite && widget.height.isFinite,
      'Image dimensions must be finite.',
    );
    final manager = context.read<CacheManager>();
    final logger = context.read<Logger?>();
    final fullResolution = widget._fullResolution;
    final width = widget.width;
    final height = widget.height;
    final source = CachedNetworkImageProvider(
      widget.url,
      cacheManager: manager,
    );
    final bucket = widget._fullResolution
        ? null
        : ImageSizeBucket.resolveAndClamp(
            logicalWidth: widget.width,
            logicalHeight: widget.height,
            devicePixelRatio:
                MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0,
          );
    final request = (
      source,
      manager,
      bucket,
      widget.fit,
      widget._fullResolution,
    );
    if (_request != request) {
      _request = request;
      _generation = Object();
      _loading = null;
      _loggedError = false;
    }
    final generation = _generation;
    // Explicit type keeps the three differently keyed providers covariant.
    // ignore: omit_local_variable_types
    final ImageProvider provider = bucket == null
        ? source
        : widget.fit == BoxFit.cover
        ? BoundedCoverImage(
            source,
            width: bucket.width!,
            height: bucket.height!,
          )
        : ResizeImage(
            source,
            width: bucket.width,
            height: bucket.height,
            policy: ResizeImagePolicy.fit,
          );

    return Image(
      key: ObjectKey(generation),
      image: provider,
      width: fullResolution ? null : width,
      height: fullResolution ? null : height,
      fit: widget.fit,
      frameBuilder: (_, child, frame, wasSynchronouslyLoaded) {
        if (!mounted) return child;
        if (!identical(generation, _generation)) return child;
        final loaded = frame != null || wasSynchronouslyLoaded;
        _publish(generation, !loaded);
        if (fullResolution || wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: loaded ? 1 : 0,
          duration: Durations.extralong4,
          curve: Curves.easeInOutCubicEmphasized,
          child: child,
        );
      },
      errorBuilder: (context, error, stackTrace) {
        if (!mounted) return const SizedBox.shrink();
        if (!identical(generation, _generation)) return const SizedBox.shrink();
        _publish(generation, false);
        if (!_loggedError) {
          _loggedError = true;
          logger?.log(
            ImageLoadFailed(url: source.url),
            error: error,
            stackTrace: stackTrace,
          );
        }
        return SizedBox(
          width: fullResolution ? null : width,
          height: fullResolution ? null : height,
          child: const ImageErrorPlaceholder(),
        );
      },
    );
  }
}
