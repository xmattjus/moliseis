import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/core/content_base.dart';
import 'package:moliseis/domain/models/event/event_content.dart';
import 'package:moliseis/ui/core/themes/shapes.dart';
import 'package:moliseis/ui/core/ui/content/event_content_card_grid_item.dart';
import 'package:moliseis/ui/core/ui/content/event_content_card_list_item.dart';
import 'package:moliseis/ui/core/ui/content/place_content_card_grid_item.dart';
import 'package:moliseis/ui/core/ui/content/place_content_card_list_item.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/favourite/widgets/favourite_button.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:responsive_framework/responsive_framework.dart';

class ContentAdaptiveListGridView extends StatelessWidget {
  const ContentAdaptiveListGridView(
    this.items, {
    super.key,
    required this.onPressed,
  });

  final List<ContentBase> items;

  final void Function(ContentBase content) onPressed;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SliverToBoxAdapter(
        child: EmptyView(text: Text("Non c'è nulla qui per il momento.")),
      );
    }

    if (ResponsiveBreakpoints.of(context).isMobile) {
      return SliverList.separated(
        itemBuilder: (context, index) {
          final content = items[index];

          if (content is EventContent) {
            return EventContentCardListItem(
              key: ValueKey<String>('list-event:${content.remoteId}'),
              content,
              color: Theme.of(context).colorScheme.surface,
              elevation: 0,
              onPressed: (ContentBase content) => onPressed(content),
              actions: <Widget>[
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 16.0),
                  child: FavouriteButton(content: content),
                ),
              ],
            );
          }

          return PlaceContentCardListItem(
            key: ValueKey<String>('list-place:${content.remoteId}'),
            content,
            color: Theme.of(context).colorScheme.surface,
            elevation: 0,
            onPressed: (ContentBase content) => onPressed(content),
            actions: <Widget>[
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 16.0),
                child: FavouriteButton(content: content),
              ),
            ],
          );
        },
        separatorBuilder: (_, _) => const Divider(),
        itemCount: items.length,
      );
    } else {
      return SliverPadding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 16.0),
        sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate((_, index) {
            final content = items[index];

            if (content is EventContent) {
              return EventContentCardGridItem(
                key: ValueKey<String>('grid-event:${content.remoteId}'),
                content,
                onPressed: () => onPressed(content),
                actions: _buildActions(content),
              );
            }

            return PlaceContentCardGridItem(
              key: ValueKey<String>('grid-place:${content.remoteId}'),
              content,
              onPressed: () => onPressed(content),
              actions: _buildActions(content),
            );
          }, childCount: items.length),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 8.0,
            crossAxisSpacing: 8.0,
            mainAxisExtent: items is List<EventContent>
                ? kEventGridViewCardHeight
                : kGridViewCardHeight,
          ),
        ),
      );
    }
  }

  List<Widget> _buildActions(ContentBase content) => <Widget>[
    Padding(
      padding: const EdgeInsetsDirectional.only(top: 8.0, end: 8.0),
      child: FavouriteButton(
        color: Colors.white70,
        content: content,
        radius: Shapes.small,
      ),
    ),
  ];
}
