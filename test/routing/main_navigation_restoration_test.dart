import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/content_type.dart';
import 'package:moliseis/ui/explore/widgets/explore_screen.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map_modal_post.dart';
import 'package:moliseis/ui/geo_map/widgets/geo_map_screen.dart';
import 'package:moliseis/ui/post/widgets/post_screen.dart';
import 'package:moliseis/ui/search/widgets/search_result_screen.dart';
import 'package:moliseis/utils/result.dart';

import '../support/fake_repositories.dart';
import '../support/fixtures.dart';
import '../support/predictive_back.dart';
import '../support/sync_harness.dart';

void main() {
  testWidgets('production Map selection is reconstructed after restoration', (
    tester,
  ) async {
    final event = makeEvent(remoteId: 5);
    final holder = SyncRestorationHolder(
      settingsFactory: () =>
          FakeSettingsRepository(lastSyncedAt: DateTime.now()),
      eventRepositoryFactory: () =>
          FakeEventRepository(getByIdResults: {5: Result.success(event)}),
    );
    await tester.pumpWidget(RestorableSyncHarness(holder: holder));
    await tester.pumpAndSettle();
    final before = holder.fixture!;
    before.router.go('/map?contentId=5&type=event');
    await tester.pumpAndSettle();
    final oldMapState = tester.state(find.byType(GeoMapScreen));
    expect(
      tester
          .widget<GeoMapScreen>(find.byType(GeoMapScreen))
          .viewModel
          .selectedContent,
      same(event),
    );

    await tester.restartAndRestore();
    await tester.pumpAndSettle();

    final after = holder.fixture!;
    expect(after.router, isNot(same(before.router)));
    expect(oldMapState.mounted, isFalse);
    expect(
      after.router.routeInformationProvider.value.uri,
      Uri.parse('/map?contentId=5&type=event'),
    );
    final map = tester.widget<GeoMapScreen>(find.byType(GeoMapScreen));
    expect(map.initialContentId, 5);
    expect(map.initialContentType, ContentType.event);
    expect(map.viewModel.selectedContent, same(event));
    expect(map.viewModel.selectedContent!.remoteId, 5);
    expect(find.byType(GeoMapModalPost), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final predictive in [false, true]) {
    testWidgets('production Search Post restoration retains ancestry and '
        '${predictive ? 'predictive' : 'normal'} Back parent', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final event = makeEvent();
        final holder = SyncRestorationHolder(
          settingsFactory: () =>
              FakeSettingsRepository(lastSyncedAt: DateTime.now()),
          eventRepositoryFactory: () =>
              FakeEventRepository(getByIdResults: {1: Result.success(event)}),
        );
        await tester.pumpWidget(RestorableSyncHarness(holder: holder));
        await tester.pumpAndSettle();
        final before = holder.fixture!;
        before.router.go('/home/search_results/posts/1?q=molise&type=event');
        await tester.pumpAndSettle();
        final oldPostState = tester.state(find.byType(PostScreen));
        final oldViewModel = tester
            .widget<PostScreen>(find.byType(PostScreen))
            .viewModel;

        await tester.restartAndRestore();
        await tester.pumpAndSettle();

        final after = holder.fixture!;
        expect(after.router, isNot(same(before.router)));
        expect(oldPostState.mounted, isFalse);
        expect(
          after.router.routeInformationProvider.value.uri,
          Uri.parse('/home/search_results/posts/1?q=molise&type=event'),
        );
        final post = tester.widget<PostScreen>(find.byType(PostScreen));
        expect(post.viewModel, isNot(same(oldViewModel)));
        expect(post.viewModel.content, same(event));
        expect(find.byType(ExploreScreen, skipOffstage: false), findsOneWidget);
        final search = find.byType(SearchResultScreen, skipOffstage: false);
        expect(search, findsOneWidget);
        expect(tester.widget<SearchResultScreen>(search).query, 'molise');
        final branch = Navigator.of(tester.element(find.byType(PostScreen)));
        final root = Navigator.of(
          tester.element(find.byType(PostScreen)),
          rootNavigator: true,
        );
        final pages = branch.widget.pages;
        expect(pages.length, 3);
        expect(root.widget.pages.length, 1);
        final searchState = tester.state(search);

        if (predictive) {
          await startPredictiveBack(tester);
          await updatePredictiveBack(tester, 0.5);
          expect(branch.widget.pages, pages);
          await commitPredictiveBack(tester);
        } else {
          expect(await tester.binding.handlePopRoute(), isTrue);
          await tester.pumpAndSettle();
        }

        expect(
          after.router.routeInformationProvider.value.uri,
          Uri.parse('/home/search_results?q=molise&type=event'),
        );
        expect(branch.widget.pages.length, 2);
        expect(
          branch.widget.pages.map((page) => page.key),
          pages.take(2).map((page) => page.key),
        );
        expect(root.widget.pages.length, 1);
        expect(find.byType(PostScreen), findsNothing);
        expect(find.byType(SearchResultScreen), findsOneWidget);
        expect(
          tester.state(find.byType(SearchResultScreen)),
          same(searchState),
        );
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }
}
