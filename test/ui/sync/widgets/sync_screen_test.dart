import 'dart:async' show Completer, unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/dtos/city_dto.dart';
import 'package:moliseis/domain/repositories/city_repository.dart';
import 'package:moliseis/domain/use-cases/sync_use_case.dart';
import 'package:moliseis/ui/core/ui/custom_circular_progress_indicator.dart';
import 'package:moliseis/ui/sync/view_models/sync_view_model.dart';
import 'package:moliseis/ui/sync/widgets/sync_screen.dart';
import 'package:moliseis/utils/result.dart';
import 'package:provider/provider.dart';

import '../../../support/fake_repositories.dart';

void main() {
  testWidgets('running sync renders the loading view', (tester) async {
    final gate = Completer<void>();
    final viewModel = _buildViewModel(
      cityRepository: _GatedCityRepository(gate: gate),
    );
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
      viewModel.dispose();
    });

    await tester.pumpWidget(_buildApp(viewModel));
    unawaited(viewModel.sync.execute(true));
    await tester.pump();

    expect(viewModel.sync.running, isTrue);
    expect(
      find.text('Aggiornamento dei contenuti in corso...'),
      findsOneWidget,
    );
    expect(find.byType(CustomCircularProgressIndicator), findsOneWidget);
  });

  testWidgets('idle sync does not render an infinite spinner', (tester) async {
    final viewModel = _buildViewModel(cityRepository: FakeCityRepository());
    addTearDown(viewModel.dispose);

    await tester.pumpWidget(_buildApp(viewModel));
    await tester.pumpAndSettle();

    expect(viewModel.sync.idle, isTrue);
    expect(find.byType(CustomCircularProgressIndicator), findsNothing);
    expect(find.text('Aggiornamento dei contenuti in corso...'), findsNothing);
  });
}

SyncViewModel _buildViewModel({required CityRepository cityRepository}) {
  return SyncViewModel(
    syncUseCase: SyncUseCase(
      cityRepository: cityRepository,
      eventRepository: FakeEventRepository(),
      mediaRepository: FakeMediaRepository(),
      placeRepository: FakePlaceRepository(),
      settingsRepository: FakeSettingsRepository(lastSyncedAt: DateTime.now()),
      transactionCoordinator: FakeTransactionCoordinator(),
    ),
  );
}

Widget _buildApp(SyncViewModel viewModel) {
  return ChangeNotifierProvider<SyncViewModel>.value(
    value: viewModel,
    child: const MaterialApp(home: SyncScreen()),
  );
}

final class _GatedCityRepository extends CityRepository {
  _GatedCityRepository({required this.gate});

  final Completer<void> gate;

  @override
  Future<Result<List<CityDto>>> prepareSync() async {
    await gate.future;
    return const Result.success(<CityDto>[]);
  }

  @override
  Result<void> commitSync(List<CityDto> dtos) => const Result.success(null);
}
