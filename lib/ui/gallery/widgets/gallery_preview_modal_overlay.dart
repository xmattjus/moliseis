import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:moliseis/domain/models/molis_image/molis_image.dart';
import 'package:moliseis/main.dart';
import 'package:moliseis/ui/core/themes/theme_data.dart';
import 'package:moliseis/ui/core/ui/button_list.dart';
import 'package:moliseis/ui/core/ui/custom_appbar.dart';
import 'package:moliseis/ui/core/ui/custom_rich_text.dart';
import 'package:moliseis/ui/core/ui/custom_snack_bar.dart';
import 'package:moliseis/ui/core/ui/url_text_button.dart';
import 'package:moliseis/utils/app_url_launcher.dart';
import 'package:moliseis/utils/log_events.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

part '_gallery_preview_modal_overlay_content.dart';

class GalleryPreviewModalOverlay extends StatelessWidget {
  const GalleryPreviewModalOverlay({super.key, required this.image});

  final MolisImage image;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppThemeData.photoViewer,
      child: _GalleryPreviewModalOverlayContent(
        attractionName: image.attraction.target!.name,
        title: image.title,
        author: image.author,
        license: image.license,
        licenseUrl: image.licenseUrl,
        placeName: image.attraction.target!.place.target!.name,
        attractionId: image.attraction.target!.id,
        onSharePressed: () async {
          try {
            final cache = DefaultCacheManager();
            final file = await cache.getSingleFile(image.url);
            final sharedImage = XFile(file.path, mimeType: 'image/*');
            await SharePlus.instance.share(ShareParams(files: [sharedImage]));
          } on Exception catch (error) {
            logger.severe(LogEvents.imageSharingError, error);
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
    );
  }
}
