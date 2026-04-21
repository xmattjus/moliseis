import 'dart:collection' show UnmodifiableListView;

import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/repositories/event_repository.dart';
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/result.dart';
import 'package:paged_vertical_calendar/utils/date_utils.dart';

class EventViewModel extends ChangeNotifier {
  final EventRepository _eventRepository;

  late Command0<void> loadAll;
  late Command1<void, DateTime> loadByDate;
  late Command0<void> loadNext;
  late Command0<void> loadNextIds;

  EventViewModel({required EventRepository repository})
    : _eventRepository = repository {
    loadAll = Command0(_loadAll)..execute();
    loadByDate = Command1(_loadByDate);
    loadNext = Command0(_loadNext);
    loadNextIds = Command0(_loadNextIds);
  }

  var _all = <Event>[];
  var _byDate = <Event>[];
  final _next = <Event>[];
  var _nextIds = <int>[];
  var _selectedDate = DateTime.now();

  UnmodifiableListView<Event> get all => UnmodifiableListView(_all);
  UnmodifiableListView<Event> get byMonth => UnmodifiableListView(_byDate);
  UnmodifiableListView<Event> get next => UnmodifiableListView(_next);
  UnmodifiableListView<int> get nextIds => UnmodifiableListView(_nextIds);
  DateTime get selectedDate => _selectedDate;

  /// Returns whether [event] should appear on [day] in the calendar.
  ///
  /// The check is inclusive of both start and end dates and compares only
  /// calendar days, ignoring timestamp precision.
  bool isEventOnDay(Event event, DateTime day) {
    final startDate = DateTime(
      event.startDate.year,
      event.startDate.month,
      event.startDate.day,
    );
    final targetDay = DateTime(day.year, day.month, day.day);

    if (event.endDate == null) {
      return startDate.isSameDay(targetDay);
    }

    final endDate = DateTime(
      event.endDate!.year,
      event.endDate!.month,
      event.endDate!.day,
    );

    // Defensive guard for malformed ranges from upstream data.
    if (endDate.isBefore(startDate)) {
      return startDate.isSameDay(targetDay);
    }

    return !targetDay.isBefore(startDate) && !targetDay.isAfter(endDate);
  }

  /// Returns events for [day], sorted by start date and then remote id.
  List<Event> getEventsOnDay(DateTime day) {
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
    if (events != null) _all = events;

    notifyListeners();

    return result;
  }

  Future<Result<void>> _loadByDate(DateTime date) async {
    if (date.isSameDay(_selectedDate)) {
      return const Result.success(null);
    }

    _selectedDate = date;

    notifyListeners();

    _byDate = getEventsOnDay(date);

    if (_byDate.isNotEmpty) {
      notifyListeners();
      return const Result.success(null);
    }

    final result = await _eventRepository.getByDate(date);

    final events = result.getOrNull();
    if (events != null) _byDate = events;

    notifyListeners();

    return result;
  }

  Future<Result<void>> _loadNextIds() async {
    final result = await _eventRepository.getNextEventIds();

    final ids = result.getOrNull();
    if (ids != null) _nextIds = ids;

    notifyListeners();

    // Only trigger the next-events fetch when IDs were loaded successfully.
    if (result.isSuccess) loadNext.execute();

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
