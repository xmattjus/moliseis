import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/use-cases/favourite_get_ids_use_case.dart';
import 'package:moliseis/ui/favourite/view_models/favourite_view_model.dart';
import 'package:moliseis/ui/favourite/widgets/favourite_button.dart';
import 'package:moliseis/utils/result.dart';

import '../../../support/fake_repositories.dart';
import '../../../support/favourite_button_harness.dart';
import '../../../support/fixtures.dart';

void main() {
  testWidgets('favourite success and Undo persist true then false', (
    tester,
  ) async {
    final event = makeEvent();
    final eventRepository = FakeEventRepository();
    final viewModel = FavouriteViewModel(
      favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
        eventRepository: eventRepository,
        placeRepository: FakePlaceRepository(),
      ),
    );
    addTearDown(viewModel.dispose);

    await tester.pumpWidget(
      favouriteButtonHarness(
        viewModel: viewModel,
        child: FavouriteButton(content: event),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(IconButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(viewModel.isFavourite(event), isTrue);
    expect(find.text('Aggiunto ai preferiti'), findsOneWidget);
    expect(find.text('Annulla'), findsOneWidget);
    expect(
      eventRepository.setFavouriteEventCalls,
      equals([(id: 1, save: true)]),
    );

    await tester.tap(find.text('Annulla'));
    await tester.pump();

    expect(viewModel.isFavourite(event), isFalse);
    expect(
      eventRepository.setFavouriteEventCalls,
      equals([(id: 1, save: true), (id: 1, save: false)]),
    );
  });

  testWidgets(
    'a failed forward action rolls back and shows only generic error',
    (
      tester,
    ) async {
      final event = makeEvent();
      final viewModel = FavouriteViewModel(
        favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
          eventRepository: FakeEventRepository(
            setFavouriteEventResult: Result.error(
              TestException('write failed'),
            ),
          ),
          placeRepository: FakePlaceRepository(),
        ),
      );
      addTearDown(viewModel.dispose);

      await tester.pumpWidget(
        favouriteButtonHarness(
          viewModel: viewModel,
          child: FavouriteButton(content: event),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(IconButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(viewModel.isFavourite(event), isFalse);
      expect(find.text('Aggiunto ai preferiti'), findsNothing);
      expect(find.text('Annulla'), findsNothing);
      expect(
        find.text('Si è verificato un errore, riprova più tardi'),
        findsOneWidget,
      );
    },
  );

  testWidgets('a failed Undo restores the successfully persisted state', (
    tester,
  ) async {
    final event = makeEvent();
    final eventRepository = FakeEventRepository(
      setFavouriteEventHandler: (_, save) => Future.value(
        save
            ? const Result.success(null)
            : Result.error(TestException('undo failed')),
      ),
    );
    final viewModel = FavouriteViewModel(
      favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
        eventRepository: eventRepository,
        placeRepository: FakePlaceRepository(),
      ),
    );
    addTearDown(viewModel.dispose);

    await tester.pumpWidget(
      favouriteButtonHarness(
        viewModel: viewModel,
        child: FavouriteButton(content: event),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(IconButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('Annulla'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();

    expect(viewModel.isFavourite(event), isTrue);
    expect(
      eventRepository.setFavouriteEventCalls,
      equals([(id: 1, save: true), (id: 1, save: false)]),
    );
    expect(
      find.text('Si è verificato un errore, riprova più tardi'),
      findsOneWidget,
    );
  });

  testWidgets('a later favourite action replaces the prior Undo action', (
    tester,
  ) async {
    final firstEvent = makeEvent();
    final secondEvent = makeEvent(remoteId: 2);
    final eventRepository = FakeEventRepository();
    final viewModel = FavouriteViewModel(
      favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
        eventRepository: eventRepository,
        placeRepository: FakePlaceRepository(),
      ),
    );
    addTearDown(viewModel.dispose);

    await tester.pumpWidget(
      favouriteButtonHarness(
        viewModel: viewModel,
        child: Column(
          children: [
            KeyedSubtree(
              key: const ValueKey('first-favourite-button'),
              child: FavouriteButton(content: firstEvent),
            ),
            KeyedSubtree(
              key: const ValueKey('second-favourite-button'),
              child: FavouriteButton(content: secondEvent),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('first-favourite-button')),
        matching: find.byType(IconButton),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('second-favourite-button')),
        matching: find.byType(IconButton),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Aggiunto ai preferiti'), findsOneWidget);
    expect(find.text('Annulla'), findsOneWidget);

    await tester.tap(find.text('Annulla'));
    await tester.pump();

    expect(viewModel.isFavourite(firstEvent), isTrue);
    expect(viewModel.isFavourite(secondEvent), isFalse);
    expect(
      eventRepository.setFavouriteEventCalls,
      equals([
        (id: 1, save: true),
        (id: 2, save: true),
        (id: 2, save: false),
      ]),
    );
  });

  testWidgets(
    'a pending later action revokes prior Undo until its write succeeds',
    (tester) async {
      final pendingSecondWrite = Completer<Result<void>>();
      final firstEvent = makeEvent();
      final secondEvent = makeEvent(remoteId: 2);
      final eventRepository = FakeEventRepository(
        setFavouriteEventHandler: (id, _) => id == secondEvent.remoteId
            ? pendingSecondWrite.future
            : Future.value(const Result<void>.success(null)),
      );
      final viewModel = FavouriteViewModel(
        favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
          eventRepository: eventRepository,
          placeRepository: FakePlaceRepository(),
        ),
      );
      addTearDown(viewModel.dispose);

      await tester.pumpWidget(
        favouriteButtonHarness(
          viewModel: viewModel,
          child: Column(
            children: [
              KeyedSubtree(
                key: const ValueKey('first-favourite-button'),
                child: FavouriteButton(content: firstEvent),
              ),
              KeyedSubtree(
                key: const ValueKey('second-favourite-button'),
                child: FavouriteButton(content: secondEvent),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final firstButton = find.descendant(
        of: find.byKey(const ValueKey('first-favourite-button')),
        matching: find.byType(IconButton),
      );
      final secondButton = find.descendant(
        of: find.byKey(const ValueKey('second-favourite-button')),
        matching: find.byType(IconButton),
      );
      await tester.tap(firstButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Annulla'), findsOneWidget);

      await tester.tap(secondButton);
      await tester.pump();

      expect(viewModel.isFavourite(secondEvent), isTrue);
      expect(tester.widget<IconButton>(firstButton).onPressed, isNull);
      expect(tester.widget<IconButton>(secondButton).onPressed, isNull);
      expect(find.text('Aggiunto ai preferiti'), findsNothing);
      expect(find.text('Annulla'), findsNothing);

      pendingSecondWrite.complete(const Result.success(null));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Aggiunto ai preferiti'), findsOneWidget);
      expect(find.text('Annulla'), findsOneWidget);
      expect(
        eventRepository.setFavouriteEventCalls,
        equals([(id: 1, save: true), (id: 2, save: true)]),
      );
    },
  );

  testWidgets(
    'a failed later action shows an error without reviving prior Undo',
    (tester) async {
      final pendingSecondWrite = Completer<Result<void>>();
      final firstEvent = makeEvent();
      final secondEvent = makeEvent(remoteId: 2);
      final eventRepository = FakeEventRepository(
        setFavouriteEventHandler: (id, _) => id == secondEvent.remoteId
            ? pendingSecondWrite.future
            : Future.value(const Result<void>.success(null)),
      );
      final viewModel = FavouriteViewModel(
        favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
          eventRepository: eventRepository,
          placeRepository: FakePlaceRepository(),
        ),
      );
      addTearDown(viewModel.dispose);

      await tester.pumpWidget(
        favouriteButtonHarness(
          viewModel: viewModel,
          child: Column(
            children: [
              KeyedSubtree(
                key: const ValueKey('first-favourite-button'),
                child: FavouriteButton(content: firstEvent),
              ),
              KeyedSubtree(
                key: const ValueKey('second-favourite-button'),
                child: FavouriteButton(content: secondEvent),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('first-favourite-button')),
          matching: find.byType(IconButton),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Annulla'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('second-favourite-button')),
          matching: find.byType(IconButton),
        ),
      );
      await tester.pump();

      expect(find.text('Aggiunto ai preferiti'), findsNothing);
      expect(find.text('Annulla'), findsNothing);

      pendingSecondWrite.complete(Result.error(TestException('write failed')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(viewModel.isFavourite(secondEvent), isFalse);
      expect(find.text('Annulla'), findsNothing);
      expect(
        find.text('Si è verificato un errore, riprova più tardi'),
        findsOneWidget,
      );
    },
  );

  testWidgets('unmounting before delayed feedback is context-safe', (
    tester,
  ) async {
    final pendingWrite = Completer<Result<void>>();
    final event = makeEvent();
    final viewModel = FavouriteViewModel(
      favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
        eventRepository: FakeEventRepository(
          setFavouriteEventHandler: (_, _) => pendingWrite.future,
        ),
        placeRepository: FakePlaceRepository(),
      ),
    );
    addTearDown(viewModel.dispose);

    await tester.pumpWidget(
      favouriteButtonHarness(
        viewModel: viewModel,
        child: FavouriteButton(content: event),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(IconButton));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    pendingWrite.complete(Result.error(TestException('late failure')));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
