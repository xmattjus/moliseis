import 'dart:async';

import 'package:command_it/command_it.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/utils/result_command.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../support/command_test_support.dart';
import '../../../../support/mock_gotrue_client.dart';
import '../../../../support/ordinary_view_model_lifecycle_support.dart';

void main() {
  for (final login in [true, false]) {
    for (final failure in ['StateError', 'AssertionError']) {
      testWidgets('E1 late $failure login=$login retains private execution', (
        tester,
      ) async {
        final probe = DisposalEventProbe();
        addTearDown(probe.dispose);
        final reports = <Object>[];
        final stacks = <StackTrace>[];
        final uncaught = <Object>[];
        final previous = Command.globalExceptionHandler;
        final reportAll = Command.reportAllExceptions;
        addTearDown(() {
          Command.globalExceptionHandler = previous;
          Command.reportAllExceptions = reportAll;
        });
        Command.reportAllExceptions = false;
        Command.globalExceptionHandler = (error, stack) {
          reports.add(error.error);
          stacks.add(stack);
        };
        late ControllableAdminAuth auth;
        late Completer<AuthResponse> password;
        late Completer<void> signOut;
        runZonedGuarded(() {
          password = Completer<AuthResponse>();
          signOut = Completer<void>();
          auth = ControllableAdminAuth(initialUser: makeAuthUser(isAdmin: true))
            ..onPassword = (() => password.future)
            ..onSignOut = (() => signOut.future);
          if (login) {
            auth.viewModel.requestLogin((
              email: 'a',
              password: 'sentinel-password',
            ));
          } else {
            auth.viewModel.requestLogout();
          }
        }, (error, stack) => uncaught.add(error));
        final notifiers = probe.creations
            .where(
              (event) =>
                  event.library ==
                  'package:functionlistener/functionlistener.dart',
            )
            .map((event) => event.object)
            .whereType<ValueListenable<dynamic>>()
            .where(
              (notifier) => notifier.value is CommandResult<dynamic, dynamic>,
            )
            .toList();
        expect(notifiers, hasLength(2));
        await pumpCommandTurns(tester);
        var notifications = 0;
        auth.viewModel.addListener(() => notifications++);
        final frozen = (
          auth.viewModel.loginSnapshot,
          auth.viewModel.logoutSnapshot,
        );
        auth.dispose();
        await pumpPhysicalCommandDisposal(tester);
        final error = failure == 'StateError'
            ? StateError('original')
            : AssertionError('original');
        final stack = StackTrace.fromString(
          '#0 authSdk (file:///original_auth.dart:1:1)',
        );
        if (login) {
          password.completeError(error, stack);
        } else {
          signOut.completeError(error, stack);
        }
        await pumpPhysicalCommandDisposal(tester);
        expect(notifications, 0);
        expect((
          auth.viewModel.loginSnapshot,
          auth.viewModel.logoutSnapshot,
        ), frozen);
        expect(auth.anonymousCalls, 0);
        if (failure == 'AssertionError') {
          expect(uncaught, [same(error)]);
          expect(reports, isEmpty);
        } else {
          expect(uncaught, isEmpty);
          expect(reports, [same(error)]);
          expect(stacks.single.toString(), contains('original_auth.dart'));
        }
        for (final notifier in notifiers) {
          expect(probe.count(notifier), 1);
        }
        expect(tester.takeException(), isNull);
      });
    }

    for (final terminal in [false, true]) {
      testWidgets('E3 dispose from ${terminal ? 'terminal' : 'running'} '
          'notification login=$login', (tester) async {
        final auth = ControllableAdminAuth();
        var revoked = false;
        auth.viewModel.addListener(() {
          final snapshot = login
              ? auth.viewModel.loginSnapshot
              : auth.viewModel.logoutSnapshot;
          if (!revoked &&
              (terminal ? snapshot.completed : snapshot.isRunning)) {
            revoked = true;
            auth.dispose();
          }
        });
        if (login) {
          auth.viewModel.requestLogin((email: 'a', password: 'secret'));
        } else {
          auth.viewModel.requestLogout();
        }
        await pumpPhysicalCommandDisposal(tester);
        expect(revoked, isTrue);
        expect(auth.viewModel.requestLogout(), isFalse);
        if (!terminal) {
          expect(auth.passwordCalls, 0);
          expect(auth.signOutCalls, 0);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('A7 SDK password never enters observable command channels', (
    tester,
  ) async {
    final auth = ControllableAdminAuth();
    final snapshots = <String>[];
    final previousLogging = Command.loggingHandler;
    final previousGlobal = Command.globalExceptionHandler;
    addTearDown(() {
      Command.loggingHandler = previousLogging;
      Command.globalExceptionHandler = previousGlobal;
    });
    Command.loggingHandler = (name, result) {
      snapshots.add('$name $result ${(result as dynamic).paramData}');
    };
    Command.globalExceptionHandler = (error, stack) {
      snapshots.add('$error');
    };
    auth.onPassword = () async => throw StateError('sdk failed');
    final owner = auth.viewModel;
    owner
      ..addListener(() {
        snapshots
          ..add('${owner.loginSnapshot}')
          ..add('${(owner.loginSnapshot as dynamic).paramData}');
      })
      ..requestLogin((email: 'a', password: 'PRIVATE-SENTINEL'));
    await pumpCommandTurns(tester);
    expect(auth.viewModel.loginSnapshot.unexpectedError, isA<StateError>());
    expect(snapshots.join(), isNot(contains('PRIVATE-SENTINEL')));
    expect(auth.logger.calls.toString(), isNot(contains('PRIVATE-SENTINEL')));
    auth.dispose();
    await pumpPhysicalCommandDisposal(tester);
  });
}
