import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/core/content_base.dart';
import 'package:moliseis/ui/core/themes/shapes.dart';
import 'package:moliseis/ui/core/ui/content/content_name_and_city.dart';
import 'package:moliseis/ui/core/ui/custom_image.dart';

// TODO(xmattjus): draw inkwell on top of the image.
class ContentBaseListItem extends StatelessWidget {
  final ContentBase content;
  final void Function(ContentBase content)? onPressed;
  final Widget? verticalTrailing;
  final Widget? horizontalTrailing;

  const ContentBaseListItem(
    this.content, {
    super.key,
    this.onPressed,
    this.verticalTrailing,
    this.horizontalTrailing,
  });

  @override
  Widget build(BuildContext context) {
    final minHeight = verticalTrailing != null ? 96.0 : 88.0;
    final textScaleMinFactor = verticalTrailing != null ? 1.0 : 1.5;
    final textScaleOffset = verticalTrailing != null ? 50.0 : 30.0;

    final textScaleFactor =
        MediaQuery.textScalerOf(
          context,
        ).clamp(maxScaleFactor: 3.0).scale(minHeight) /
        minHeight;

    // Calculates the height this widget should have based on the device text
    // size.
    final finalHeight = textScaleFactor > textScaleMinFactor
        ? ((textScaleFactor - 1) * textScaleOffset) + minHeight
        : minHeight;

    return InkWell(
      onTap: onPressed != null ? () => onPressed!(content) : null,
      child: Container(
        height: finalHeight,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (content.media.isNotEmpty)
              ClipPath(
                clipper: ShapeBorderClipper(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Shapes.medium),
                  ),
                ),
                child: CustomImage.network(
                  content.media.first.url,
                  width: 72.0,
                  height: 72.0,
                  imageWidth: content.media.first.width,
                  imageHeight: content.media.first.height,
                  fit: BoxFit.cover,
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  16.0,
                  8.0,
                  8.0,
                  8.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 8.0,
                  children: <Widget>[
                    ContentNameAndCity(
                      name: content.name,
                      cityName: content.city.target?.name,
                    ),
                    if (verticalTrailing != null) verticalTrailing!,
                  ],
                ),
              ),
            ),
            if (horizontalTrailing != null) horizontalTrailing!,
          ],
        ),
      ),
    );
  }
}
