import 'dart:async' show Completer, unawaited;
import 'dart:collection' show UnmodifiableListView;

import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/core/event_time.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/repositories/event_repository.dart';
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/result.dart';

class EventViewModel extends ChangeNotifier {
  EventViewModel({
    required EventRepository repository,
    DateTime Function()? nowUtc,
    EventTimePolicy? eventTimePolicy,
  }) : _eventRepository = repository,
       _nowUtc = nowUtc ?? DateTime.now,
       _eventTimePolicy = eventTimePolicy ?? EventTimePolicy() {
    loadAll = Command0(_loadAll);
    unawaited(loadAll.execute());
    loadByDate = Command1(_loadByDate);
    loadOngoing = Command1(_loadOngoing);
    loadNext = Command1(_loadNext);
  }

  final EventRepository _eventRepository;
  final DateTime Function() _nowUtc;
  final EventTimePolicy _eventTimePolicy;

  late Command0<void> loadAll;
  late Command1<void, EventCalendarDate> loadByDate;

  /// Retrieves ongoing models for the supplied discovery-pass UTC snapshot.
  late Command1<void, DateTime> loadOngoing;

  /// Retrieves upcoming models for the same discovery-pass UTC snapshot.
  late Command1<void, DateTime> loadNext;

  var _all = <Event>[];
  var _byDate = <Event>[];
  EventCalendarDate? _loadedDate;
  int? _loadedDateRevision;
  var _yearlyRevision = 0;
  var _ongoing = <Event>[];
  var _next = <Event>[];
  bool _disposed = false;
  bool _homeRefreshPending = false;
  Future<void>? _homeRefresh;
  final _commandWaits = <void Function()>{};
  late EventCalendarDate _selectedDate = currentCalendarDate;

  UnmodifiableListView<Event> get all => UnmodifiableListView(_all);
  UnmodifiableListView<Event> get byMonth => UnmodifiableListView(_byDate);

  /// Last successful ongoing collection in repository order, exposed read-only.
  UnmodifiableListView<Event> get ongoing => UnmodifiableListView(_ongoing);
  UnmodifiableListView<Event> get next => UnmodifiableListView(_next);
  EventCalendarDate get selectedDate => _selectedDate;

  EventCalendarDate get currentCalendarDate =>
      _eventTimePolicy.currentCalendarDate(_nowUtc().toUtc());

  /// Returns whether [event] should appear on [day] in the calendar.
  ///
  /// The check is inclusive of both start and end dates and compares only
  /// calendar days, ignoring timestamp precision.
  bool isEventOnDay(Event event, EventCalendarDate day) {
    final startDate = _eventTimePolicy.calendarDateForUtc(event.startDate);

    if (event.endDate == null) {
      return startDate == day;
    }

    final endDate = _eventTimePolicy.calendarDateForUtc(event.endDate!);

    return _calendarDateCompare(day, startDate) >= 0 &&
        _calendarDateCompare(day, endDate) <= 0;
  }

  /// Returns events for [day], sorted by start date and then remote id.
  List<Event> getEventsOnDay(EventCalendarDate day) {
    return _all.where((event) => isEventOnDay(event, day)).toList()
      ..sort((a, b) {
        final startDateCompare = a.startDate.compareTo(b.startDate);

        if (startDateCompare != 0) {
          return startDateCompare;
        }

        return a.remoteId.compareTo(b.remoteId);
      });
  }

  Future<Result<void>> _loadAll() async {
    final result = await _eventRepository.getByCurrentYear();
    if (_disposed) return result.map((_) {});

    final events = result.getOrNull();
    if (events != null) {
      _all = events;
      _yearlyRevision++;
      _byDate = getEventsOnDay(_selectedDate);
      if (_byDate.isNotEmpty) {
        _loadedDate = _selectedDate;
        _loadedDateRevision = _yearlyRevision;
      } else {
        _loadedDate = null;
        _loadedDateRevision = null;
      }
    }

    notifyListeners();

    return result;
  }

