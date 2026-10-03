import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/models/admin_external_event.dart';
import 'package:moliseis/domain/models/admin_submission.dart';
import 'package:moliseis/domain/models/admin_submission_status.dart';
import 'package:moliseis/ui/admin/submissions/view_models/admin_submissions_view_model.dart';
import 'package:moliseis/utils/result.dart';

import '../../../../support/fake_repositories.dart';

void main() {
  group('AdminSubmissionsViewModel', () {
    test('ignored record without pending is reachable and un-ignore refreshes '
        'both lists', () async {
      const source = AdminIgnoredSource(
        id: 12,
        provider: 'eventimolise',
        externalId: 'a',
        name: 'Ignored',
        ignoredAt: '2026-10-02T10:00:00Z',
      );
      final repository = FakeAdminContentSubmissionRepository()
        ..ignoredSourcesResult = const Result.success([source])
        ..unIgnoreResult = const Result.success(
          AdminEventResolution(outcome: 'unignored', pendingId: 8),
        );
      final vm = AdminSubmissionsViewModel(repository: repository);
      addTearDown(vm.dispose);
      await vm.load.execute();
      vm.setIgnoredFilter();
      await vm.loadIgnored.execute();
      expect(vm.items, isEmpty);
      expect(vm.ignoredSources.single.id, 12);
      repository
        ..ignoredSourcesResult = const Result.success([])
        ..listResult = Result.success([sampleAdminSubmission(id: 8)]);
      await vm.unIgnore.execute(12);
      expect(vm.unIgnore.completed, isTrue);
      expect(vm.ignoredSources, isEmpty);
      expect(vm.items.single.id, 8);
      expect(vm.unignoredPendingId, 8);
      expect(repository.unIgnoreCalls, [12]);
      expect(repository.ignoredListCalls, 2);
      expect(repository.listCallCount, 2);
    });

    test('refresh during un-ignore cannot read pre-commit source or pending '
        'state and success starts fresh reads', () async {
      const source = AdminIgnoredSource(
        id: 12,
        provider: 'eventimolise',
        externalId: 'a',
        name: 'Ignored',
        ignoredAt: '2026-10-02T10:00:00Z',
      );
      final pending = Completer<Result<AdminEventResolution>>();
      final repository = FakeAdminContentSubmissionRepository()
        ..ignoredSourcesResult = const Result.success([source])
        ..pendingUnIgnore = pending;
      final vm = AdminSubmissionsViewModel(repository: repository);
      addTearDown(vm.dispose);
      await vm.loadIgnored.execute();
      await vm.load.execute();
      final resolution = vm.unIgnore.execute(12);
      final ignoredRefresh = vm.loadIgnored.execute();
      final pendingRefresh = vm.load.execute();
      // Complete immediately: the blocked commands may still be running.
      repository
        ..ignoredSourcesResult = const Result.success([])
        ..listResult = Result.success([sampleAdminSubmission(id: 8)]);
      pending.complete(
        const Result.success(
          AdminEventResolution(outcome: 'unignored', pendingId: 8),
        ),
      );
      await ignoredRefresh;
      await pendingRefresh;
      await resolution;
      expect(vm.ignoredSources, isEmpty);
      expect(vm.items.single.id, 8);
      expect(vm.unIgnore.completed, isTrue);
      expect(vm.loadIgnored.completed, isTrue);
      expect(vm.load.completed, isTrue);
      expect(repository.ignoredListCalls, 2);
      expect(repository.listCallCount, 2);
    });

    test('failed un-ignore preserves ignored and pending list state', () async {
      const source = AdminIgnoredSource(
        id: 12,
        provider: 'eventimolise',
        externalId: 'a',
        name: 'Ignored',
        ignoredAt: '2026-10-02T10:00:00Z',
      );
      final repository =
          FakeAdminContentSubmissionRepository(
              listResult: Result.success([sampleAdminSubmission()]),
            )
            ..ignoredSourcesResult = const Result.success([source])
            ..unIgnoreResult = Result.error(TestException('Failure'));
      final vm = AdminSubmissionsViewModel(repository: repository);
      addTearDown(vm.dispose);
      await vm.load.execute();
      await vm.loadIgnored.execute();
      await vm.unIgnore.execute(12);
      expect(vm.unIgnore.error, isTrue);
      expect(vm.ignoredSources, [source]);
      expect(vm.items.single.id, 1);
      expect(repository.ignoredListCalls, 1);
      expect(repository.listCallCount, 1);
      expect(vm.unignoredPendingId, isNull);
    });

    test('stores loaded submission summaries', () async {
      final submission = sampleAdminSubmission();
      final repository = FakeAdminContentSubmissionRepository(
        listResult: Result.success(<AdminSubmission>[submission]),
      );
      final viewModel = AdminSubmissionsViewModel(repository: repository);
      addTearDown(viewModel.dispose);

      await viewModel.load.execute();

      expect(viewModel.load.completed, isTrue);
      expect(viewModel.items, <AdminSubmission>[submission]);
      expect(viewModel.filteredItems, <AdminSubmission>[submission]);
    });

    test(
      'exposes an error without retaining items when loading fails',
      () async {
        final repository = FakeAdminContentSubmissionRepository(
          listResult: Result.error(TestException('list failed')),
        );
        final viewModel = AdminSubmissionsViewModel(repository: repository);
        addTearDown(viewModel.dispose);

        await viewModel.load.execute();

        expect(viewModel.error, isTrue);
        expect(viewModel.items, isEmpty);
        expect(viewModel.hasData, isFalse);
      },
    );

    test('recovers when retrying after a loading error', () async {
      final submission = sampleAdminSubmission();
      final repository = FakeAdminContentSubmissionRepository(
        listResult: Result.error(TestException('list failed')),
      );
      final viewModel = AdminSubmissionsViewModel(repository: repository);
      addTearDown(viewModel.dispose);

      await viewModel.load.execute();
      repository.listResult = Result.success(<AdminSubmission>[submission]);
      await viewModel.load.execute();

      expect(viewModel.error, isFalse);
      expect(viewModel.items, <AdminSubmission>[submission]);
      expect(repository.listCallCount, 2);
    });

    test(
      'filters loaded summaries by status and restores all summaries',
      () async {
        final pending = sampleAdminSubmission();
        final accepted = sampleAdminSubmission(
          id: 2,
          status: AdminSubmissionStatus.accepted,
        );
        final repository = FakeAdminContentSubmissionRepository(
          listResult: Result.success(<AdminSubmission>[pending, accepted]),
        );
        final viewModel = AdminSubmissionsViewModel(repository: repository);
        addTearDown(viewModel.dispose);

        await viewModel.load.execute();
        viewModel.setFilter(AdminSubmissionStatus.accepted);

        expect(viewModel.filteredItems, <AdminSubmission>[accepted]);

        viewModel.setFilter(null);

        expect(viewModel.filteredItems, <AdminSubmission>[pending, accepted]);
      },
    );
  });
}
