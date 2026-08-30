import 'dart:async' show unawaited;
import 'dart:collection' show UnmodifiableListView;

import 'package:flutter/material.dart';
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
    loadNext = Command0(_loadNext);
    loadNextIds = Command0(_loadNextIds);
  }

  final EventRepository _eventRepository;
  final DateTime Function() _nowUtc;
  final EventTimePolicy _eventTimePolicy;

  late Command0<void> loadAll;
  late Command1<void, EventCalendarDate> loadByDate;
  late Command0<void> loadNext;
  late Command0<void> loadNextIds;

  var _all = <Event>[];
  var _byDate = <Event>[];
  EventCalendarDate? _loadedDate;
  int? _loadedDateRevision;
  var _yearlyRevision = 0;
  final _next = <Event>[];
  var _nextIds = <int>[];
  late EventCalendarDate _selectedDate = currentCalendarDate;

  UnmodifiableListView<Event> get all => UnmodifiableListView(_all);
  UnmodifiableListView<Event> get byMonth => UnmodifiableListView(_byDate);
  UnmodifiableListView<Event> get next => UnmodifiableListView(_next);
  UnmodifiableListView<int> get nextIds => UnmodifiableListView(_nextIds);
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

  Future<Result<void>> _loadNextIds() async {
    final result = await _eventRepository.getNextEventIds();

    final ids = result.getOrNull();
    if (ids != null) _nextIds = ids;

    notifyListeners();

    // Only trigger the next-events fetch when IDs were loaded successfully.
    if (result.isSuccess) unawaited(loadNext.execute());

    return result;
  }

  Future<Result<void>> _loadNext() async {
    _next.clear();

    for (final id in _nextIds) {
      final event = (await _eventRepository.getById(id)).getOrNull();
      if (event != null) _next.add(event);
    }

    notifyListeners();

    return const Result.success(null);
  }
}
