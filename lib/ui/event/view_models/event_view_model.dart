import 'dart:async';
import 'dart:collection' show UnmodifiableListView;

import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/core/event_time.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/repositories/event_repository.dart';
import 'package:moliseis/utils/restartable_command.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';

class EventViewModel extends ChangeNotifier {
  EventViewModel({
    required EventRepository repository,
    DateTime Function()? nowUtc,
    EventTimePolicy? eventTimePolicy,
  }) : _eventRepository = repository,
       _nowUtc = nowUtc ?? DateTime.now,
       _eventTimePolicy = eventTimePolicy ?? EventTimePolicy() {
    loadAll = createResultCommandNoParam(
      _loadAll,
      debugName: 'event_view_model.loadAll',
    );
    loadByDate = RestartableCommand(
      _loadByDate,
      debugName: 'event_view_model.loadByDate',
    );
    loadByDate.results.addListener(_commitDay);
    loadOngoing = createResultCommand(
      _loadOngoing,
      debugName: 'event_view_model.loadOngoing',
    );
    loadNext = createResultCommand(
      _loadNext,
      debugName: 'event_view_model.loadNext',
    );
    loadAll.run();
  }

  final EventRepository _eventRepository;
  final DateTime Function() _nowUtc;
  final EventTimePolicy _eventTimePolicy;

  late final ResultCommand<void, void> loadAll;
  late final RestartableCommand<EventDayRequest, List<Event>> loadByDate;
  late final ResultCommand<DateTime, void> loadOngoing;
  late final ResultCommand<DateTime, void> loadNext;

  EventDayRequest? _currentDayRequest;

  /// The request with publication authority for the selected day.
  EventDayRequest? get currentDayRequest => _currentDayRequest;

