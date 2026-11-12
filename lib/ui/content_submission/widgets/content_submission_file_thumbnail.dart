import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:moliseis/ui/core/utils/content_submission_asset_size.dart';

/// Renders a staged local photo without distorting its decoded aspect ratio.
///
/// The decode is bounded to the thumbnail's physical size; [BoxFit.cover]
/// crops the displayed square without stretching the source pixels.
class ContentSubmissionFileThumbnail extends StatelessWidget {
  /// Creates a preview of the unmodified staged [file].
  const ContentSubmissionFileThumbnail({required this.file, super.key});

  /// Staged image file. This widget never alters its contents.
  final File file;

  @override
  Widget build(BuildContext context) {
    final size = contentSubmissionAssetSize;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Image(
      image: ResizeImage(
        FileImage(file),
        width: (size.width * dpr).ceil(),
        height: (size.height * dpr).ceil(),
        policy: ResizeImagePolicy.fit,
      ),
      width: size.width,
      height: size.height,
      fit: BoxFit.cover,
    );
  }
}
