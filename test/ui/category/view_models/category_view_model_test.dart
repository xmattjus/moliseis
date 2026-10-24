import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/models/content_type.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';

import '../../../support/category_view_model_test_support.dart';
import '../../../support/command_test_support.dart';
import '../../../support/fake_repositories.dart';
import '../../../support/fixtures.dart';

void main() {
  testCategoryViewModel(
    'bootstrap selection is copied before deferred loading',
    (tester, h) async {
      final input = {ContentCategory.nature};
      final gate = Completer<Result<List<Place>>>();
      Set<ContentCategory>? captured;
      h.places.getByCategoriesHandler = (value) {
        captured = value;
        return gate.future;
      };
      final vm = h.create(initialCategories: input);
      expect(vm.selectedCategories, {ContentCategory.nature});
      expect(vm.selectedTypes, ContentType.values.toSet());
      expect(vm.load.results.value.idle, isTrue);
      expect(vm.load.isRunningSync.value, isTrue);
      expect(h.places.getByCategoriesCallCount, 0);
      input.clear();
      await pumpCommandTurns(tester);
      expect(captured, {ContentCategory.nature});
      expect(() => captured!.clear(), throwsUnsupportedError);
      gate.complete(const Result.success([]));
      await pumpCommandTurns(tester);
      expect(vm.load.results.value.completed, isTrue);
    },
  );

  testCategoryViewModel('empty and unknown normalize to supported all path', (
    tester,
    h,
  ) async {
    final vm = h.create(initialCategories: {ContentCategory.unknown});
    expect(vm.selectedCategories, ContentCategory.values.minusUnknown.toSet());
    await pumpCommandTurns(tester);
    expect(h.places.getAllCallCount, 1);
    expect(h.events.getByCurrentYearCallCount, 1);
    expect(h.places.getByCategoriesCallCount, 0);
    vm
      ..setSelectedCategories({ContentCategory.nature})
      ..setSelectedTypes({ContentType.place});
    await pumpCommandTurns(tester);
    vm
      ..setSelectedCategories({})
      ..setSelectedTypes({});
    await pumpCommandTurns(tester);
    expect(vm.selectedCategories, ContentCategory.values.minusUnknown.toSet());
    expect(vm.selectedTypes, ContentType.values.toSet());
  });

  testCategoryViewModel(
    'equal selection is no-op but refresh is a new intent',
    (tester, h) async {
      final vm = h.create();
      var notifications = 0;
      vm
        ..addListener(() => notifications++)
        ..setSelectedCategories({ContentCategory.history})
        ..setSelectedTypes(ContentType.values.reversed.toSet());
      await pumpCommandTurns(tester);
      expect(h.places.getByCategoriesCallCount, 1);
      final count = notifications;
      vm
        ..setSelectedCategories({ContentCategory.history})
        ..setSelectedTypes(ContentType.values.toSet());
      expect(notifications, count);
      vm.refresh();
      await pumpCommandTurns(tester);
      expect(h.places.getByCategoriesCallCount, 2);
    },
  );

  testCategoryViewModel(
    'confirmed old snapshots and pending requests are independent',
    (tester, h) async {
      final vm = h.create();
      final oldCategories = vm.selectedCategories;
      final oldTypes = vm.selectedTypes;
      final input = {ContentCategory.nature};
      final seen = <Set<ContentCategory>>[];
      h.places.getByCategoriesHandler = (categories) async {
        seen.add(categories);
        return const Result.success([]);
      };
      vm
        ..setSelectedCategories(input)
        ..setSelectedTypes({ContentType.place});
      input.add(ContentCategory.food);
      await pumpCommandTurns(tester);
      expect(oldCategories, {ContentCategory.history});
      expect(oldTypes, ContentType.values.toSet());
      expect(seen.single, {ContentCategory.nature});
      expect(() => vm.selectedCategories.clear(), throwsUnsupportedError);
      expect(() => vm.selectedTypes.clear(), throwsUnsupportedError);
      expect(h.events.getByCategoriesCallCount, 0);
    },
  );

  for (final oldFirst in [true, false]) {
    for (final oldOutcome in ['success', 'domain', 'runtime']) {
      testCategoryViewModel(
        'A to B, old $oldOutcome settles ${oldFirst ? 'first' : 'last'}',
        (tester, h) async {
          final a = Completer<Result<List<Place>>>();
          final b = Completer<Result<List<Place>>>();
          h.places.getByCategoriesHandler = (categories) =>
              categories.contains(ContentCategory.history)
              ? a.future
              : b.future;
          final vm = h.create()..setSelectedTypes({ContentType.place});
          await pumpCommandTurns(tester);
          vm.setSelectedCategories({ContentCategory.nature});
          await pumpCommandTurns(tester);
          final runtime = StateError('old runtime');
          void finishOld() {
            if (oldOutcome == 'success') {
              a.complete(Result.success([makePlace(name: 'old')]));
            } else if (oldOutcome == 'domain') {
              a.complete(Result.error(TestException('old domain')));
            } else {
              a.completeError(runtime, StackTrace.current);
            }
          }

          if (oldFirst) {
            finishOld();
            await pumpCommandTurns(tester);
            expect(vm.content, isEmpty);
            expect(vm.load.isRunningSync.value, isTrue);
          }
          b.complete(Result.success([makePlace(name: 'new')]));
          await pumpCommandTurns(tester);
          if (!oldFirst) {
            finishOld();
            await pumpCommandTurns(tester);
          }
          expect(vm.content.single.name, 'new');
          expect(vm.load.results.value.completed, isTrue);
          expect(vm.load.isRunningSync.value, isFalse);
          expect(h.logger.calls, hasLength(oldOutcome == 'runtime' ? 1 : 0));
          if (oldOutcome == 'runtime') {
            expect(h.logger.calls.single.error, same(runtime));
          }
          expect(vm.load.debugLiveChildCount, 0);
        },
      );
    }
  }

  for (final reverse in [false, true]) {
    testCategoryViewModel(
      'A to B to A uses execution authority, reverse=$reverse',
      (tester, h) async {
        final gates = <Completer<Result<List<Place>>>>[];
        h.places.getByCategoriesHandler = (_) {
          final gate = Completer<Result<List<Place>>>();
          gates.add(gate);
          return gate.future;
        };
        final vm = h.create()..setSelectedTypes({ContentType.place});
        await pumpCommandTurns(tester);
        vm.setSelectedCategories({ContentCategory.nature});
        await pumpCommandTurns(tester);
        vm.setSelectedCategories({ContentCategory.history});
        await pumpCommandTurns(tester);
        expect(gates, hasLength(3));
        final order = reverse ? [2, 1, 0] : [0, 1, 2];
        for (final i in order) {
          gates[i].complete(Result.success([makePlace(name: '$i')]));
          await pumpCommandTurns(tester);
        }
        expect(vm.content.single.name, '2');
        expect(vm.load.debugRetiredChildCount, 3);
      },
    );
  }

  for (final all in [false, true]) {
    testCategoryViewModel(
      '${all ? 'all' : 'filtered'} stages are sequential and atomic',
      (tester, h) async {
        final places = Completer<Result<List<Place>>>();
        final events = Completer<Result<List<Event>>>();
        if (all) {
          h.places.pendingGetAll = places;
          h.events.pendingGetByCurrentYear = events;
        } else {
          h.places.getByCategoriesHandler = (_) => places.future;
          h.events.getByCategoriesHandler = (_) => events.future;
        }
        final vm = h.create(
          initialCategories: all
              ? ContentCategory.values.minusUnknown.toSet()
              : {ContentCategory.history},
        );
        var commits = 0;
        vm.addListener(() => commits++);
        await pumpCommandTurns(tester);
        expect(
          all
              ? h.events.getByCurrentYearCallCount
              : h.events.getByCategoriesCallCount,
          0,
        );
        places.complete(Result.success([makePlace(name: 'Z place')]));
        await pumpCommandTurns(tester);
        expect(vm.content, isEmpty);
        expect(commits, 0);
        expect(
          all
              ? h.events.getByCurrentYearCallCount
              : h.events.getByCategoriesCallCount,
          1,
        );
        events.complete(Result.success([makeEvent(name: 'A event')]));
        await pumpCommandTurns(tester);
        expect(vm.content.map((x) => x.name), ['A event', 'Z place']);
        expect(commits, 1);
      },
    );
    for (final second in [false, true]) {
      testCategoryViewModel(
        '${all ? 'all' : 'filtered'} failure ${second ? 2 : 1}: atomic',
        (tester, h) async {
          final failure = TestException('original');
          if (all) {
            h.places.getAllResult = second
                ? Result.success([makePlace()])
                : Result.error(failure);
            h.events.getByCurrentYearResult = Result.error(failure);
          } else {
            h.places.getByCategoriesResult = second
                ? Result.success([makePlace()])
                : Result.error(failure);
            h.events.getByCategoriesResult = Result.error(failure);
          }
          final vm = h.create(
            initialCategories: all
                ? ContentCategory.values.minusUnknown.toSet()
                : {ContentCategory.history},
          );
          await pumpCommandTurns(tester);
          expect(vm.content, isEmpty);
          expect(vm.load.results.value.domainError, same(failure));
          expect(
            all
                ? h.events.getByCurrentYearCallCount
                : h.events.getByCategoriesCallCount,
            second ? 1 : 0,
          );
          expect(h.logger.calls, isEmpty);
        },
      );
    }
  }

  testCategoryViewModel(
    'filter/type change during private event partial cannot mix results',
    (tester, h) async {
      final oldEvents = Completer<Result<List<Event>>>();
      h.places.getByCategoriesHandler = (categories) async =>
          Result.success([makePlace(name: categories.single.name)]);
      h.events.getByCategoriesHandler = (_) => oldEvents.future;
      final vm = h.create();
      await pumpCommandTurns(tester);
      expect(vm.content, isEmpty);
      vm
        ..setSelectedTypes({ContentType.place})
        ..setSelectedCategories({ContentCategory.nature});
      await pumpCommandTurns(tester);
      expect(vm.content.single.name, 'nature');
      oldEvents.complete(Result.success([makeEvent(name: 'old')]));
      await pumpCommandTurns(tester);
      expect(vm.content.single.name, 'nature');
      expect(h.events.getByCategoriesCallCount, 1);
    },
  );

  testCategoryViewModel(
    'refresh retains success; changed filter clears; empty replaces',
    (tester, h) async {
      h.places.getByCategoriesResult = Result.success([makePlace()]);
      final vm = h.create();
      await pumpCommandTurns(tester);
      final retained = vm.content.single;
      h.places.getByCategoriesResult = Result.error(TestException('refresh'));
      vm.refresh();
      await pumpCommandTurns(tester);
      expect(vm.content.single, same(retained));
      expect(vm.load.results.value.hasFailure, isTrue);
      vm.setSelectedCategories({ContentCategory.nature});
      expect(vm.content, isEmpty);
      await pumpCommandTurns(tester);
      expect(vm.content, isEmpty);
      h.places.getByCategoriesResult = const Result.success([]);
      vm.refresh();
      await pumpCommandTurns(tester);
      expect(vm.load.results.value.completed, isTrue);
      expect(vm.content, isEmpty);
    },
  );

  for (final beforeQuery in [false, true]) {
    testCategoryViewModel(
      'query commit uses current sort: write first=$beforeQuery',
      (tester, h) async {
        final gate = Completer<Result<List<Place>>>();
        final write = Completer<Result<void>>();
        h.places.getByCategoriesHandler = (_) => gate.future;
        h.settings.onSetContentSort = (_) => write.future;
        final newer = makePlace(name: 'Z', modifiedAt: DateTime.utc(2026, 2));
        final older = makePlace(name: 'A', modifiedAt: DateTime.utc(2026));
        final vm = h.create();
        await pumpCommandTurns(tester);
        vm.setSort.run(ContentSort.byDate);
        await pumpCommandTurns(tester);
        expect(vm.sort, ContentSort.byDate);
        expect(h.settings.contentSort, ContentSort.byName);
        if (beforeQuery) {
          write.complete(const Result.success(null));
          await pumpCommandTurns(tester);
        }
        gate.complete(Result.success([older, newer]));
        await pumpCommandTurns(tester);
        expect(vm.content.map((x) => x.name), ['Z', 'A']);
        if (!beforeQuery) {
          write.complete(const Result.success(null));
          await pumpCommandTurns(tester);
        }
        vm.setSort.run(ContentSort.byName);
        await pumpCommandTurns(tester);
        expect(h.places.getByCategoriesCallCount, 1);
        expect(vm.sort, ContentSort.byName);
        expect(vm.content.map((x) => x.name), ['A', 'Z']);
      },
    );
  }

  testCategoryViewModel(
    'sort failure is truthful, retains session sort; same sort does not retry',
    (tester, h) async {
      final failure = TestException('write');
      h.settings.setContentSortResult = Result.error(failure);
      final vm = h.create();
      await pumpCommandTurns(tester);
      vm.setSort.run(ContentSort.byDate);
      await pumpCommandTurns(tester);
      expect(vm.setSort.results.value.domainError, same(failure));
      expect(
        vm.setSort.results.value.data,
        same(h.settings.setContentSortResult),
      );
      expect(vm.sort, ContentSort.byDate);
      expect(h.settings.contentSort, ContentSort.byName);
      expect(h.logger.calls, isEmpty);
      vm.setSort.run(ContentSort.byDate);
      await pumpCommandTurns(tester);
      expect(h.settings.contentSortCalls, [ContentSort.byDate]);
      final replacement = h.create();
      expect(replacement.sort, ContentSort.byName);
      await pumpCommandTurns(tester);
    },
  );

  testCategoryViewModel(
    'sort rejects duplicates before entry, during write and notify',
    (tester, h) async {
      final write = Completer<Result<void>>();
      h.settings.onSetContentSort = (_) => write.future;
      final vm = h.create();
      await pumpCommandTurns(tester);
      vm
        ..addListener(() => vm.setSort.run(ContentSort.byName))
        ..setSort.run(ContentSort.byDate)
        ..setSort.run(ContentSort.byName);
      await pumpCommandTurns(tester);
      vm.setSort.run(ContentSort.byName);
      expect(h.settings.contentSortCalls, [ContentSort.byDate]);
      expect(vm.sort, ContentSort.byDate);
      write.complete(const Result.success(null));
      await pumpCommandTurns(tester);
    },
  );
  testCategoryViewModel(
    'types and categories replace pending places together',
    (tester, h) async {
      final old = Completer<Result<List<Place>>>();
      final seenEvents = <Set<ContentCategory>>[];
      h.places.getByCategoriesHandler = (categories) =>
          categories.contains(ContentCategory.history)
          ? old.future
          : Future.value(Result.success([makePlace(name: 'nature')]));
      h.events.getByCategoriesHandler = (categories) async {
        seenEvents.add(categories);
        return Result.success([makeEvent(name: 'old')]);
      };
      final vm = h.create();
      await pumpCommandTurns(tester);
      vm
        ..setSelectedCategories({ContentCategory.nature})
        ..setSelectedTypes({ContentType.place});
      await pumpCommandTurns(tester);
      expect(vm.content.single.name, 'nature');
      old.complete(Result.success([makePlace(name: 'history')]));
      await pumpCommandTurns(tester);
      expect(seenEvents.single, {ContentCategory.history});
      expect(vm.content.single.name, 'nature');
      expect(vm.load.debugLiveChildCount, 0);
    },
  );

  testCategoryViewModel(
    'obsolete query cannot restore ordering after a newer sort',
    (tester, h) async {
      final a = Completer<Result<List<Place>>>();
      final b = Completer<Result<List<Place>>>();
      h.places.getByCategoriesHandler = (categories) =>
          categories.contains(ContentCategory.history) ? a.future : b.future;
      final vm = h.create()..setSelectedTypes({ContentType.place});
      await pumpCommandTurns(tester);
      vm.setSelectedCategories({ContentCategory.nature});
      await pumpCommandTurns(tester);
      vm.setSort.run(ContentSort.byDate);
      await pumpCommandTurns(tester);
      b.complete(
        Result.success([
          makePlace(name: 'A'),
          makePlace(name: 'Z', modifiedAt: DateTime.utc(2027)),
        ]),
      );
      await pumpCommandTurns(tester);
      expect(vm.content.map((x) => x.name), ['Z', 'A']);
      a.complete(Result.success([makePlace(name: 'old')]));
      await pumpCommandTurns(tester);
      expect(vm.content.map((x) => x.name), ['Z', 'A']);
      expect(h.places.getByCategoriesCallCount, 2);
      expect(h.settings.contentSortCalls, [ContentSort.byDate]);
    },
  );
}
