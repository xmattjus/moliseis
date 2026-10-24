import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/config/dependencies.dart';
import 'package:moliseis/ui/core/ui/custom_circular_progress_indicator.dart';
import 'package:moliseis/ui/sync/view_models/sync_view_model.dart';
import 'package:moliseis/ui/sync/widgets/sync_screen.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';
import 'package:provider/provider.dart';

import '../../../support/command_test_support.dart';
import '../../../support/fake_repositories.dart';
import '../../../support/mock_logger.dart';
import '../../../support/sync_harness.dart';

void main() {
  const feedback =
      "Si è verificato un errore durante l'aggiornamento dei contenuti";

  testWidgets('running sync renders the loading view', (tester) async {
    final harness = SyncHarness();
    await tester.pumpWidget(buildLocalSyncScreen(harness.viewModel));
    harness.viewModel.sync.run(true);
    expect(harness.viewModel.sync.isRunningSync.value, isTrue);
    await pumpCommandTurns(tester);
    expect(
      find.text('Aggiornamento dei contenuti in corso...'),
      findsOneWidget,
    );
    expect(find.byType(CustomCircularProgressIndicator), findsOneWidget);
    await disposeSyncHarnesses(tester, [harness]);
  });

  testWidgets('idle sync does not render an infinite spinner', (tester) async {
    final harness = SyncHarness();
    await tester.pumpWidget(buildLocalSyncScreen(harness.viewModel));
    expect(harness.viewModel.sync.results.value.idle, isTrue);
    expect(find.byType(CustomCircularProgressIndicator), findsNothing);
    await disposeSyncHarnesses(tester, [harness]);
  });

  testWidgets(
    'F2 same Exception in two accepted attempts delivers twice only',
    (tester) async {
      final failure = TestException('same instance');
      final harness = SyncHarness(
        gated: false,
        cityResult: Result.error(failure),
      );
      await tester.pumpWidget(buildLocalSyncScreen(harness.viewModel));
      for (var attempt = 0; attempt < 2; attempt++) {
        harness.viewModel.sync.run(true);
        await pumpCommandTurns(tester);
        expect(harness.viewModel.sync.results.value.domainError, same(failure));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text(feedback), findsOneWidget);
        await tester.pumpWidget(buildLocalSyncScreen(harness.viewModel));
        await pumpCommandTurns(tester);
        $scaffoldMessengerKey.currentState!.removeCurrentSnackBar();
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          find.text(feedback),
          findsNothing,
          reason: 'same owner rebuild must not queue duplicate feedback',
        );
      }
      expect(harness.prepareCalls, 2);
      await disposeSyncHarnesses(tester, [harness]);
    },
  );

  testWidgets(
    'F3/F6 local rebind retains State and ignores old owner terminal',
    (tester) async {
      final a = SyncHarness(
        cityResult: Result.error(TestException('obsolete A')),
      );
      final b = SyncHarness();
      await tester.pumpWidget(buildLocalSyncScreen(a.viewModel));
      final state = tester.state(find.byType(SyncScreen));
      a.viewModel.sync.run(true);
      await pumpCommandTurns(tester);
      await tester.pumpWidget(buildLocalSyncScreen(b.viewModel));
      expect(tester.state(find.byType(SyncScreen)), same(state));
      expect(b.prepareCalls, 0);
      a.release();
      await pumpCommandTurns(tester);
      expect(find.text(feedback), findsNothing);
      expect(find.byType(CustomCircularProgressIndicator), findsNothing);
      b.viewModel.sync.run(true);
      await pumpCommandTurns(tester);
      expect(find.byType(CustomCircularProgressIndicator), findsOneWidget);
      await disposeSyncHarnesses(tester, [a, b]);
    },
  );

  testWidgets('F3 already-terminal B reconciles without starting a new sync', (
    tester,
  ) async {
    final a = SyncHarness();
    final b = SyncHarness(
      gated: false,
      cityResult: Result.error(TestException('B')),
    );
    b.viewModel.sync.run(true);
    await pumpCommandTurns(tester);
    await tester.pumpWidget(buildLocalSyncScreen(a.viewModel));
    final state = tester.state(find.byType(SyncScreen));
    await tester.pumpWidget(buildLocalSyncScreen(b.viewModel));
    await pumpCommandTurns(tester);
    expect(tester.state(find.byType(SyncScreen)), same(state));
    expect(b.prepareCalls, 1);
    expect(find.text(feedback), findsOneWidget);
    await tester.pumpWidget(buildLocalSyncScreen(b.viewModel));
    $scaffoldMessengerKey.currentState!.removeCurrentSnackBar();
    await pumpCommandTurns(tester);
    expect(find.text(feedback), findsNothing);
    await disposeSyncHarnesses(tester, [a, b]);
  });

  testWidgets('F2 retry before pending reconciliation revokes old feedback', (
    tester,
  ) async {
    final harness = SyncHarness(
      gated: false,
      cityResult: Result.error(TestException('A')),
    );
    harness.viewModel.sync.run(true);
    await pumpCommandTurns(tester);
    // This callback is ahead of the reconciliation queued on initial binding.
    // A genuine accepted retry publishes loading and revokes that observation.
    tester.binding.addPostFrameCallback(
      (_) => harness.viewModel.sync.run(true),
    );
    await tester.pumpWidget(buildLocalSyncScreen(harness.viewModel));
    expect(harness.viewModel.sync.isRunningSync.value, isTrue);
    expect(find.text(feedback), findsNothing);
    await pumpCommandTurns(tester);
    expect(
      find.text(feedback),
      findsOneWidget,
      reason: 'the new accepted failure can deliver its own feedback',
    );
    await disposeSyncHarnesses(tester, [harness]);
  });

  testWidgets(
    'F2 fatal runtime shows retry and reports original once without snackbar',
    (tester) async {
      final failure = StateError('programming fault');
      final logger = MockLogger();
      final restore = installCommandTestReporting(logger);
      addTearDown(restore);
      final harness = SyncHarness(
        autoSync: true,
        onCommit: () => throw failure,
      );
      await tester.pumpWidget(buildLocalSyncScreen(harness.viewModel));
      await pumpCommandTurns(tester);
      harness.release();
      await pumpCommandTurns(tester);
      expect(
        harness.viewModel.sync.results.value.unexpectedError,
        same(failure),
      );
      expect(harness.viewModel.sync.results.value.domainError, isNull);
      expect(find.text('Riprova'), findsOneWidget);
      expect(
        find.text('Impossibile aggiornare i contenuti. Riprova più tardi.'),
        findsOneWidget,
      );
      expect(find.text(feedback), findsNothing);
      expect(logger.calls, hasLength(1));
      expect(logger.calls.single.error, same(failure));
      await disposeSyncHarnesses(tester, [harness]);
    },
  );

  testWidgets('F3 final detach prevents effects from late completion', (
    tester,
  ) async {
    final harness = SyncHarness(
      cityResult: Result.error(TestException('late')),
    );
    await tester.pumpWidget(buildLocalSyncScreen(harness.viewModel));
    harness.viewModel.sync.run(true);
    await pumpCommandTurns(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    harness.release();
    await pumpCommandTurns(tester);
    expect(tester.takeException(), isNull);
    expect($scaffoldMessengerKey.currentState, isNull);
    await disposeSyncHarnesses(tester, [harness]);
  });
  testWidgets('F3 Provider B replacement revokes pending A reconciliation', (
    tester,
  ) async {
    final a = SyncHarness(
      gated: false,
      cityResult: Result.error(TestException('A')),
    );
    final b = SyncHarness();
    a.viewModel.sync.run(true);
    await pumpCommandTurns(tester);
    State? preservedState;
    // Replace the real Provider before A's queued feedback callback.
    // buildScope also flushes dependency rebuilds; this tests replacement
    // before authorization, not the narrower Provider-before-rebind window.
    tester.binding.addPostFrameCallback((_) {
      preservedState = tester.state(find.byType(SyncScreen));
      final provider = tester.element(
        find.byType(ChangeNotifierProvider<SyncViewModel>),
      );
      provider.owner!.buildScope(provider, () {
        provider.update(buildLocalSyncScreen(b.viewModel));
      });
    });
    await tester.pumpWidget(buildLocalSyncScreen(a.viewModel));
    expect(find.text(feedback), findsNothing);
    await tester.pumpWidget(buildLocalSyncScreen(b.viewModel));
    await pumpCommandTurns(tester);
    expect(tester.state(find.byType(SyncScreen)), same(preservedState));
    expect(b.prepareCalls, 0);
    expect(b.viewModel.sync.results.value.idle, isTrue);
    expect(find.text(feedback), findsNothing);
    await disposeSyncHarnesses(tester, [a, b]);
  });

  testWidgets('F2 foreign navigation revokes pending reconciliation', (
    tester,
  ) async {
    final harness = SyncHarness(
      gated: false,
      cityResult: Result.error(TestException('old route')),
    );
    harness.viewModel.sync.run(true);
    await pumpCommandTurns(tester);
    tester.binding.addPostFrameCallback((_) {
      final context = tester.element(find.byType(SyncScreen));
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Other route')),
        ),
      );
    });
    await tester.pumpWidget(buildLocalSyncScreen(harness.viewModel));
    await pumpCommandTurns(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Other route'), findsOneWidget);
    expect(find.text(feedback), findsNothing);
    expect(tester.takeException(), isNull);
    await disposeSyncHarnesses(tester, [harness]);
  });
}
