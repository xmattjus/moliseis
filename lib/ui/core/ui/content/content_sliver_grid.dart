import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/event_content.dart';
import 'package:moliseis/ui/core/ui/content/content_base_card_grid_item.dart';
import 'package:moliseis/ui/core/ui/content/content_base_list_item.dart';
import 'package:moliseis/ui/core/ui/content/content_event_card_grid_item.dart';
import 'package:moliseis/ui/core/ui/content/event_content_start_date_time.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/favourite/widgets/favourite_button.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

class ContentSliverGrid extends StatelessWidget {
  final List<ContentBase> items;
  final void Function(ContentBase content) onPressed;

  const ContentSliverGrid(this.items, {super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SliverToBoxAdapter(
        child: EmptyView(
          text: Text("Non c'è nulla qui per il momento, riprova più tardi!"),
        ),
      );
    }

    final isCompact = context.windowSizeClass.isCompact;

    var itemWidth = kGridViewCardWidth;
    var itemHeight = kGridViewCardHeight;

    if (isCompact) {
      itemWidth = kListViewCardWidth;
      itemHeight = kListViewCardHeight;
    }

    final padding = isCompact
        ? EdgeInsets.zero
        : const EdgeInsets.symmetric(horizontal: 16.0);

    final childrenDelegate = SliverChildBuilderDelegate((_, index) {
      final content = items[index];

      if (isCompact) {
        return ContentBaseListItem(
          content,
          key: ValueKey<String>('list-item:${content.name}-$index'),
          onPressed: (ContentBase content) => onPressed(content),
          horizontalTrailing: FavouriteButton(content: content),
          verticalTrailing: content is EventContent
              ? EventContentStartDateTime(content)
              : null,
        );
      }

      if (content is EventContent) {
        return ContentEventCardGridItem(event: content, onPressed: onPressed);
      }

      return ContentBaseCardGridItem(
        content,
        key: ValueKey<String>('grid-item:${content.name}-$index'),
        onPressed: onPressed,
        trailing: FavouriteButton(
          color: Colors.white,
          content: content,
          borderRadius: context.appShapes.circular.cornerSmall,
        ),
      );
    }, childCount: items.length);

    final gridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: itemWidth,
      mainAxisSpacing: 8.0,
      crossAxisSpacing: 8.0,
      mainAxisExtent: itemHeight,
    );

    return SliverPadding(
      padding: padding,
      sliver: SliverGrid(
        delegate: childrenDelegate,
        gridDelegate: gridDelegate,
      ),
    );
  }
}
