import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/event_content.dart';
import 'package:moliseis/ui/core/ui/content/content_base_list_item.dart';
import 'package:moliseis/ui/core/ui/content/event_content_start_date_time.dart';
import 'package:moliseis/ui/core/ui/text_section_divider.dart';

class SearchAnchorSuggestionList extends StatelessWidget {
  final List<ContentBase> suggestions;
  final void Function(ContentBase content)? onSuggestionPressed;

  const SearchAnchorSuggestionList({
    super.key,
    required this.suggestions,
    this.onSuggestionPressed,
  });

  @override
  Widget build(BuildContext context) {
    final length = math.max(0, suggestions.length * 2 - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const TextSectionDivider('Risultati rapidi'),
        ...List.generate(length, (index) {
          final int itemIndex = index ~/ 2;
          final content = suggestions[itemIndex];
          if (index.isEven) {
            return ContentBaseListItem(
              content,
              key: ValueKey('list-content:${content.remoteId}'),
              onPressed: onSuggestionPressed,
              verticalTrailing: content is EventContent
                  ? EventContentStartDateTime(content)
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