  Future<Result<void>> _loadByDate(EventCalendarDate date) async {
    if (_loadedDate == date && _loadedDateRevision == _yearlyRevision) {
      return const Result.success(null);
    }

    _selectedDate = date;

    notifyListeners();

    _byDate = getEventsOnDay(date);

    if (_byDate.isNotEmpty) {
      _loadedDate = date;
      _loadedDateRevision = _yearlyRevision;
      notifyListeners();
      return const Result.success(null);
    }

    final yearlyRevision = _yearlyRevision;
    final result = await _eventRepository.getByDate(date);

    final events = result.getOrNull();
    if (events != null &&
        _selectedDate == date &&
        _yearlyRevision == yearlyRevision) {
      _byDate = events;
      _loadedDate = date;
      _loadedDateRevision = yearlyRevision;
    }

    notifyListeners();

    return result;
  }

  int _calendarDateCompare(EventCalendarDate left, EventCalendarDate right) {
    final year = left.year.compareTo(right.year);
    if (year != 0) return year;
    final month = left.month.compareTo(right.month);
    return month != 0 ? month : left.day.compareTo(right.day);
  }

  Future<Result<void>> _loadOngoing(DateTime snapshotUtc) async {
    if (_disposed) return const Result.success(null);
    final result = await _eventRepository.getOngoingEvents(snapshotUtc);
    if (_disposed) return result.map((_) {});

    return result.map((events) {
      _ongoing = events;
      notifyListeners();
    });
  }

  Future<Result<void>> _loadNext(DateTime snapshotUtc) async {
    if (_disposed) return const Result.success(null);
    final result = await _eventRepository.getNextEvents(snapshotUtc);
    if (_disposed) return result.map((_) {});

    return result.map((events) {
      _next = events;
      notifyListeners();
    });
  }

  /// Refreshes both discovery collections with one UTC snapshot per pass.
  ///
  /// Concurrent requests share the in-flight Future and request a subsequent
  /// coalesced pass, whose snapshot is captured only when that pass starts.
  /// Each retrieval command exposes its own error and retains its valid state.
  Future<void> refreshHomeDiscovery() {
    if (_disposed) return Future.value();
    _homeRefreshPending = true;
    final runningRefresh = _homeRefresh;
    if (runningRefresh != null) return runningRefresh;

    final completion = Completer<void>();
    _homeRefresh = completion.future;
    unawaited(_runHomeDiscovery(completion));
    return completion.future;
  }

  Future<void> _runHomeDiscovery(Completer<void> completion) async {
    try {
      while (!_disposed && _homeRefreshPending) {
        _homeRefreshPending = false;
        while (!_disposed && (loadOngoing.running || loadNext.running)) {
          await _waitForCommand(loadOngoing);
          await _waitForCommand(loadNext);
        }
        if (_disposed) break;

        final snapshotUtc = _nowUtc().toUtc();
        await loadOngoing.execute(snapshotUtc);
        if (_disposed) break;
        await loadNext.execute(snapshotUtc);
      }
      _homeRefresh = null;
      completion.complete();
    } on Object catch (error, stackTrace) {
      _homeRefresh = null;
      completion.completeError(error, stackTrace);
    }
  }

  Future<void> _waitForCommand(Command<void> command) {
    if (_disposed || !command.running) return Future.value();
    final completion = Completer<void>();
    late void Function() listener;
    void finish() {
      command.removeListener(listener);
      _commandWaits.remove(finish);
      if (!completion.isCompleted) completion.complete();
    }

    listener = () {
      if (!command.running) finish();
    };
    _commandWaits.add(finish);
    command.addListener(listener);
    return completion.future;
  }

  @override
  void dispose() {
    _disposed = true;
    _homeRefreshPending = false;
    for (final finish in _commandWaits.toList()) {
      finish();
    }
    super.dispose();
  }
}
