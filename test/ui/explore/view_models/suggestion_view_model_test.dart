import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/ui/explore/view_models/suggestion_view_model.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';

import '../../../support/fake_repositories.dart';
import '../../../support/fixtures.dart';

void main() {
  group('SuggestionViewModel', () {
    test('pending reload keeps prior data, domain error clears it, empty retry '
        'succeeds', () async {
      final gate = Completer<Result<List<Place>>>();
      final repository = FakePlaceRepository(
        getSuggestedPlacesResult: Result.success([makePlace()]),
      );
      final vm = SuggestionViewModel(placeRepository: repository);
      addTearDown(vm.dispose);
      await pumpEventQueue();
      repository.getSuggestionsHandler = () => gate.future;
      final loading = vm.load.runAsync();
      vm.load.run();
      expect(vm.suggestions, hasLength(1));
      gate.complete(Result.error(TestException('failed retry')));
      await loading;
      expect(vm.suggestions, isEmpty);
      expect(vm.load.results.value.hasFailure, isTrue);
      expect(repository.getSuggestionsCallCount, 2);
      repository
        ..getSuggestionsHandler = null
        ..getSuggestedPlacesResult = const Result.success([]);
      expect(await vm.load.runAsync(), isA<Success<void>>());
      expect(vm.load.results.value.completed, isTrue);
      expect(vm.suggestions, isEmpty);
    });

    test(
      'loads suggestions from the constructor and completes the command',
      () async {
        final suggestions = <Place>[
          makePlace(name: 'Castello'),
          makePlace(remoteId: 2, name: 'Teatro'),
        ];
        final viewModel = SuggestionViewModel(
          placeRepository: FakePlaceRepository(
            getSuggestedPlacesResult: Result.success(suggestions),
          ),
        );
        addTearDown(viewModel.dispose);

        await _waitForInitialLoad();

        expect(viewModel.load.results.value.completed, isTrue);
        expect(viewModel.load.results.value.hasFailure, isFalse);
        expect(viewModel.suggestions, equals(suggestions));
      },
    );

    test('leaves suggestions empty and exposes a repository error', () async {
      final viewModel = SuggestionViewModel(
        placeRepository: FakePlaceRepository(
          getSuggestedPlacesResult: Result.error(
            TestException('suggestions unavailable'),
          ),
        ),
      );
      addTearDown(viewModel.dispose);

      await _waitForInitialLoad();

      expect(viewModel.load.results.value.completed, isFalse);
      expect(viewModel.load.results.value.hasFailure, isTrue);
      expect(viewModel.load.results.value.data, isA<Error<void>>());
      expect(viewModel.suggestions, isEmpty);
    });

    test(
      'reload recovers after an error and replaces stale suggestions',
      () async {
        final repository = FakePlaceRepository(
          getSuggestedPlacesResult: Result.error(
            TestException('suggestions unavailable'),
          ),
        );
        final viewModel = SuggestionViewModel(placeRepository: repository);
        addTearDown(viewModel.dispose);

        await _waitForInitialLoad();
        expect(viewModel.load.results.value.hasFailure, isTrue);
        expect(viewModel.suggestions, isEmpty);

        final recoveredSuggestion = makePlace(remoteId: 7, name: 'Museo');
        repository.getSuggestedPlacesResult = Result.success([
          recoveredSuggestion,
        ]);

        await viewModel.load.runAsync();

        expect(repository.getSuggestionsCallCount, 2);
        expect(viewModel.load.results.value.completed, isTrue);
        expect(viewModel.load.results.value.hasFailure, isFalse);
        expect(viewModel.suggestions, equals([recoveredSuggestion]));
      },
    );

    test('exposes an unmodifiable suggestions collection', () async {
      final suggestion = makePlace(name: 'Abbazia');
      final viewModel = SuggestionViewModel(
        placeRepository: FakePlaceRepository(
          getSuggestedPlacesResult: Result.success([suggestion]),
        ),
      );
      addTearDown(viewModel.dispose);

      await _waitForInitialLoad();

      expect(
        () => viewModel.suggestions.add(makePlace(remoteId: 2)),
        throwsUnsupportedError,
      );
      expect(viewModel.suggestions, equals([suggestion]));
    });
  });
}

Future<void> _waitForInitialLoad() => pumpEventQueue(times: 10);
