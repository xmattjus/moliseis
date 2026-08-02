import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/ui/core/ui/content/content_base_list_item.dart';
import 'package:moliseis/ui/core/ui/text_section_divider.dart';
import 'package:moliseis/ui/event/widgets/components/event_formatted_date_time.dart';

class SearchAnchorSuggestionList extends StatelessWidget {
  const SearchAnchorSuggestionList({
    required this.suggestions,
    this.onSuggestionPressed,
    super.key,
  });

  final List<ContentBase> suggestions;
  final void Function(ContentBase content)? onSuggestionPressed;

  @override
  Widget build(BuildContext context) {
    final length = math.max(0, suggestions.length * 2 - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const TextSectionDivider('Risultati rapidi'),
        ...List.generate(length, (index) {
          final itemIndex = index ~/ 2;
          final content = suggestions[itemIndex];
          if (index.isEven) {
            return ContentBaseListItem(
              content,
              key: ValueKey<String>('list-item:${content.name}-$index'),
              onPressed: onSuggestionPressed,
              verticalTrailing: content is Event
                  ? EventFormattedDateTime(event: content)
                  : null,
            );
          } else {
            return const Divider();
          }
        }),
      ],
    );
  }
}
