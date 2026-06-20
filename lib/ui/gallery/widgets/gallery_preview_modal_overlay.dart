import 'package:cached_network_image_ce/cached_network_image.dart'
    show CacheManager;
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:moliseis/data/services/url_launch_service.dart';
import 'package:moliseis/domain/models/media.dart';
import 'package:moliseis/ui/core/themes/app_theme_data.dart';
import 'package:moliseis/ui/core/themes/system_ui_overlay_styles.dart';
import 'package:moliseis/ui/core/ui/app_page_indicator.dart';
import 'package:moliseis/ui/core/ui/content/content_name_and_city.dart';
import 'package:moliseis/ui/core/ui/custom_appbar.dart';
import 'package:moliseis/ui/core/ui/custom_snack_bar.dart';
import 'package:moliseis/ui/core/ui/empty_box.dart';
import 'package:moliseis/ui/core/ui/horizontal_button_list.dart';
import 'package:moliseis/ui/core/ui/linear_gradient_background.dart';
import 'package:moliseis/ui/core/ui/link_text_button.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

part '_gallery_preview_modal_overlay_content.dart';

class GalleryPreviewModalOverlay extends StatelessWidget {
  const GalleryPreviewModalOverlay({
    required this.media,
    required this.index,
    required this.itemCount,
    super.key,
  });

  final Media media;
  final int index;
  final int itemCount;

  Future<void> _onSharePressed(BuildContext context) async {
    try {
      final cache = context.read<CacheManager>();
      final file = await cache.getSingleFile(media.url);
      final sharedImage = XFile(file.path, mimeType: 'image/*');
      await SharePlus.instance.share(ShareParams(files: [sharedImage]));
    } on Exception catch (exception, stackTrace) {
      if (context.mounted) {
        context.read<Logger?>()?.log(
          const ImageSharingFailed(),
          error: exception,
          stackTrace: stackTrace,
        );

        showSnackBar(
          context: context,
          textContent:
              'Si è verificato un errore durante la condivisione, riprova.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: SystemUiOverlayStyles(context).gallery,
      child: Theme(
        data: AppThemeData.photoViewer,
        child: _GalleryPreviewModalOverlayContent(
          eventOrPlaceName: media.areaName,
          title: media.title ?? '',
          author: media.author ?? '',
          license: media.license ?? '',
          licenseUrl: media.licenseUrl ?? '',
          cityName: media.cityName,
          onSharePressed: () async => _onSharePressed(context),
          index: index,
          itemCount: itemCount,
        ),
      ),
    );
  }
}
