import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/ui/core/ui/blurred_box.dart';
import 'package:moliseis/ui/core/ui/content/content_base_card_grid_item.dart';
import 'package:moliseis/ui/event/widgets/components/event_formatted_date_time.dart';
import 'package:moliseis/ui/favourite/widgets/favourite_button.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

class ContentEventCardGridItem extends StatelessWidget {
  const ContentEventCardGridItem({
    required this.event,
    required this.onPressed,
    super.key,
  });

  final Event event;
  final void Function(ContentBase content) onPressed;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ContentBaseCardGridItem(
          event,
          width: constraints.minWidth,
          onPressed: onPressed,
          trailing: Wrap(
            alignment: WrapAlignment.end,
            spacing: 4,
            runSpacing: 4,
            children: <Widget>[
              BlurredBox(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 8,
                  ),
                  child: EventFormattedDateTime(
                    event: event,
                    iconColor: Colors.white,
                    textColor: Colors.white,
                  ),
                ),
              ),
              FavouriteButton(
                color: Colors.white,
                content: event,
                borderRadius: context.appShapes.circular.cornerSmall,
              ),
            ],
          ),
        );
      },
    );
  }
}
