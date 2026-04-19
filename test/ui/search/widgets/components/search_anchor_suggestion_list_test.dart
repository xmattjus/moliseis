import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/content_category.dart'
    show ContentCategory;
import 'package:moliseis/domain/models/place_content.dart';
import 'package:moliseis/ui/core/ui/text_section_divider.dart';
import 'package:moliseis/ui/search/widgets/components/search_anchor_suggestion_list.dart';
import 'package:objectbox/objectbox.dart';

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
      // No ContentBaseListItem keys present.
      expect(find.byKey(const ValueKey('Place 1')), findsNothing);
    });

    testWidgets('renders one item without a divider for a single suggestion', (
      tester,
    ) async {
      final place = _makePlace(1);

      await tester.pumpWidget(_buildTestApp([place]));

      expect(find.byKey(ValueKey(place.name)), findsOneWidget);
      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('renders two items with one divider', (tester) async {
      final place1 = _makePlace(1);
      final place2 = _makePlace(2);

      await tester.pumpWidget(_buildTestApp([place1, place2]));

      expect(find.byKey(ValueKey(place1.name)), findsOneWidget);
      expect(find.byKey(ValueKey(place2.name)), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('renders three items with two dividers', (tester) async {
      final places = [_makePlace(1), _makePlace(2), _makePlace(3)];

      await tester.pumpWidget(_buildTestApp(places));

      for (final p in places) {
        expect(find.byKey(ValueKey(p.name)), findsOneWidget);
      }
      expect(find.byType(Divider), findsNWidgets(2));
    });

    testWidgets('calls onSuggestionPressed when an item is tapped', (
      tester,
    ) async {
      final place = _makePlace(1);
      ContentBase? pressed;

      await tester.pumpWidget(
        _buildTestApp([place], onSuggestionPressed: (c) => pressed = c),
      );

      await tester.tap(find.byKey(ValueKey(place.name)));
      await tester.pump();

      expect(pressed, same(place));
    });

    testWidgets('does not fire onSuggestionPressed when callback is null', (
      tester,
    ) async {
      final place = _makePlace(1);

      await tester.pumpWidget(_buildTestApp([place]));

      // Tapping should not throw even with no callback.
      await tester.tap(find.byKey(ValueKey(place.name)));
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

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

PlaceContent _makePlace(int id) => PlaceContent(
  remoteId: id,
  name: 'Place $id',
  description: '',
  category: ContentCategory.unknown,
  city: ToOne(),
  coordinates: const LatLng(41.56, 14.66),
  createdAt: DateTime(2025),
  modifiedAt: DateTime(2025),
  media: ToMany(),
  isSaved: false,
);
