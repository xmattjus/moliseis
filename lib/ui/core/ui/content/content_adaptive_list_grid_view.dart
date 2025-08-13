import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/core/content_base.dart';
import 'package:moliseis/domain/models/event/event_content.dart';
import 'package:moliseis/ui/core/themes/shapes.dart';
import 'package:moliseis/ui/core/ui/content/content_base_card_grid_item.dart';
import 'package:moliseis/ui/core/ui/content/content_base_list_item.dart';
import 'package:moliseis/ui/core/ui/content/event_content_start_date_time.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/favourite/widgets/favourite_button.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:responsive_framework/responsive_framework.dart';

class ContentAdaptiveListGridView extends StatelessWidget {
  final List<ContentBase> items;
  final void Function(ContentBase content) onPressed;

  const ContentAdaptiveListGridView(
    this.items, {
    super.key,
    required this.onPressed,
  });

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

          return ContentBaseListItem(
            content,
            key: ValueKey<String>('list-content:${content.remoteId}'),
            onPressed: (ContentBase content) => onPressed(content),
            horizontalTrailing: FavouriteButton(content: content),
            verticalTrailing: content is EventContent
                ? EventContentStartDateTime(content)
                : null,
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

            return ContentBaseCardGridItem(
              content,
              onPressed: (ContentBase content) => onPressed(content),
              verticalTrailing: content is EventContent
                  ? EventContentStartDateTime(content)
                  : null,
              horizontalTrailing: FavouriteButton(
                color: Colors.white,
                content: content,
                radius: Shapes.small,
              ),
            );
          }, childCount: items.length),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount:
                2, // TODO(xmattjus): Update for different screen sizes.
            mainAxisSpacing: 8.0,
            crossAxisSpacing: 8.0,
            mainAxisExtent: kGridViewCardHeight,
          ),
        ),
      );
    }
  }
}
