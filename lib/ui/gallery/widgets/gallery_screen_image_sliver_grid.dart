import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/attraction/attraction.dart';
import 'package:moliseis/domain/models/attraction/attraction_sort.dart';
import 'package:moliseis/domain/models/molis_image/molis_image.dart';
import 'package:moliseis/ui/core/ui/custom_image.dart';
import 'package:moliseis/ui/core/ui/custom_ink_well.dart';
import 'package:moliseis/ui/gallery/view_models/gallery_view_model.dart';
import 'package:moliseis/ui/gallery/widgets/gallery_preview_modal.dart';
import 'package:provider/provider.dart';

class GalleryScreenImageSliverGrid extends StatelessWidget {
  /// A sliver that creates a 2D array of widgets.
  const GalleryScreenImageSliverGrid({
    super.key,
    required this.attraction,
    required this.sortBy,
  });

  final Attraction attraction;
  final AttractionSort sortBy;

  @override
  Widget build(BuildContext context) {
    return Selector<GalleryViewModel, List<MolisImage>>(
      builder: (_, images, _) {
        return SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 4.0,
            crossAxisSpacing: 4.0,
          ),
          delegate: SliverChildBuilderDelegate((_, index) {
            return Stack(
              children: <Widget>[
                LayoutBuilder(
                  builder: (_, constraints) {
                    return CustomImage.network(
                      attraction.images[index].url,
                      width: constraints.biggest.width,
                      height: constraints.biggest.height,
                      imageWidth: attraction.images[index].width.toDouble(),
                      imageHeight: attraction.images[index].height.toDouble(),
                      fit: BoxFit.cover,
                    );
                  },
                ),
                Material(
                  type: MaterialType.transparency,
                  child: CustomInkWell(
                    onPressed: () async {
                      final initialIndex = images.indexWhere(
                        (element) => element.id == attraction.images[index].id,
                      );

                      const modal = GalleryPreviewModal();
                      await modal(
                        context: context,
                        images: images,
                        initialIndex: initialIndex,
                      );
                    },
                    shape: const RoundedRectangleBorder(),
                  ),
                ),
              ],
            );
          }, childCount: attraction.images.length),
        );
      },
      selector: (_, controller) => controller.getAllImages(sortBy),
    );
  }
}
