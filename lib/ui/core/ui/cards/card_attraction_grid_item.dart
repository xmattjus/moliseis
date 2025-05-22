import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/ui/attraction_and_place_names.dart';
import 'package:moliseis/ui/core/ui/cards/base_attraction_card.dart';
import 'package:moliseis/ui/core/ui/custom_image.dart';
import 'package:moliseis/ui/core/ui/skeletons/card_skeleton_grid_item.dart';
import 'package:moliseis/utils/constants.dart';

class CardAttractionGridItem extends StatelessWidget {
  const CardAttractionGridItem(
    this.attractionId, {
    super.key,
    this.color,
    this.placeholderColor,
    this.elevation,
    this.onPressed,
  });

  final int attractionId;

  /// See [BaseAttractionCard.color].
  final Color? color;

  /// See [BaseAttractionCard.placeholderColor].
  final Color? placeholderColor;

  /// See [BaseAttractionCard.elevation].
  final double? elevation;

  /// See [BaseAttractionCard.onPressed].
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return BaseAttractionCard(
      attractionId,
      color: color,
      placeholderColor: placeholderColor,
      elevation: elevation,
      onPressed: onPressed,
      onLoading: () => const CardSkeletonGridItem(),
      builder: (attraction, image, place) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4.0,
          children: [
            Flexible(
              child: LayoutBuilder(
                builder: (_, constraints) {
                  return ClipPath(
                    clipper: ShapeBorderClipper(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(kCardCornerRadius),
                      ),
                    ),
                    child: CustomImage.network(
                      image.url,
                      width: constraints.biggest.width,
                      height: constraints.biggest.height,
                      imageWidth: image.width.toDouble(),
                      imageHeight: image.height.toDouble(),
                      fit: BoxFit.cover,
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(8.0, 0, 8.0, 8.0),
              child: AttractionAndPlaceNames(
                name: attraction.name,
                placeName: place.name,
              ),
            ),
          ],
        );
      },
    );
  }
}
