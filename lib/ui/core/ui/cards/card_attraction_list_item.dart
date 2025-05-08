import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/ui/cards/attraction_card_title_subtitle.dart';
import 'package:moliseis/ui/core/ui/cards/base_attraction_card.dart';
import 'package:moliseis/ui/core/ui/custom_image.dart';
import 'package:moliseis/ui/core/ui/skeletons/card_skeleton_list_item.dart';
import 'package:moliseis/utils/constants.dart';

class CardAttractionListItem extends StatelessWidget {
  const CardAttractionListItem(
    this.attractionId, {
    super.key,
    this.color,
    this.elevation,
    this.onPressed,
    this.actions,
  });

  final int attractionId;

  /// See [BaseAttractionCard.color].
  final Color? color;

  /// See [BaseAttractionCard.elevation].
  final double? elevation;

  /// See [BaseAttractionCard.onPressed].
  final VoidCallback? onPressed;

  /// See [BaseAttractionCard.actions].
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    /// The minimum height this widget must have.
    const minHeight = 88.0;

    /// Calculates the height this widget should have based on the device text
    /// size.
    ///
    /// Defaults to [minHeight] if null.
    final scaledHeight = MediaQuery.maybeTextScalerOf(
      context,
    )?.scale(minHeight);
    final finalHeight = scaledHeight?.clamp(minHeight, 112.0) ?? minHeight;

    /// Calculates the amount of space to pad the attraction and place names
    /// with.
    var additionalEndInset = (actions?.length ?? 0) * 16.0;
    additionalEndInset =
        additionalEndInset == 0.0 ? 0.0 : additionalEndInset + 16.0;

    return BaseAttractionCard(
      attractionId,
      height: finalHeight,
      color: color,
      elevation: elevation,
      shape: const RoundedRectangleBorder(),
      onPressed: onPressed,
      actions: actions,
      onLoading: () => const CardSkeletonListItem(),
      builder: (attraction, image, place) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ClipPath(
                clipper: ShapeBorderClipper(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(kCardCornerRadius),
                  ),
                ),
                child: CustomImage(
                  image,
                  width: 72.0,
                  height: 72.0,
                  fit: BoxFit.cover,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    16.0,
                    8.0,
                    16.0 + additionalEndInset,
                    8.0,
                  ),
                  child: AttractionCardTitleSubtitle(
                    attraction.name,
                    place.name,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
