import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/core/content_base.dart';
import 'package:moliseis/domain/models/event/event_content.dart';
import 'package:moliseis/ui/core/themes/shapes.dart';
import 'package:moliseis/ui/core/ui/cards/card_base.dart';
import 'package:moliseis/ui/core/ui/content/content_name_and_city.dart';
import 'package:moliseis/ui/core/ui/content/event_content_start_date_time.dart';
import 'package:moliseis/ui/core/ui/custom_image.dart';
import 'package:moliseis/ui/core/ui/empty_box.dart';

class EventContentCardListItem extends StatelessWidget {
  const EventContentCardListItem(
    this.content, {
    super.key,
    this.color,
    this.elevation,
    this.onPressed,
    this.actions = const <Widget>[],
  });

  final EventContent content;

  /// See [CardBase.color].
  final Color? color;

  /// See [CardBase.elevation].
  final double? elevation;

  final void Function(ContentBase content)? onPressed;

  /// See [CardBase.actions].
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    // The minimum height this widget must have.
    const minHeight = 96.0;

    final textScaleFactor =
        MediaQuery.textScalerOf(
          context,
        ).clamp(maxScaleFactor: 3.0).scale(minHeight) /
        minHeight;

    // Calculates the height this widget should have based on the device text
    // size.
    final finalHeight = textScaleFactor > 1.0
        ? ((textScaleFactor - 1) * 50) + minHeight
        : minHeight;

    // Calculates the amount of space to pad the content and city names
    // with.
    var additionalEndInset = actions.length * 16.0;

    if (additionalEndInset > 0) additionalEndInset += 16.0;

    return CardBase(
      height: finalHeight,
      color: color,
      elevation: elevation,
      shape: const RoundedRectangleBorder(),
      onPressed: onPressed != null ? () => onPressed!(content) : null,
      actions: actions,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ClipPath(
              clipper: ShapeBorderClipper(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Shapes.medium),
                ),
              ),
              child: content.media.isNotEmpty
                  ? CustomImage.network(
                      content.media.first.url,
                      width: 72.0,
                      height: 72.0,
                      imageWidth: content.media.first.width,
                      imageHeight: content.media.first.height,
                      fit: BoxFit.cover,
                    )
                  : const EmptyBox(),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  16.0,
                  8.0,
                  16.0 + additionalEndInset,
                  8.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ContentNameAndCity(
                      name: content.name,
                      cityName: content.city.target?.name,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: EventContentStartDateTime(content),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
