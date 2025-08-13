import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/core/content_base.dart';
import 'package:moliseis/ui/core/themes/shapes.dart';
import 'package:moliseis/ui/core/ui/cards/card_base.dart';
import 'package:moliseis/ui/core/ui/content/content_name_and_city.dart';
import 'package:moliseis/ui/core/ui/custom_image.dart';

class ContentBaseCardGridItem extends StatelessWidget {
  final ContentBase content;
  final double? width;
  final void Function(ContentBase content)? onPressed;
  final Widget? verticalTrailing;
  final Widget? horizontalTrailing;

  const ContentBaseCardGridItem(
    this.content, {
    super.key,
    this.width,
    this.onPressed,
    this.verticalTrailing,
    this.horizontalTrailing,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        CardBase.filled(
          width: width,
          onPressed: onPressed != null ? () => onPressed!(content) : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4.0,
            children: <Widget>[
              if (content.media.isNotEmpty)
                AspectRatio(
                  aspectRatio: 3 / 1.2,
                  child: LayoutBuilder(
                    builder: (_, constraints) {
                      return ClipPath(
                        clipper: ShapeBorderClipper(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(Shapes.medium),
                          ),
                        ),
                        child: CustomImage.network(
                          content.media.first.url,
                          width: constraints.biggest.width,
                          height: constraints.biggest.height,
                          imageWidth: content.media.first.width,
                          imageHeight: content.media.first.height,
                          fit: BoxFit.cover,
                        ),
                      );
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(8.0, 0, 8.0, 8.0),
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
            ],
          ),
        ),
        if (horizontalTrailing != null)
          Positioned(
            top: 8.0,
            right: 8.0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(Shapes.small),
              ),
              child: horizontalTrailing,
            ),
          ),
      ],
    );
  }
}
