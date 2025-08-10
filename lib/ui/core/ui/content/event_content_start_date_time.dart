import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/event/event_content.dart';
import 'package:moliseis/ui/core/themes/text_styles.dart';

class EventContentStartDateTime extends StatelessWidget {
  const EventContentStartDateTime(this.content, {super.key});

  final EventContent content;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    final textStyle = CustomTextStyles.subtitle(context);

    final localizations = MaterialLocalizations.of(context);

    return Flex(
      direction: Axis.horizontal,
      mainAxisSize: MainAxisSize.min,
      spacing: 4.0,
      children: <Widget>[
        Icon(Icons.calendar_month_outlined, size: 18.0, color: color),
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
        Icon(Icons.schedule_outlined, size: 18.0, color: color),
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
