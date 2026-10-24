import 'dart:async';

import 'package:command_it/command_it.dart';
import 'package:flutter/foundation.dart';
import 'package:moliseis/domain/models/admin_external_event.dart';
import 'package:moliseis/domain/models/admin_submission.dart';
import 'package:moliseis/ui/admin/submissions/view_models/admin_submissions_view_model.dart';
import 'package:moliseis/utils/result.dart';

import 'fake_repositories.dart';
import 'ordinary_view_model_lifecycle_support.dart';

/// The three private dashboard commands, observed through their owner façade.
enum AdminDashboardLane { submissions, ignored, mutation }

/// Keeps physical work distinct from the accepted public refresh Future.
final class AdminDashboardCommandHarness {
  AdminDashboardCommandHarness(this.lane, {required DisposalEventProbe probe}) {
    repository = FakeAdminContentSubmissionRepository();
    switch (lane) {
      case AdminDashboardLane.submissions:
        repository.pendingList = submissions;
      case AdminDashboardLane.ignored:
        repository.pendingIgnoredList = ignored;
      case AdminDashboardLane.mutation:
        repository.pendingUnIgnore = mutation;
    }
    final start = probe.creations.length;
    owner = AdminSubmissionsViewModel(repository: repository);
    owner.addListener(() => notifications++);
    resultNotifiers = probe.creations
        .skip(start)
        .where(
          (event) =>
              event.library == 'package:functionlistener/functionlistener.dart',
        )
        .map((event) => event.object)
        .whereType<ValueListenable<dynamic>>()
        .where((notifier) => notifier.value is CommandResult<dynamic, dynamic>)
        .toList();
  }

  final AdminDashboardLane lane;
  final submissions = Completer<Result<List<AdminSubmission>>>();
  final ignored = Completer<Result<List<AdminIgnoredSource>>>();
  final mutation = Completer<Result<AdminEventResolution>>();
  late final FakeAdminContentSubmissionRepository repository;
  late final AdminSubmissionsViewModel owner;
  late final List<ValueListenable<dynamic>> resultNotifiers;
  Future<void>? original;
  int completions = 0;
  int notifications = 0;

  void request() {
    original = switch (lane) {
      AdminDashboardLane.submissions => owner.refreshSubmissions(),
      AdminDashboardLane.ignored => owner.refreshIgnoredSources(),
      AdminDashboardLane.mutation => null,
    };
    if (lane == AdminDashboardLane.mutation) owner.requestUnIgnore(12);
    if (original case final future?) {
      unawaited(future.then((_) => completions++));
    }
  }

  void succeed() {
    switch (lane) {
      case AdminDashboardLane.submissions:
        submissions.complete(Result.success([sampleAdminSubmission(id: 8)]));
      case AdminDashboardLane.ignored:
        ignored.complete(
          const Result.success([
            AdminIgnoredSource(
              id: 12,
              provider: 'eventimolise',
              externalId: 'a',
              name: 'Ignored',
              ignoredAt: '2026-10-02T10:00:00Z',
            ),
          ]),
        );
      case AdminDashboardLane.mutation:
        mutation.complete(
          const Result.success(
            AdminEventResolution(outcome: 'unignored', pendingId: 8),
          ),
        );
    }
  }

  void failDomain() {
    final error = TestException('expected dashboard failure');
    switch (lane) {
      case AdminDashboardLane.submissions:
        submissions.complete(Result.error(error));
      case AdminDashboardLane.ignored:
        ignored.complete(Result.error(error));
      case AdminDashboardLane.mutation:
        mutation.complete(Result.error(error));
    }
  }

  void failRuntime(Object error, StackTrace stack) {
    switch (lane) {
      case AdminDashboardLane.submissions:
        submissions.completeError(error, stack);
      case AdminDashboardLane.ignored:
        ignored.completeError(error, stack);
      case AdminDashboardLane.mutation:
        mutation.completeError(error, stack);
    }
  }

  int get calls => switch (lane) {
    AdminDashboardLane.submissions => repository.listCallCount,
    AdminDashboardLane.ignored => repository.ignoredListCalls,
    AdminDashboardLane.mutation => repository.unIgnoreCalls.length,
  };

  CommandResult<dynamic, Result<dynamic>?> get snapshot => switch (lane) {
    AdminDashboardLane.submissions => owner.loadSnapshot,
    AdminDashboardLane.ignored => owner.loadIgnoredSnapshot,
    AdminDashboardLane.mutation => owner.unIgnoreSnapshot,
  };

  List<Object?> state() => [
    owner.items.toList(),
    owner.ignoredSources.toList(),
    owner.loadSnapshot,
    owner.loadIgnoredSnapshot,
    owner.unIgnoreSnapshot,
    owner.unignoredPendingId,
  ];
}
