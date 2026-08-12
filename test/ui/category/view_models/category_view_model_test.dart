import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_type.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/domain/use-cases/category_use_case.dart';
import 'package:moliseis/domain/use-cases/explore_use_case.dart';
import 'package:moliseis/ui/category/view_models/category_view_model.dart';
import 'package:moliseis/utils/result.dart';

import '../../../support/fake_repositories.dart';
import '../../../support/fixtures.dart';

void main() {
  group('CategoryViewModel', () {
    group('_load via filtered path (CategoryUseCase)', () {
      test('populates content when both places and events succeed', () async {
        final place1 = makePlace(name: 'Castle');
        final event1 = makeEvent(remoteId: 2, name: 'Festival');
        final vm = buildViewModel(
          placesByCategoryResult: Result.success([place1]),
          eventsByCategoryResult: Result.success([event1]),
        );

        await vm.load.execute();

        expect(vm.load.completed, isTrue);
        expect(vm.content, hasLength(2));
      });

      test(
        'early-returns and skips event fetch when place fetch fails',
        () async {
          final eventRepo = FakeEventRepository();
          final placeRepo = FakePlaceRepository(
            getByCategoriesResult: Result.error(
              TestException('places failed'),
            ),
          );
          final vm = CategoryViewModel(
            categoryUseCase: CategoryUseCase(
              eventRepository: eventRepo,
              placeRepository: placeRepo,
            ),
            exploreGetByIdUseCase: ExploreUseCase(
              eventRepository: eventRepo,
              placeRepository: placeRepo,
            ),
            settingsRepository: FakeSettingsRepository(),
          );

          await vm.load.execute();

          expect(vm.load.error, isTrue);
          expect(vm.content, isEmpty);
          // Event repository must not have been queried for categories.
          expect(eventRepo.getByCategoriesCallCount, 0);
        },
      );

      test(
        'surfaces error when event fetch fails after successful place fetch',
        () async {
          final vm = buildViewModel(
            placesByCategoryResult: const Result.success(<Place>[]),
            eventsByCategoryResult: Result.error(
              TestException('events failed'),
            ),
          );

          await vm.load.execute();

          expect(vm.load.error, isTrue);
        },
      );
    });

    group('setSelectedCategories', () {
      test('is a no-op when categories are unchanged', () async {
        final eventRepo = FakeEventRepository();
        final placeRepo = FakePlaceRepository();
        final vm = CategoryViewModel(
          categoryUseCase: CategoryUseCase(
            eventRepository: eventRepo,
            placeRepository: placeRepo,
          ),
          exploreGetByIdUseCase: ExploreUseCase(
            eventRepository: eventRepo,
            placeRepository: placeRepo,
          ),
          settingsRepository: FakeSettingsRepository(),
        );

        // Set categories once, then set again with the same value.
        await vm.setSelectedCategories.execute({ContentCategory.history});
        final callsAfterFirst = eventRepo.getByCategoriesCallCount;
        await vm.setSelectedCategories.execute({ContentCategory.history});

        expect(
          eventRepo.getByCategoriesCallCount,
          callsAfterFirst,
          reason: 'second call with same categories must not trigger a load',
        );
      });
    });

    group('setSelectedTypes', () {
      test(
        'loads only places when only ContentType.place is selected',
        () async {
          final place1 = makePlace(remoteId: 2, name: 'Castle');
          final vm = buildViewModel(
            placesByCategoryResult: Result.success([place1]),
            eventsByCategoryResult: const Result.success(<Event>[]),
          );

          // setSelectedTypes internally triggers load; no extra execute needed.
          await vm.setSelectedTypes.execute({ContentType.place});

          expect(vm.content.every((c) => c is Place), isTrue);
        },
      );
    });
  });
}

// ---------------------------------------------------------------------------
// Builder helper
// ---------------------------------------------------------------------------

/// Builds a [CategoryViewModel] wired to fakes.
///
/// By default `selectedCategories` is empty, routing `_load` through
/// [CategoryUseCase] (filtered path) rather than [ExploreUseCase] (all path).
CategoryViewModel buildViewModel({
  Result<List<Event>>? eventsByCategoryResult,
  Result<List<Place>>? placesByCategoryResult,
  Result<List<Event>>? allEventsResult,
  Result<List<Place>>? allPlacesResult,
}) {
  final eventRepo = FakeEventRepository(
    getByCategoriesResult:
        eventsByCategoryResult ?? const Result.success(<Event>[]),
    getByCurrentYearResult: allEventsResult ?? const Result.success(<Event>[]),
  );
  final placeRepo = FakePlaceRepository(
    getByCategoriesResult:
        placesByCategoryResult ?? const Result.success(<Place>[]),
    getAllResult: allPlacesResult ?? const Result.success(<Place>[]),
  );

  return CategoryViewModel(
    categoryUseCase: CategoryUseCase(
      eventRepository: eventRepo,
      placeRepository: placeRepo,
    ),
    exploreGetByIdUseCase: ExploreUseCase(
      eventRepository: eventRepo,
      placeRepository: placeRepo,
    ),
    settingsRepository: FakeSettingsRepository(),
  );
}
