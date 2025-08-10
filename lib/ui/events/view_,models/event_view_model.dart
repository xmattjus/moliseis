import 'dart:collection' show UnmodifiableListView;

import 'package:flutter/material.dart';
import 'package:moliseis/data/repositories/event/event_repository.dart';
import 'package:moliseis/domain/models/event/event.dart';
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/result.dart';

class EventViewModel extends ChangeNotifier {
  EventViewModel({required EventRepository repository})
    : _eventRepository = repository {
    load = Command0(_load)..execute();
  }

  final EventRepository _eventRepository;

  var _events = <Event>[];

  late Command0<void> load;

  UnmodifiableListView<Event> get events => UnmodifiableListView(_events);

  Future<Result<void>> _load() async {
    final results = await _eventRepository.getAll();

    switch (results) {
      case Success<List<Event>>():
        _events = results.value;
      case Error<List<Event>>():
    }

    notifyListeners();

    return results;
  }

  Future<Result<void>> refreshData() async {
    final result = await _eventRepository.synchronize();

    return result;
  }
}
