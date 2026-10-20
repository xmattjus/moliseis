import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/ui/category/view_models/category_view_model.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';

import '../../../support/category_view_model_test_support.dart';
import '../../../support/command_test_support.dart';
import '../../../support/fake_repositories.dart';
import '../../../support/fixtures.dart';
import '../../../support/ordinary_view_model_lifecycle_support.dart';

void main() {
  testCategoryViewModel('dispose before entry starts no query or write', (
    tester,
    h,
  ) async {
    final vm = h.create()
      ..setSort.run(ContentSort.byDate)
      ..dispose()
      ..dispose();
    await pumpPhysicalCommandDisposal(tester);
    expect(h.places.getByCategoriesCallCount, 0);
    expect(h.events.getByCategoriesCallCount, 0);
    expect(h.settings.contentSortCalls, isEmpty);
    expect(vm.load.debugLiveChildCount, 0);
    expect(h.logger.calls, isEmpty);
  });

  for (final stage in ['places', 'events']) {
    for (final outcome in [
      'success',
      'domain',
      'runtime',
      'type',
      'assertion',
    ]) {
      testCategoryViewModel(
        'dispose during $stage, late $outcome safely settles once',
        (tester, h) async {
          late Completer<Result<List<Place>>> places;
          late Completer<Result<List<Event>>> events;
          h.places.getByCategoriesHandler = (_) => stage == 'places'
              ? places.future
              : Future.value(Result.success([makePlace()]));
          h.events.getByCategoriesHandler = (_) => events.future;
          final uncaught = <Object>[];
          late CategoryViewModel vm;
          runZonedGuarded(() {
            places = Completer<Result<List<Place>>>();
            events = Completer<Result<List<Event>>>();
            vm = h.create();
          }, (error, _) => uncaught.add(error));
          var notifications = 0;
          vm.addListener(() => notifications++);
          await pumpCommandTurns(tester);
          expect(h.events.getByCategoriesCallCount, stage == 'events' ? 1 : 0);
          vm.dispose();
          final count = notifications;
          await pumpPhysicalCommandDisposal(tester);
          expect(vm.load.debugLiveChildCount, 1);
          final failure = switch (outcome) {
            'runtime' => StateError('original'),
            'type' => TypeError(),
            'assertion' => AssertionError('original'),
            _ => TestException('original'),
          };
          final stack = StackTrace.fromString(
            '#0 originalCategoryRepository (category_repository.dart:7:3)',
          );
          if (['runtime', 'type', 'assertion'].contains(outcome)) {
            if (stage == 'places') {
              places.completeError(failure, stack);
            } else {
              events.completeError(failure, stack);
            }
          } else if (stage == 'places') {
            places.complete(
              outcome == 'success'
                  ? Result.success([makePlace()])
                  : Result.error(failure as Exception),
            );
          } else {
            events.complete(
              outcome == 'success'
                  ? Result.success([makeEvent()])
                  : Result.error(failure as Exception),
            );
          }
          await pumpPhysicalCommandDisposal(tester);
          expect(vm.content, isEmpty);
          expect(notifications, count);
          expect(h.events.getByCategoriesCallCount, stage == 'events' ? 1 : 0);
          expect(vm.load.debugLiveChildCount, 0);
          expect(vm.load.debugRetiredChildCount, 1);
          if (outcome == 'assertion') {
            expect(uncaught, [same(failure)]);
            expect(h.logger.calls, isEmpty);
          } else {
            expect(uncaught, isEmpty);
            expect(
              h.logger.calls,
              hasLength(['runtime', 'type'].contains(outcome) ? 1 : 0),
            );
            if (h.logger.calls.isNotEmpty) {
              expect(h.logger.calls.single.error, same(failure));
              expect(
                h.logger.calls.single.stackTrace.toString(),
                contains('category_repository.dart'),
              );
            }
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final source in ['notify', 'terminal']) {
    testCategoryViewModel(
      'reentrant $source revokes owner without notifier failure',
      (tester, h) async {
        h.places.getByCategoriesResult = Result.success([makePlace()]);
        final vm = h.create();
        if (source == 'notify') {
          vm.addListener(vm.dispose);
        } else {
          vm.load.results.addListener(() {
            if (vm.load.results.value.completed) vm.dispose();
          });
        }
        await pumpPhysicalCommandDisposal(tester);
        expect(vm.load.debugLiveChildCount, 0);
        expect(vm.load.debugRetiredChildCount, 1);
        final content = vm.content.toList();
        vm
          ..setSelectedCategories({ContentCategory.nature})
          ..refresh();
        expect(vm.content, content);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testCategoryViewModel(
    'revocation from filter notify prevents queued new query',
    (tester, h) async {
      final vm = h.create();
      await pumpCommandTurns(tester);
      final calls = h.places.getByCategoriesCallCount;
      vm
        ..addListener(vm.dispose)
        ..setSelectedCategories({ContentCategory.nature});
      await pumpPhysicalCommandDisposal(tester);
      expect(h.places.getByCategoriesCallCount, calls);
      expect(vm.content, isEmpty);
    },
  );

  testCategoryViewModel(
    'live runtime retrieval and sort errors stay separate from domain errors',
    (tester, h) async {
      final loadError = TypeError();
      h.places.getByCategoriesHandler = (_) async => throw loadError;
      final vm = h.create();
      await pumpCommandTurns(tester);
      expect(vm.load.results.value.unexpectedError, same(loadError));
      expect(vm.load.results.value.domainError, isNull);
      final sortError = StateError('sort');
      h.settings.onSetContentSort = (_) async => throw sortError;
      vm.setSort.run(ContentSort.byDate);
      await pumpCommandTurns(tester);
      expect(vm.setSort.results.value.unexpectedError, same(sortError));
      expect(vm.sort, ContentSort.byDate);
      expect(h.settings.contentSort, ContentSort.byName);
      expect(h.logger.calls.map((x) => x.error), [
        same(loadError),
        same(sortError),
      ]);
    },
  );
}
