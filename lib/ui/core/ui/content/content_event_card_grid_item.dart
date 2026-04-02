import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/event_content.dart';
import 'package:moliseis/ui/core/ui/blurred_box.dart';
import 'package:moliseis/ui/core/ui/content/content_base_card_grid_item.dart';
import 'package:moliseis/ui/event/widgets/components/event_formatted_date_time.dart';
import 'package:moliseis/ui/favourite/widgets/favourite_button.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

class ContentEventCardGridItem extends StatelessWidget {
  final EventContent event;
  final void Function(ContentBase content) onPressed;

  const ContentEventCardGridItem({
    super.key,
    required this.event,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    return ContentBaseCardGridItem(
      event,
      width: kGridViewCardWidth,
      onPressed: onPressed,
      trailing: Wrap(
        alignment: WrapAlignment.end,
        spacing: 4.0,
        runSpacing: 4.0,
        children: <Widget>[
          Tooltip(
            message:
                'Data di inizio evento '
                '${localizations.formatMediumDate(event.startDate)}',
            child: BlurredBox(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 10.0,
                  horizontal: 8.0,
                ),
                child: EventFormattedDateTime(event: event),
              ),
            ),
          ),
          BlurredBox(
            child: FavouriteButton(
              color: Colors.white,
              content: event,
              borderRadius: context.appShapes.circular.cornerSmall,
            ),
          ),
        ],
      ),
    );
  }
}
