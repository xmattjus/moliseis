import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/ui/explore/view_models/explore_view_model.dart';
import 'package:moliseis/utils/result.dart';

import '../../../support/fake_repositories.dart';
import '../../../support/fixtures.dart';

void main() {
  group('ExploreViewModel.loadLatest', () {
    test('bootstraps direct retrieval and publishes repository order '
        'without ID lookup', () async {
      final places = [makePlace(remoteId: 2), makePlace()];
      final repo = FakePlaceRepository(getLatestResult: Result.success(places));
      final vm = ExploreViewModel(placeRepository: repo);
      addTearDown(vm.dispose);
      await pumpEventQueue();
      expect(vm.loadLatest.completed, isTrue);
      expect(vm.latest, places);
      expect(repo.getLatestCallCount, 1);
      expect(repo.getByIdCallCount, 0);
    });

    test('owns discovery error and retries discovery', () async {
      final failure = TestException('discovery failed');
      final repo = FakePlaceRepository(getLatestResult: Result.error(failure));
      final vm = ExploreViewModel(placeRepository: repo);
      addTearDown(vm.dispose);
      await pumpEventQueue();
      expect(vm.loadLatest.error, isTrue);
      expect((vm.loadLatest.result! as Error<void>).error, same(failure));
      repo.getLatestResult = Result.success([makePlace()]);
      await vm.loadLatest.execute();
      expect(repo.getLatestCallCount, 2);
      expect(vm.loadLatest.completed, isTrue);
      expect(vm.latest, hasLength(1));
    });

    test('retains successful state while pending and on error, '
        'clears on empty success', () async {
      final first = makePlace();
      final repo = FakePlaceRepository(
        getLatestResult: Result.success([first]),
      );
      final vm = ExploreViewModel(placeRepository: repo);
      addTearDown(vm.dispose);
      await pumpEventQueue();
      final pending = Completer<Result<List<Place>>>();
      repo.pendingGetLatest = pending;
      final load = vm.loadLatest.execute();
      expect(vm.latest, [first]);
      pending.complete(Result.error(TestException('query failed')));
      await load;
      expect(vm.latest, [first]);
      expect(vm.loadLatest.error, isTrue);
      repo
        ..pendingGetLatest = null
        ..getLatestResult = const Result.success([]);
      await vm.loadLatest.execute();
      expect(vm.latest, isEmpty);
      expect(vm.loadLatest.completed, isTrue);
    });

    test(
      'replaces the complete list after successful pending retrieval',
      () async {
        final first = makePlace();
        final repo = FakePlaceRepository(
          getLatestResult: Result.success([first]),
        );
        final vm = ExploreViewModel(placeRepository: repo);
        addTearDown(vm.dispose);
        await pumpEventQueue();
        final pending = Completer<Result<List<Place>>>();
        repo.pendingGetLatest = pending;
        final load = vm.loadLatest.execute();
        expect(vm.latest, [first]);
        final replacement = [makePlace(remoteId: 3), makePlace(remoteId: 2)];
        pending.complete(Result.success(replacement));
        await load;
        expect(vm.latest, replacement);
      },
    );
  });
}
