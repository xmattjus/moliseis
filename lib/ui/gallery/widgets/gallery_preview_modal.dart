import 'dart:async' show StreamController;

import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/molis_image/molis_image.dart';
import 'package:moliseis/ui/core/ui/custom_image.dart';
import 'package:moliseis/ui/gallery/widgets/gallery_preview_modal_overlay.dart';
import 'package:provider/provider.dart';
import 'package:swipe_image_gallery/swipe_image_gallery.dart';

class GalleryPreviewModal {
  const GalleryPreviewModal();

  Future<bool?> call({
    required BuildContext context,
    required List<MolisImage> images,
    required int initialIndex,
  }) async {
    if (context.mounted) {
      final StreamController<Widget> streamController = context.read();
      await SwipeImageGallery(
        context: context,
        itemBuilder: (context, index) {
          return CustomImage(
            images[index],
            width: MediaQuery.sizeOf(context).width,
            height: MediaQuery.sizeOf(context).height,
          );
        },
        itemCount: images.length,
        hideStatusBar: false,
        initialIndex: initialIndex,
        overlayController: streamController,
        initialOverlay: GalleryPreviewModalOverlay(image: images[initialIndex]),
        onSwipe: (index) {
          streamController.add(
            GalleryPreviewModalOverlay(image: images[index]),
          );
        },
        useSafeArea: false,
      ).show();

      /// Resolves to true when the SwipeImageGallery dialog has been dismissed.
      return true;
    }

    return null;
  }
}
