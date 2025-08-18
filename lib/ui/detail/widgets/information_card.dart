import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/ui/cards/card_base.dart';
import 'package:moliseis/ui/core/ui/empty_box.dart';

class InformationCard extends StatelessWidget {
  final void Function()? onPressed;
  final Widget top;

  /// Typically an icon or an image that represents the content.
  final Widget leading;
  final Widget title;
  final Widget? subtitle;
  final bool useBoldSubtitle;

  const InformationCard({
    super.key,
    this.onPressed,
    required this.top,
    required this.leading,
    required this.title,
    this.subtitle,
    this.useBoldSubtitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultTextStyle = theme.textTheme.bodyMedium;
    final backgroundColor = theme.colorScheme.secondaryContainer;
    final foregroundColor = theme.colorScheme.onSecondaryContainer;

    final subtitle = useBoldSubtitle
        ? DefaultTextStyle.merge(
            style: defaultTextStyle?.copyWith(fontWeight: FontWeight.bold),
            child: this.subtitle ?? const EmptyBox(),
          )
        : this.subtitle ?? const EmptyBox();

    final rightPart = Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: 2.0,
        children: <Widget>[title, subtitle],
      ),
    );

    return CardBase.filled(
      color: backgroundColor,
      onPressed: onPressed,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12.0, 0, 16.0, 0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            DefaultTextStyle.merge(
              style: defaultTextStyle?.copyWith(fontWeight: FontWeight.bold),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: top,
              ),
              softWrap: true,
              maxLines: 2,
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              spacing: 12.0,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: IconTheme.merge(
                    data: IconThemeData(size: 24.0, color: foregroundColor),
                    child: leading,
                  ),
                ),
                DefaultTextStyle.merge(
                  style: defaultTextStyle,
                  child: rightPart,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