  /// Whether the public day snapshot belongs to the current dataset/selection.
  bool get hasCurrentDaySnapshot {
    final request = _currentDayRequest;
    return request != null &&
        identical(loadByDate.results.value.paramData, request) &&
        request.date == _selectedDate &&
        request.revision == _yearlyRevision;
  }

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
  Completer<void>? _homeCompletion;
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
    if (_disposed) return Result.error(Exception('Event owner unavailable'));
    final result = await _eventRepository.getByCurrentYear();
    if (_disposed) return result.map((_) {});
    final events = result.getOrNull();
    if (events != null) {
      _all = events;
      _yearlyRevision++;
      final candidate = getEventsOnDay(_selectedDate);
      _byDate = candidate;
      _loadedDate = candidate.isNotEmpty ? _selectedDate : null;
      _loadedDateRevision = candidate.isNotEmpty ? _yearlyRevision : null;
      if (_currentDayRequest != null) {
        _admitDay(
          _selectedDate,
          candidate: candidate,
          cacheable: candidate.isNotEmpty,
        );
      }
    }
    if (!_disposed) notifyListeners();
    return result.map((_) {});
  }

  /// Selects immediately, preserving a successful current cache.
  void selectDate(EventCalendarDate date) {
    if (_disposed) return;
    if (date == _selectedDate &&
        _loadedDate == date &&
        _loadedDateRevision == _yearlyRevision &&
        !loadByDate.isRunningSync.value &&
        hasCurrentDaySnapshot &&
        loadByDate.results.value.completed) {
      return;
    }
    final candidate = getEventsOnDay(date);
    _admitDay(
      date,
      candidate: candidate.isEmpty ? null : candidate,
      cacheable: true,
    );
    if (!_disposed) notifyListeners();
  }

  void _admitDay(
    EventCalendarDate date, {
    required List<Event>? candidate,
    required bool cacheable,
  }) {
    final request = EventDayRequest._(
      date,
      _yearlyRevision,
      candidate == null ? null : List.unmodifiable(candidate),
      cacheable,
    );
    _currentDayRequest = request;
    _loadedDate = null;
    _loadedDateRevision = null;
    _selectedDate = date;
    _byDate = candidate ?? [];
    loadByDate.run(request);
  }

  Future<Result<List<Event>>> _loadByDate(EventDayRequest request) async {
    if (_disposed) return Result.error(Exception('Event owner unavailable'));
    final candidate = request.candidate;
    if (candidate != null) return Result.success(candidate);
    return await _eventRepository.getByDate(request.date);
  }

  void _commitDay() {
    if (_disposed || !hasCurrentDaySnapshot) return;
    final snapshot = loadByDate.results.value;
    if (!snapshot.completed) return;
    final request = _currentDayRequest!;
    _byDate = snapshot.data!.getOrNull()!;
    if (request.cacheable) {
      _loadedDate = request.date;
      _loadedDateRevision = request.revision;
    }
    notifyListeners();
  }

  int _calendarDateCompare(EventCalendarDate left, EventCalendarDate right) {
    final year = left.year.compareTo(right.year);
    if (year != 0) return year;
    final month = left.month.compareTo(right.month);
    return month != 0 ? month : left.day.compareTo(right.day);
  }

  Future<Result<void>> _loadOngoing(DateTime snapshotUtc) async {
    if (_disposed) return Result.error(Exception('Event owner unavailable'));
    final result = await _eventRepository.getOngoingEvents(snapshotUtc);
    if (_disposed) return result.map((_) {});

    return result.map((events) {
      _ongoing = events;
      notifyListeners();
    });
  }

  Future<Result<void>> _loadNext(DateTime snapshotUtc) async {
    if (_disposed) return Result.error(Exception('Event owner unavailable'));
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
    _homeCompletion = completion;
    unawaited(_runHomeDiscovery(completion));
    return completion.future;
  }

  Future<void> _runHomeDiscovery(Completer<void> completion) async {
    try {
      while (!_disposed && _homeRefreshPending) {
        _homeRefreshPending = false;
        while (!_disposed &&
            (loadOngoing.isRunningSync.value || loadNext.isRunningSync.value)) {
          await _waitForCommand(loadOngoing);
          await _waitForCommand(loadNext);
        }
        if (_disposed) break;

        final snapshotUtc = _nowUtc().toUtc();
        loadOngoing.run(snapshotUtc);
        await _waitForCommand(loadOngoing);
        if (_disposed) break;
        while (!_disposed && loadNext.isRunningSync.value) {
          await _waitForCommand(loadNext);
        }
        if (_disposed) break;
        loadNext.run(snapshotUtc);
        await _waitForCommand(loadNext);
      }
      if (identical(_homeCompletion, completion)) {
        _homeCompletion = null;
        _homeRefresh = null;
      }
      if (!completion.isCompleted) completion.complete();
    } on Object catch (error, stackTrace) {
      _homeRefresh = null;
      if (!completion.isCompleted) completion.completeError(error, stackTrace);
    }
  }

  Future<void> _waitForCommand(ResultCommand<DateTime, void> command) {
    if (_disposed || !command.isRunningSync.value) return Future.value();
    final completion = Completer<void>();
    late void Function() listener;
    void finish() {
      command.isRunningSync.removeListener(listener);
      _commandWaits.remove(finish);
      if (!completion.isCompleted) completion.complete();
    }

    listener = () {
      if (!command.isRunningSync.value) finish();
    };
    _commandWaits.add(finish);
    command.isRunningSync.addListener(listener);
    if (_disposed || !command.isRunningSync.value) finish();
    return completion.future;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _homeRefreshPending = false;
    final completion = _homeCompletion;
    _homeCompletion = null;
    _homeRefresh = null;
    if (completion != null && !completion.isCompleted) completion.complete();
    for (final finish in _commandWaits.toList()) {
      finish();
    }
    loadByDate.results.removeListener(_commitDay);
    loadByDate.dispose();
    scheduleMicrotask(super.dispose);
    _releaseOrdinary(loadAll);
    _releaseOrdinary(loadOngoing);
    _releaseOrdinary(loadNext);
  }

  // Keep physically running commands alive through upstream error routing.
  void _releaseOrdinary<P>(ResultCommand<P, void> command) {
    var queued = false;
    var invalidated = false;
    var released = false;
    late VoidCallback onRunningChanged;
    void requestCleanup() {
      if (queued || released) return;
      queued = true;
      invalidated = false;
      scheduleMicrotask(() {
        unawaited(
          Future<void>(() {
            queued = false;
            if (released || command.isRunningSync.value) return;
            if (invalidated) {
              requestCleanup();
              return;
            }
            command.isRunningSync.removeListener(onRunningChanged);
            released = true;
            command.dispose();
          }),
        );
      });
    }

    onRunningChanged = () {
      invalidated = true;
      if (!command.isRunningSync.value) requestCleanup();
    };
    command.isRunningSync.addListener(onRunningChanged);
    if (!command.isRunningSync.value) requestCleanup();
  }
}

/// Immutable identity for one day selection against an annual dataset revision.
class EventDayRequest {
  EventDayRequest._(this.date, this.revision, this.candidate, this.cacheable);
  final EventCalendarDate date;
  final int revision;
  final List<Event>? candidate;
  final bool cacheable;
}
