import 'dart:async';

import 'package:command_it/command_it.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/models/admin_external_event.dart';
import 'package:moliseis/domain/models/admin_submission.dart';
import 'package:moliseis/ui/admin/submissions/view_models/admin_submissions_view_model.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../support/admin_dashboard_command_harness.dart';
import '../../../../support/command_test_support.dart';
import '../../../../support/fake_repositories.dart';
import '../../../../support/mock_gotrue_client.dart';
import '../../../../support/ordinary_view_model_lifecycle_support.dart';

void main() {
  for (final lane in AdminDashboardLane.values) {
    for (final duringNotification in [false, true]) {
      testOwnerUI('D2 ${lane.name} revocation prevents reserved dispatch '
          'during notification=$duringNotification', (tester) async {
        final probe = DisposalEventProbe();
        addTearDown(probe.dispose);
        final auth = ControllableAdminAuth(
          initialUser: makeAuthUser(id: 'admin-a', isAdmin: true),
        );
        final h = AdminDashboardCommandHarness(
          lane,
          probe: probe,
          auth: auth.viewModel,
        );
        addTearDown(auth.dispose);
        if (duringNotification) {
          h.owner.addListener(() {
            auth
              ..setUser(null)
              ..emit(AuthChangeEvent.signedOut);
          });
        }
        h.request();
        expect(h.calls, 0);
        if (!duringNotification) {
          auth
            ..setUser(null)
            ..emit(AuthChangeEvent.signedOut);
        }
        await tester.idle();
        expect(h.owner.isDisposed, isTrue);
        expect(h.owner.loadSnapshot.idle, isTrue);
        expect(h.owner.loadIgnoredSnapshot.idle, isTrue);
        expect(h.owner.unIgnoreSnapshot.idle, isTrue);
        await pumpCommandTurns(tester);
        expect(h.calls, 0);
        if (h.original case final original?) await original;
        expect(h.owner.requestUnIgnore(99), isFalse);
        h.owner.dispose();
        await pumpPhysicalCommandDisposal(tester);
      });
    }

    for (final outcome in ['success', 'domain', 'runtime']) {
      testOwnerUI('D3 ${lane.name} late $outcome settles privately after '
          'replacement and returning A', (tester) async {
        final probe = DisposalEventProbe();
        addTearDown(probe.dispose);
        final auth = ControllableAdminAuth(
          initialUser: makeAuthUser(id: 'admin-a', isAdmin: true),
        );
        final reports = <Object>[];
        final previous = Command.globalExceptionHandler;
        final previousAll = Command.reportAllExceptions;
        Command.reportAllExceptions = false;
        Command.globalExceptionHandler = (failure, _) =>
            reports.add(failure.error);
        addTearDown(() {
          Command.globalExceptionHandler = previous;
          Command.reportAllExceptions = previousAll;
          auth.dispose();
        });
        final originalAuthority = auth.viewModel.authority;
        final h = AdminDashboardCommandHarness(
          lane,
          probe: probe,
          auth: auth.viewModel,
        )..request();
        await pumpCommandTurns(tester);
        expect(h.calls, 1);
        auth
          ..setUser(makeAuthUser(id: 'admin-b', isAdmin: true))
          ..emit(AuthChangeEvent.signedIn);
        await tester.idle();
        expect(h.owner.items, isEmpty);
        expect(h.owner.ignoredSources, isEmpty);
        expect(h.owner.unignoredPendingId, isNull);
        expect(h.owner.unIgnoreSnapshot.idle, isTrue);
        final notifications = h.notifications;
        auth
          ..setUser(makeAuthUser(id: 'admin-a', isAdmin: true))
          ..emit(AuthChangeEvent.signedIn);
        await tester.idle();
        expect(auth.viewModel.authority, isNot(same(originalAuthority)));
        expect(h.owner.canRefreshSelectedLane, isFalse);
        // Retirement releases idle lanes at their deferred boundary; only the
        // physically pending lane stays allocated until it settles.
        await pumpPhysicalCommandDisposal(tester);
        expect(h.resultNotifiers.map(probe.count).toList()..sort(), [
          0,
          for (var i = 1; i < h.resultNotifiers.length; i++) 1,
        ]);
        final failure = StateError('late synthetic failure');
        switch (outcome) {
          case 'success':
            h.succeed();
          case 'domain':
            h.failDomain();
          case 'runtime':
            h.failRuntime(failure, StackTrace.current);
        }
        await pumpCommandTurns(tester);
        if (h.original case final original?) await original;
        expect(h.notifications, notifications);
        expect(h.calls, 1);
        expect(h.repository.dashboardCalls, hasLength(1));
        expect(h.owner.loadSnapshot.idle, isTrue);
        expect(h.owner.loadIgnoredSnapshot.idle, isTrue);
        expect(h.owner.unIgnoreSnapshot.idle, isTrue);
        expect(h.owner.items, isEmpty);
        expect(h.owner.ignoredSources, isEmpty);
        expect(reports, outcome == 'runtime' ? [failure] : isEmpty);
        final fresh = AdminSubmissionsViewModel(
          repository: h.repository,
          auth: auth.viewModel,
        );
        expect(fresh.canRefreshSelectedLane, isTrue);
        expect(fresh.items, isEmpty);
        fresh.dispose();
        // Late settlement released the pending lane before explicit disposal.
        await pumpPhysicalCommandDisposal(tester);
        for (final notifier in h.resultNotifiers) {
          expect(probe.count(notifier), 1);
        }
        h.owner.dispose();
        await pumpPhysicalCommandDisposal(tester);
        // Explicit disposal does not release any lane a second time.
        for (final notifier in h.resultNotifiers) {
          expect(probe.count(notifier), 1);
        }
      });
    }
  }

  testOwnerUI('A1 continuous refresh preserves Dashboard owner and '
      'admitted read', (tester) async {
    final auth = ControllableAdminAuth(
      initialUser: makeAuthUser(id: 'admin-a', isAdmin: true),
    );
    addTearDown(auth.dispose);
    final pending = Completer<Result<List<AdminSubmission>>>();
    final repository = FakeAdminContentSubmissionRepository()
      ..pendingList = pending;
    final owner = AdminSubmissionsViewModel(
      repository: repository,
      auth: auth.viewModel,
    );
    final authority = auth.viewModel.authority;
    final read = owner.refreshSubmissions();
    await pumpCommandTurns(tester);
    auth
      ..setUser(makeAuthUser(id: 'admin-a', isAdmin: true, name: 'New profile'))
      ..emit(AuthChangeEvent.tokenRefreshed)
      ..emit(AuthChangeEvent.userUpdated);
    await tester.idle();
    expect(auth.viewModel.authority, same(authority));
    expect(owner.isDisposed, isFalse);
    expect(owner.loading, isTrue);
    expect(repository.listCallCount, 1);
    pending.complete(Result.success([sampleAdminSubmission(id: 73)]));
    await pumpCommandTurns(tester);
    await read;
    expect(owner.items.single.id, 73);
    expect(owner.canRefreshSelectedLane, isTrue);
    owner.dispose();
    await pumpPhysicalCommandDisposal(tester);
  });

  testOwnerUI('D3 revocation during ignored post-commit read prevents '
      'subsequent submissions refresh', (tester) async {
    final auth = ControllableAdminAuth(
      initialUser: makeAuthUser(id: 'admin-a', isAdmin: true),
    );
    addTearDown(auth.dispose);
    final ignored = Completer<Result<List<AdminIgnoredSource>>>();
    final repository = FakeAdminContentSubmissionRepository()
      ..unIgnoreResult = const Result.success(
        AdminEventResolution(outcome: 'unignored', pendingId: 123),
      )
      ..pendingIgnoredList = ignored;
    final owner = AdminSubmissionsViewModel(
      repository: repository,
      auth: auth.viewModel,
    );
    expect(owner.requestUnIgnore(12), isTrue);
    await pumpCommandTurns(tester);
    expect(repository.dashboardCalls, [
      'unIgnoreSource:12',
      'listIgnoredSources',
    ]);
    auth
      ..setUser(null)
      ..emit(AuthChangeEvent.signedOut);
    await tester.idle();
    ignored.complete(const Result.success([]));
    await pumpCommandTurns(tester);
    expect(repository.listCallCount, 0);
    expect(owner.unignoredPendingId, isNull);
    expect(owner.unIgnoreSnapshot.idle, isTrue);
    owner.dispose();
    await pumpPhysicalCommandDisposal(tester);
  });
}
