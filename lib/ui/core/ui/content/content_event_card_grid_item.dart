import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/event_content.dart';
import 'package:moliseis/ui/core/ui/blurred_box.dart';
import 'package:moliseis/ui/core/ui/content/content_base_card_grid_item.dart';
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
        verticalDirection: VerticalDirection.up,
        children: <Widget>[
          Tooltip(
            message:
                'Data di inizio evento '
                '${localizations.formatMediumDate(event.startDate)}',
            child: BlurredBox(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 4.0,
                  children: <Widget>[
                    const SizedBox(width: 8.0),
                    const Icon(Symbols.event, color: Colors.white),
                    Text(
                      localizations.formatMediumDate(event.startDate),
                      style: context.defaultTextStyle.style.copyWith(
                        color: Colors.white,
                      ),
                      softWrap: false,
                      overflow: TextOverflow.fade,
                    ),
                    const SizedBox(width: 8.0),
                  ],
                ),
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
