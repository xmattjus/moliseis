import 'dart:async';

import 'package:moliseis/ui/search/view_models/search_view_model.dart';
import 'package:moliseis/utils/result.dart';

import 'fake_repositories.dart';

/// Controlled repository boundary for FIFO, read authority and store outcomes.
class SearchHistoryHarness {
  SearchHistoryHarness({
    List<String> initial = const [],
    bool holdReads = false,
  }) : stored = List.of(initial) {
    repository.historyReadHandler = () {
      final gate = Completer<Result<List<String>>>();
      reads.add(gate);
      if (!holdReads) gate.complete(Result.success(List.of(stored)));
      return gate.future;
    };
    repository.historyAddHandler = (query) => _write(query, remove: false);
    repository.historyRemoveHandler = (query) => _write(query, remove: true);
    vm = SearchViewModel(searchRepository: repository);
    vm.addListener(() => notifications++);
  }

  final repository = FakeSearchRepository();
  final List<String> stored;
  final List<Completer<Result<List<String>>>> reads = [];
  final List<Completer<Result<void>>> writes = [];
  late final SearchViewModel vm;
  int notifications = 0;

  Future<Result<void>> _write(String query, {required bool remove}) async {
    final gate = Completer<Result<void>>();
    writes.add(gate);
    final result = await gate.future;
    result.map((_) => applyStored(query, remove: remove));
    return result;
  }

  /// Simulates an already-completed commit independently from Future delivery.
  void applyStored(String query, {bool remove = false}) {
    if (remove) {
      stored.remove(query);
    } else if (!stored.any(
      (item) => item.toLowerCase() == query.toLowerCase(),
    )) {
      stored.add(query);
    }
  }
}
