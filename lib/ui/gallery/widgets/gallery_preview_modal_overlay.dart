import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:logging/logging.dart';
import 'package:moliseis/data/services/url_launch_service.dart';
import 'package:moliseis/domain/models/media/media.dart';
import 'package:moliseis/ui/core/themes/system_ui_overlay_styles.dart';
import 'package:moliseis/ui/core/themes/theme_data.dart';
import 'package:moliseis/ui/core/ui/content/content_name_and_city.dart';
import 'package:moliseis/ui/core/ui/custom_appbar.dart';
import 'package:moliseis/ui/core/ui/custom_snack_bar.dart';
import 'package:moliseis/ui/core/ui/empty_box.dart';
import 'package:moliseis/ui/core/ui/horizontal_button_list.dart';
import 'package:moliseis/ui/core/ui/url_text_button.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

part '_gallery_preview_modal_overlay_content.dart';

class GalleryPreviewModalOverlay extends StatelessWidget {
  const GalleryPreviewModalOverlay({super.key, required this.image});

  final Media image;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: SystemUiOverlayStyles(context).gallerySurface,
      child: Theme(
        data: AppThemeData.photoViewer,
        child: _GalleryPreviewModalOverlayContent(
          eventOrPlaceName:
              image.place.target?.name ?? image.event.target?.name ?? '',
          title: image.title ?? '',
          author: image.author ?? '',
          license: image.license ?? '',
          licenseUrl: image.licenseUrl ?? '',
          cityName:
              image.place.target?.city.target?.name ??
              image.event.target?.city.target?.name ??
              '',
          onSharePressed: () async {
            try {
              final cache = DefaultCacheManager();
              final file = await cache.getSingleFile(image.url);
              final sharedImage = XFile(file.path, mimeType: 'image/*');
              await SharePlus.instance.share(ShareParams(files: [sharedImage]));
            } on Exception catch (error, stackTrace) {
              final log = Logger('GalleryPreviewModalOverlay');

              log.warning(
                'An exception occurred during image sharing.',
                error,
                stackTrace,
              );

              if (context.mounted) {
                showSnackBar(
                  context: context,
                  textContent:
                      'Si è verificato un errore durante la condivisione, riprova.',
                );
              }
            }
          },
        ),
      ),
    );
  }
}
