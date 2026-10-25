import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/use-cases/favourite_get_ids_use_case.dart';
import 'package:moliseis/ui/core/ui/skeletons/skeleton_content_sliver_grid.dart';
import 'package:moliseis/ui/favourite/view_models/favourite_view_model.dart';
import 'package:moliseis/ui/favourite/widgets/favourite_screen.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';

import '../../../support/command_test_support.dart';
import '../../../support/fake_repositories.dart';
import '../../../support/favourite_button_harness.dart';

void main() {
  testOwnerUI('load failure offers retry and forwards '
      'its pending and empty success states', (tester) async {
    var pending = Completer<Result<List<int>>>();
    final places = FakePlaceRepository(
      getFavouritePlaceIdsHandler: () => pending.future,
    );
    final vm = FavouriteViewModel(
      favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
        eventRepository: FakeEventRepository(),
        placeRepository: places,
      ),
    );
    addTearDown(vm.dispose);
    await tester.pumpWidget(
      favouriteButtonHarness(
        viewModel: vm,
        ownsViewModel: true,
        child: FavouriteScreen(viewModel: vm),
      ),
    );
    await pumpCommandTurns(tester);
    expect(find.byType(SkeletonContentSliverGrid), findsOneWidget);
    final failure = TestException('load failed');
    pending.complete(Result.error(failure));
    await pumpCommandTurns(tester);
    await tester.pumpAndSettle();
    expect(vm.load.results.value.domainError, same(failure));
    expect(
      find.text('Si è verificato un errore durante il caricamento.'),
      findsOneWidget,
    );
    expect(find.text('Riprova'), findsOneWidget);
    pending = Completer<Result<List<int>>>();
    await tester.tap(find.text('Riprova'));
    await tester.pump();
    expect(vm.load.results.value.isRunning, isTrue);
    expect(find.byType(SkeletonContentSliverGrid), findsOneWidget);
    expect(find.text('Riprova'), findsNothing);
    pending.complete(const Result.success([]));
    await pumpCommandTurns(tester);
    await tester.pumpAndSettle();
    expect(vm.load.results.value.completed, isTrue);
    expect(find.byType(SkeletonContentSliverGrid), findsNothing);
    expect(
      find.text('Non hai ancora aggiunto nulla ai preferiti.'),
      findsOneWidget,
    );
  });
}
