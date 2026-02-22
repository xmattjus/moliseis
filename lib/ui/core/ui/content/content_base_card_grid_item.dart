import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/ui/core/ui/cards/card_base.dart';
import 'package:moliseis/ui/core/ui/content/content_name_and_city.dart';
import 'package:moliseis/ui/core/ui/custom_image.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

class ContentBaseCardGridItem extends StatelessWidget {
  final ContentBase content;
  final double? width;
  final Color? color;
  final void Function(ContentBase content)? onPressed;
  final Widget? supportingText;
  final Widget? trailing;

  const ContentBaseCardGridItem(
    this.content, {
    super.key,
    this.width,
    this.color,
    this.onPressed,
    this.supportingText,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final appShapes = context.appShapes;

    return Stack(
      children: <Widget>[
        CardBase.filled(
          shape: RoundedRectangleBorder(
            borderRadius: appShapes.circular.cornerMedium,
            side: BorderSide(
              color: context.appColors.modalBorderColor,
              width: context.appSizes.borderSide.medium,
            ),
          ),
          width: width,
          color: color,
          onPressed: onPressed != null ? () => onPressed!(content) : null,
          child: Stack(
            children: <Widget>[
              if (content.media.isNotEmpty)
                SizedBox(
                  child: LayoutBuilder(
                    builder: (_, constraints) => ClipPath(
                      clipper: ShapeBorderClipper(
                        shape: RoundedRectangleBorder(
                          borderRadius: appShapes.circular.cornerMedium,
                        ),
                      ),
                      child: CustomImage.network(
                        content.media.first.url,
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        imageWidth: content.media.first.width,
                        imageHeight: content.media.first.height,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              Positioned(
                bottom: 8.0,
                left: 8.0,
                right: 8.0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 8.0,
                  children: <Widget>[
                    ContentNameAndCity(
                      name: content.name,
                      cityName: content.city.target?.name,
                      color: Colors.white,
                    ),
                    if (supportingText != null) supportingText!,
                  ],
                ),
              ),
            ],
          ),
        ),
        if (trailing != null)
          Positioned(
            top: 8.0,
            right: 8.0,
            child: SizedBox(width: width, child: trailing),
          ),
      ],
    );
  }
}
