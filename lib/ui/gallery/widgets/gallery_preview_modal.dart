// ignore_for_file: avoid_classes_with_only_static_members

import 'dart:async' show StreamController;

import 'package:flutter/material.dart';
import 'package:moliseis/data/sources/media.dart';
import 'package:moliseis/ui/core/ui/media/app_network_image.dart';
import 'package:moliseis/ui/gallery/widgets/gallery_preview_modal_overlay.dart';
import 'package:swipe_image_gallery/swipe_image_gallery.dart';

class GalleryPreviewModal {
  static Future<bool?> show({
    required BuildContext context,
    required List<Media> media,
    required int initialIndex,
  }) async {
    if (context.mounted) {
      final streamController = StreamController<Widget>();
      await SwipeImageGallery(
        context: context,
        itemBuilder: (context, index) {
          return AppNetworkImage.fullResolution(
            url: media[index].url,
            imageWidth: media[index].width,
            imageHeight: media[index].height,
            fit: BoxFit.contain,
          );
        },
        itemCount: media.length,
        hideStatusBar: false,
        initialIndex: initialIndex,
        overlayController: streamController,
        initialOverlay: GalleryPreviewModalOverlay(
          media: media[initialIndex],
          index: initialIndex,
          itemCount: media.length,
        ),
        onSwipe: (index) {
          streamController.add(
            GalleryPreviewModalOverlay(
              media: media[index],
              index: index,
              itemCount: media.length,
            ),
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
