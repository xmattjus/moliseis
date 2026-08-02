import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/ui/core/ui/cards/card_base.dart';
import 'package:moliseis/ui/core/ui/content/content_name_and_city.dart';
import 'package:moliseis/ui/core/ui/media/app_network_image.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

class ContentBaseCardGridItem extends StatelessWidget {
  const ContentBaseCardGridItem(
    this.content, {
    super.key,
    this.width,
    this.color,
    this.onPressed,
    this.supportingText,
    this.trailing,
  });

  final ContentBase content;
  final double? width;
  final Color? color;
  final void Function(ContentBase content)? onPressed;
  final Widget? supportingText;
  final Widget? trailing;

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
                      child: AppNetworkImage(
                        url: content.media.first.url,
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        imageWidth: content.media.first.width,
                        imageHeight: content.media.first.height,
                      ),
                    ),
                  ),
                ),
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 8,
                  children: <Widget>[
                    ContentNameAndCity(
                      name: content.name,
                      cityName: content.city?.name,
                      color: Colors.white,
                    ),
                    ?supportingText,
                  ],
                ),
              ),
            ],
          ),
        ),
        if (trailing != null)
          Positioned(
            top: 8,
            right: 8,
            width: width,
            child: trailing!,
          ),
      ],
    );
  }
}
