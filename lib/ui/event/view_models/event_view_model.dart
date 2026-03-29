import 'dart:collection' show UnmodifiableListView;

import 'package:flutter/material.dart';
import 'package:moliseis/data/sources/event.dart';
import 'package:moliseis/domain/models/event_content.dart';
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

  var _all = <EventContent>[];
  var _byDate = <EventContent>[];
  final _next = <EventContent>[];
  var _nextIds = <int>[];
  var _selectedDate = DateTime.now();

  UnmodifiableListView<EventContent> get all => UnmodifiableListView(_all);
  UnmodifiableListView<EventContent> get byMonth =>
      UnmodifiableListView(_byDate);
  UnmodifiableListView<EventContent> get next => UnmodifiableListView(_next);
  UnmodifiableListView<int> get nextIds => UnmodifiableListView(_nextIds);
  DateTime get selectedDate => _selectedDate;

  /// Returns whether [event] should appear on [day] in the calendar.
  ///
  /// The check is inclusive of both start and end dates and compares only
  /// calendar days, ignoring timestamp precision.
  bool isEventOnDay(EventContent event, DateTime day) {
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
  List<EventContent> getEventsOnDay(DateTime day) {
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

    switch (result) {
      case Success<List<Event>>():
        _all = result.value
            .map((event) => EventContent.fromEvent(event))
            .toList();
      case Error<List<Event>>():
    }

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

    switch (result) {
      case Success<List<Event>>():
        _byDate = result.value
            .map((event) => EventContent.fromEvent(event))
            .toList();
      case Error<List<Event>>():
    }

    notifyListeners();

    return result;
  }

  Future<Result<void>> _loadNextIds() async {
    final result = await _eventRepository.getNextEventIds();

    switch (result) {
      case Success<List<int>>():
        _nextIds = result.value;
      case Error<List<int>>():
    }

    notifyListeners();

    loadNext.execute();

    return result;
  }

  Future<Result<void>> refreshData() async {
    final result = await _eventRepository.synchronize();

    return result;
  }

  Future<Result<void>> _loadNext() async {
    _next.clear();

    for (final id in _nextIds) {
      final result = await _eventRepository.getById(id);

      switch (result) {
        case Success<Event>():
          _next.add(EventContent.fromEvent(result.value));
        case Error<Event>():
      }
    }

    notifyListeners();

    return const Result.success(null);
  }
}
