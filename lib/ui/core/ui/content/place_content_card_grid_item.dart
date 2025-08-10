import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/core/content_base.dart';
import 'package:moliseis/ui/core/themes/shapes.dart';
import 'package:moliseis/ui/core/ui/cards/card_base.dart';
import 'package:moliseis/ui/core/ui/content/content_name_and_city.dart';
import 'package:moliseis/ui/core/ui/custom_image.dart';

class PlaceContentCardGridItem extends StatelessWidget {
  const PlaceContentCardGridItem(
    this.content, {
    super.key,
    this.width,
    this.height,
    this.color,
    this.elevation,
    this.onPressed,
    this.actions = const <Widget>[],
  });

  final ContentBase content;

  final double? width;

  final double? height;

  /// See [CardBase.color].
  final Color? color;

  /// See [CardBase.elevation].
  final double? elevation;

  /// See [CardBase.onPressed].
  final VoidCallback? onPressed;

  /// See [CardBase.actions].
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return CardBase(
      width: width,
      height: height,
      color: color,
      elevation: elevation,
      onPressed: onPressed,
      actions: actions,
      actionAlignment: CardBaseActionAlignment.start,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4.0,
        children: <Widget>[
          Flexible(
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
            child: ContentNameAndCity(
              name: content.name,
              cityName: content.city.target?.name,
            ),
          ),
        ],
      ),
    );
  }
}
