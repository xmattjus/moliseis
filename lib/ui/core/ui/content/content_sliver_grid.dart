import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/ui/core/ui/content/content_base_card_grid_item.dart';
import 'package:moliseis/ui/core/ui/content/content_base_list_item.dart';
import 'package:moliseis/ui/core/ui/content/content_event_card_grid_item.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/event/widgets/components/event_formatted_date_time.dart';
import 'package:moliseis/ui/favourite/widgets/favourite_button.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

class ContentSliverGrid extends StatelessWidget {
  const ContentSliverGrid(
    this.items, {
    required this.onPressed,
    super.key,
  });

  final List<ContentBase> items;
  final void Function(ContentBase content) onPressed;

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
        : const EdgeInsets.symmetric(horizontal: 16);

    final childrenDelegate = SliverChildBuilderDelegate((_, index) {
      final content = items[index];

      if (isCompact) {
        return ContentBaseListItem(
          content,
          key: ValueKey<String>('list-item:${content.remoteId}-$index'),
          onPressed: onPressed,
          horizontalTrailing: FavouriteButton(content: content),
          verticalTrailing: content is Event
              ? EventFormattedDateTime(event: content)
              : null,
        );
      }

      if (content is Event) {
        return ContentEventCardGridItem(
          event: content,
          key: ValueKey<String>('grid-item:${content.remoteId}-$index'),
          onPressed: onPressed,
        );
      }

      return ContentBaseCardGridItem(
        content,
        key: ValueKey<String>('grid-item:${content.remoteId}-$index'),
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
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
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
