import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/domain/models/event_content.dart';
import 'package:moliseis/ui/core/themes/text_styles.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

class EventContentStartDateTime extends StatelessWidget {
  const EventContentStartDateTime(
    this.content, {
    super.key,
    this.iconColor,
    this.textColor,
  });

  final EventContent content;
  final Color? iconColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? context.colorScheme.primary;

    final textStyle = AppTextStyles.subtitle(
      context,
    )?.copyWith(color: textColor);

    final localizations = MaterialLocalizations.of(context);

    return Flex(
      direction: Axis.horizontal,
      mainAxisSize: MainAxisSize.min,
      spacing: 4.0,
      children: <Widget>[
        Icon(Symbols.calendar_month, size: 18.0, color: color),
        Flexible(
          flex: 2,
          child: Text(
            localizations.formatMediumDate(content.startDate),
            style: textStyle,
            softWrap: false,
            overflow: TextOverflow.fade,
          ),
        ),
        const SizedBox(width: 4.0),
        Icon(Symbols.schedule, size: 18.0, color: color),
        Flexible(
          child: Text(
            localizations.formatTimeOfDay(
              TimeOfDay.fromDateTime(content.startDate),
            ),
            style: textStyle,
            softWrap: false,
            overflow: TextOverflow.fade,
          ),
        ),
      ],
    );
  }
}
