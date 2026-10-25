import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/ui/search/view_models/search_view_model.dart';
import 'package:moliseis/utils/result.dart';

import '../../../support/command_test_support.dart';
import '../../../support/fake_repositories.dart';

void main() {
  testOwnerUI(
    'independent bootstrap may publish confirmed history during accepted write',
    (tester) async {
      final read = Completer<Result<List<String>>>();
      final write = Completer<Result<void>>();
      final repository = FakeSearchRepository()
        ..pendingGetPastSearches = read
        ..pendingAddToPastSearches = write;
      final vm = SearchViewModel(searchRepository: repository)
        ..addToPastSearches('accepted');
      expect(vm.pastSearches, isEmpty);
      read.complete(const Result.success(['old']));
      await pumpCommandTurns(tester);
      final visible = vm.pastSearches.toList();
      vm.dispose();
      write.complete(const Result.success(null));
      await pumpCommandTurns(tester);
      expect(visible, ['old']);
    },
  );
}
