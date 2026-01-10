import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/ui/cards/card_base.dart';

/// A customizable information card widget that displays content in a structured layout.
///
/// This widget displays information with a header, an icon-title row, and optional footer content.
/// It uses the app's secondary container color scheme and provides optional tap functionality.
///
/// The layout consists of:
/// - A header section at the top
/// - A middle section with an icon and title in a row
/// - An optional footer section at the bottom
///
/// Example usage:
/// ```dart
/// InformationCard(
///   header: Text('Location'),
///   icon: Icon(Icons.location_on),
///   title: Text('Molise, Italy'),
///   footer: Text('Additional details'),
///   onPressed: () => print('Card tapped'),
/// )
/// ```
class InformationCard extends StatelessWidget {
  /// Callback function executed when the card is tapped.
  /// If null, the card will not be interactive.
  final void Function()? onPressed;

  /// Widget displayed at the top of the card, typically used for category or type information.
  /// This content is styled with bold text and limited to a single line.
  final Widget header;

  /// Icon widget displayed before the main title in the middle section.
  /// The icon will inherit the card's foreground color.
  final Widget icon;

  /// Main title widget displayed next to the icon in the middle section.
  /// This content can span up to 2 lines with ellipsis overflow.
  final Widget title;

  /// Optional widget displayed at the bottom of the card for additional information.
  /// If null, an empty text with small body style will be displayed as placeholder.
  final Widget? footer;

  /// Creates an information card with the specified content and styling.
  ///
  /// The [header], [icon], and [title] parameters are required.
  /// The [footer] and [onPressed] parameters are optional.
  const InformationCard({
    super.key,
    this.onPressed,
    required this.header,
    required this.icon,
    required this.title,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultTextStyle = theme.textTheme.bodyMedium;
    final backgroundColor = theme.colorScheme.secondaryContainer;
    final foregroundColor = theme.colorScheme.onSecondaryContainer;

    return CardBase.filled(
      color: backgroundColor,
      onPressed: onPressed,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            DefaultTextStyle.merge(
              style: defaultTextStyle?.copyWith(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              child: header,
            ),
            const Spacer(),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              spacing: 4.0,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: IconTheme.merge(
                    data: IconThemeData(color: foregroundColor),
                    child: icon,
                  ),
                ),
                Expanded(
                  child: DefaultTextStyle.merge(
                    style: defaultTextStyle,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                    child: title,
                  ),
                ),
              ],
            ),
            footer ?? Text('', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
