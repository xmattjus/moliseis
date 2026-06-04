import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:moliseis/domain/core/sync_dto.dart';
import 'package:moliseis/domain/models/city.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/repositories/event_repository.dart';
import 'package:moliseis/ui/event/view_models/event_view_model.dart';
import 'package:moliseis/ui/event/widgets/components/events_vertical_calendar_day_markers.dart';
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/result.dart';

void main() {
  group('EventViewModel.isEventOnDay', () {
    late EventViewModel viewModel;

    setUp(() {
      viewModel = EventViewModel(repository: _FakeEventRepository());
    });

    test('returns true for each day in an inclusive multi-day span', () {
      final event = _buildEventContent(
        startDate: DateTime(2026, 3, 10, 10, 30),
        endDate: DateTime(2026, 3, 12, 22, 45),
      );

      expect(viewModel.isEventOnDay(event, DateTime(2026, 3, 9)), isFalse);
      expect(viewModel.isEventOnDay(event, DateTime(2026, 3, 10)), isTrue);
      expect(viewModel.isEventOnDay(event, DateTime(2026, 3, 11)), isTrue);
      expect(viewModel.isEventOnDay(event, DateTime(2026, 3, 12)), isTrue);
      expect(viewModel.isEventOnDay(event, DateTime(2026, 3, 13)), isFalse);
    });

    test('treats null end date as a single-day event', () {
      final event = _buildEventContent(startDate: DateTime(2026, 3, 15, 18));

      expect(viewModel.isEventOnDay(event, DateTime(2026, 3, 14)), isFalse);
      expect(viewModel.isEventOnDay(event, DateTime(2026, 3, 15)), isTrue);
      expect(viewModel.isEventOnDay(event, DateTime(2026, 3, 16)), isFalse);
    });

    test('falls back to start day when end date is before start date', () {
      final event = _buildEventContent(
        startDate: DateTime(2026, 3, 20, 10),
        endDate: DateTime(2026, 3, 19, 10),
      );

      expect(viewModel.isEventOnDay(event, DateTime(2026, 3, 19)), isFalse);
      expect(viewModel.isEventOnDay(event, DateTime(2026, 3, 20)), isTrue);
      expect(viewModel.isEventOnDay(event, DateTime(2026, 3, 21)), isFalse);
    });
  });

  group('EventViewModel.loadByDate', () {
    test(
      'includes multi-day event on middle day when repository getByDate is '
      'empty',
      () async {
        final event = _buildEvent(
          remoteId: 42,
          startDate: DateTime(2026, 3, 10, 10, 30),
          endDate: DateTime(2026, 3, 12, 22, 45),
        );

        final repository = _FakeEventRepository(
          currentYearEvents: [event],
        );
        final viewModel = EventViewModel(repository: repository);

        await _waitForCommand(viewModel.loadAll);
        await viewModel.loadByDate.execute(DateTime(2026, 3, 11));
        await _waitForCommand(viewModel.loadByDate);

        expect(viewModel.byMonth, hasLength(1));
        expect(viewModel.byMonth.first.remoteId, 42);
        expect(repository.getByDateCallCount, 0);
      },
    );

    test('returns cached events on same day without repository call', () async {
      final event = _buildEvent(
        remoteId: 7,
        startDate: DateTime(2026, 3, 11, 8),
      );
      final repository = _FakeEventRepository(currentYearEvents: [event]);
      final viewModel = EventViewModel(repository: repository);

      await _waitForCommand(viewModel.loadAll);
      await viewModel.loadByDate.execute(DateTime(2026, 3, 11));
      await _waitForCommand(viewModel.loadByDate);

      expect(repository.getByDateCallCount, 0);

      await viewModel.loadByDate.execute(DateTime(2026, 3, 11));
      await _waitForCommand(viewModel.loadByDate);

      expect(repository.getByDateCallCount, 0);
    });
  });

  group('EventViewModel.getEventsOnDay', () {
    test('returns events sorted by start date and remote id', () async {
      final repository = _FakeEventRepository(
        currentYearEvents: [
          _buildEvent(remoteId: 2, startDate: DateTime(2026, 3, 11, 10)),
          _buildEvent(remoteId: 1, startDate: DateTime(2026, 3, 11, 10)),
          _buildEvent(remoteId: 3, startDate: DateTime(2026, 3, 11, 9)),
        ],
      );
      final viewModel = EventViewModel(repository: repository);

      await _waitForCommand(viewModel.loadAll);

      expect(
        viewModel
            .getEventsOnDay(DateTime(2026, 3, 11))
            .map((event) => event.remoteId)
            .toList(growable: false),
        <int>[3, 1, 2],
      );
    });
  });

  group('EventsVerticalCalendarDayMarkers', () {
    testWidgets('maps marker colors deterministically from remote id', (
      tester,
    ) async {
      const expectedColor = Color(0xFF00897B);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventsVerticalCalendarDayMarkers(
              events: [
                _buildEventContent(
                  remoteId: 5,
                  startDate: DateTime(2026, 3, 11, 8),
                ),
                _buildEventContent(
                  remoteId: 13,
                  startDate: DateTime(2026, 3, 11, 9),
                ),
              ],
            ),
          ),
        ),
      );

      final markerColorCount = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .where(
            (box) => (box.decoration as BoxDecoration).color == expectedColor,
          )
          .length;

      expect(markerColorCount, 2);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              (widget.decoration as BoxDecoration).shape == BoxShape.circle,
        ),
        findsNWidgets(2),
      );
    });
  });
}

