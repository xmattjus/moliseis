import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/ui/core/ui/text_section_divider.dart';
import 'package:moliseis/ui/search/widgets/components/search_anchor_suggestion_list.dart';

import '../../../../support/fixtures.dart';

void main() {
  group('SearchAnchorSuggestionList', () {
    testWidgets('renders section header for any list', (tester) async {
      await tester.pumpWidget(_buildTestApp([]));

      expect(find.byType(TextSectionDivider), findsOneWidget);
      expect(find.text('Risultati rapidi'), findsOneWidget);
    });

    testWidgets('renders no items and no dividers for an empty list', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp([]));

      expect(find.byType(Divider), findsNothing);
      expect(find.byKey(const ValueKey('list-item:Place 1-0')), findsNothing);
    });

    testWidgets('renders one item without a divider for a single suggestion', (
      tester,
    ) async {
      final place = makePlace(name: 'Place 1');

      await tester.pumpWidget(_buildTestApp([place]));

      // index in List.generate for item 0 is 0
      expect(find.byKey(ValueKey('list-item:${place.name}-0')), findsOneWidget);
      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('renders two items with one divider', (tester) async {
      final place1 = makePlace(name: 'Place 1');
      final place2 = makePlace(remoteId: 2, name: 'Place 2');

      await tester.pumpWidget(_buildTestApp([place1, place2]));

      // List.generate indices: item 0 → index 0, item 1 → index 2
      expect(
        find.byKey(ValueKey('list-item:${place1.name}-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('list-item:${place2.name}-2')),
        findsOneWidget,
      );
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('renders three items with two dividers', (tester) async {
      final places = [
        makePlace(name: 'Place 1'),
        makePlace(remoteId: 2, name: 'Place 2'),
        makePlace(remoteId: 3, name: 'Place 3'),
      ];

      await tester.pumpWidget(_buildTestApp(places));

      // List.generate indices: item 0 → 0, item 1 → 2, item 2 → 4
      for (final (itemIndex, p) in places.indexed) {
        expect(
          find.byKey(ValueKey('list-item:${p.name}-${itemIndex * 2}')),
          findsOneWidget,
        );
      }
      expect(find.byType(Divider), findsNWidgets(2));
    });

    testWidgets('calls onSuggestionPressed when an item is tapped', (
      tester,
    ) async {
      final place = makePlace(name: 'Place 1');
      ContentBase? pressed;

      await tester.pumpWidget(
        _buildTestApp([place], onSuggestionPressed: (c) => pressed = c),
      );

      await tester.tap(find.byKey(ValueKey('list-item:${place.name}-0')));
      await tester.pump();

      expect(pressed, same(place));
    });

    testWidgets('does not fire onSuggestionPressed when callback is null', (
      tester,
    ) async {
      final place = makePlace(name: 'Place 1');

      await tester.pumpWidget(_buildTestApp([place]));

      // Tapping should not throw even with no callback.
      await tester.tap(find.byKey(ValueKey('list-item:${place.name}-0')));
      await tester.pump();
    });
  });
}

// ---------------------------------------------------------------------------
// Widget builder
// ---------------------------------------------------------------------------

Widget _buildTestApp(
  List<ContentBase> suggestions, {
  void Function(ContentBase)? onSuggestionPressed,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: SearchAnchorSuggestionList(
          suggestions: suggestions,
          onSuggestionPressed: onSuggestionPressed,
        ),
      ),
    ),
  );
}
