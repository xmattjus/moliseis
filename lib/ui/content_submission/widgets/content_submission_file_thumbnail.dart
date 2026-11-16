import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:moliseis/ui/core/ui/media/bounded_cover_image.dart';
import 'package:moliseis/ui/core/ui/media/image_error_placeholder.dart';
import 'package:moliseis/ui/core/utils/content_submission_asset_size.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:provider/provider.dart';

/// Renders a staged photo with proportional decoding and cover cropping.
///
/// The physical target is ceil(86 × DPR); intrinsic resolution and the shared
/// output ceiling can limit detail. This widget never alters its staged file.
class ContentSubmissionFileThumbnail extends StatefulWidget {
  /// Creates a preview of the unmodified staged [file].
  const ContentSubmissionFileThumbnail({required this.file, super.key});

  /// Staged image file owned by the submission flow.
  final File file;

  @override
  State<ContentSubmissionFileThumbnail> createState() =>
      _ContentSubmissionFileThumbnailState();
}

class _ContentSubmissionFileThumbnailState
    extends State<ContentSubmissionFileThumbnail> {
  BoundedCoverImage? _request;
  Object _generation = Object();
  bool _loggedError = false;

  @override
  Widget build(BuildContext context) {
    final size = contentSubmissionAssetSize;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final provider = BoundedCoverImage(
      FileImage(widget.file),
      width: (size.width * dpr).ceil(),
      height: (size.height * dpr).ceil(),
    );
    if (_request != provider) {
      _request = provider;
      _generation = Object();
      _loggedError = false;
    }
    final generation = _generation;
    return Image(
      key: ObjectKey(generation),
      image: provider,
      width: size.width,
      height: size.height,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        if (!mounted) return const SizedBox.shrink();
        if (!identical(generation, _generation)) return const SizedBox.shrink();
        if (!_loggedError) {
          _loggedError = true;
          context.read<Logger?>()?.log(
            const ImageLoadFailed(url: 'staged-local-image'),
            error: error,
            stackTrace: stackTrace,
          );
        }
        return SizedBox.fromSize(
          size: size,
          child: const ImageErrorPlaceholder(),
        );
      },
    );
  }
}