final class _FakeEventRepository implements EventRepository {
  _FakeEventRepository({
    List<Event> currentYearEvents = const [],
    List<Event> byDateEvents = const [],
  }) : _currentYearEvents = currentYearEvents,
       _byDateEvents = byDateEvents;

  final List<Event> _currentYearEvents;
  final List<Event> _byDateEvents;
  int getByDateCallCount = 0;

  @override
  Future<Result<List<Event>>> getByCurrentYear() async {
    return Result.success(_currentYearEvents);
  }

  @override
  Future<Result<List<Event>>> getByDate(DateTime date) async {
    getByDateCallCount++;
    return Result.success(_byDateEvents);
  }

  @override
  Future<Result<List<Event>>> getByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    return const Result.success(<Event>[]);
  }

  @override
  Future<Result<List<Event>>> getByCategories(
    Set<ContentCategory> categories, {
    ContentSort sort = ContentSort.byName,
  }) async {
    return const Result.success(<Event>[]);
  }

  @override
  Future<Result<List<Event>>> getByCoordinates(List<double> coordinates) async {
    return const Result.success(<Event>[]);
  }

  @override
  Future<Result<Event>> getById(int id) async {
    return Result.error(Exception('Not needed in this test.'));
  }

  @override
  Future<Result<List<int>>> getNextEventIds() async {
    return const Result.success(<int>[]);
  }

  @override
  Future<Result<List<int>>> getFavouriteEventIds() async {
    return const Result.success(<int>[]);
  }

  @override
  Future<Result<void>> setFavouriteEvent(int id, bool save) async {
    return const Result.success(null);
  }

  @override
  Future<Result<List<SyncDto>>> prepareSync() async =>
      const Result.success(<SyncDto>[]);

  @override
  Result<void> commitSync(List<SyncDto> dtos) => const Result.success(null);
}

Future<void> _waitForCommand(Command<void> command) async {
  while (command.running) {
    await Future<void>.delayed(Duration.zero);
  }
}

City _testCity() => City(
  remoteId: 0,
  name: 'Molise',
  createdAt: DateTime(2026),
  modifiedAt: DateTime(2026),
);

Event _buildEvent({
  required int remoteId,
  required DateTime startDate,
  DateTime? endDate,
}) {
  return Event(
    remoteId: remoteId,
    name: 'Event $remoteId',
    description: '',
    startDate: startDate,
    endDate: endDate,
    category: ContentCategory.unknown,
    createdAt: DateTime(2026),
    modifiedAt: DateTime(2026),
    city: _testCity(),
    coordinates: const LatLng(0, 0),
    media: const [],
    isSaved: false,
  );
}

Event _buildEventContent({
  required DateTime startDate,
  DateTime? endDate,
  int remoteId = 1,
}) {
  return Event(
    category: ContentCategory.experience,
    city: _testCity(),
    coordinates: const LatLng(0, 0),
    createdAt: DateTime(2026),
    description: 'Test event',
    media: const [],
    modifiedAt: DateTime(2026),
    name: 'Event',
    remoteId: remoteId,
    isSaved: false,
    startDate: startDate,
    endDate: endDate,
  );
}
