import 'dart:async' show Completer;

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/models/admin_submission.dart';
import 'package:moliseis/domain/models/admin_submission_status.dart';
import 'package:moliseis/ui/admin/submissions/view_models/admin_submissions_view_model.dart';
import 'package:moliseis/utils/result.dart';

import '../../../../support/fake_repositories.dart';

void main() {
  group('AdminSubmissionsViewModel', () {
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
      'serializes a fresh post-editor reload after an active load',
      () async {
        final oldSubmission = sampleAdminSubmission(name: 'Old submission');
        final refreshedSubmission = sampleAdminSubmission(
          name: 'Refreshed submission',
        );
        final initialList = Completer<Result<List<AdminSubmission>>>();
        final refreshedList = Completer<Result<List<AdminSubmission>>>();
        final repository = FakeAdminContentSubmissionRepository()
          ..pendingList = initialList;
        final viewModel = AdminSubmissionsViewModel(repository: repository);
        addTearDown(viewModel.dispose);

        final loading = viewModel.load.execute();
        await pumpEventQueue();
        final refreshing = viewModel.reloadAfterEditor();
        final coalescedRefresh = viewModel.reloadAfterEditor();
        repository.pendingList = refreshedList;
        initialList.complete(Result.success(<AdminSubmission>[oldSubmission]));
        await pumpEventQueue();

        expect(repository.listCallCount, 2);
        expect(viewModel.items, isEmpty);

        refreshedList.complete(
          Result.success(<AdminSubmission>[refreshedSubmission]),
        );
        await Future.wait<void>(
          <Future<void>>[loading, refreshing, coalescedRefresh],
        );

        expect(viewModel.items, <AdminSubmission>[refreshedSubmission]);
      },
    );

    test(
      'starts a post-editor reload after command finalization begins',
      () async {
        final oldSubmission = sampleAdminSubmission(name: 'Old submission');
        final refreshedSubmission = sampleAdminSubmission(
          name: 'Refreshed submission',
        );
        final initialList = Completer<Result<List<AdminSubmission>>>();
        final refreshedList = Completer<Result<List<AdminSubmission>>>();
        final repository = FakeAdminContentSubmissionRepository()
          ..pendingList = initialList;
        final viewModel = AdminSubmissionsViewModel(repository: repository);
        addTearDown(viewModel.dispose);

        final loading = viewModel.load.execute();
        await pumpEventQueue();
        repository.pendingList = refreshedList;
        final editorRouteResult = Completer<void>.sync();
        var loadWasRunningWhenEditorReturned = false;
        late Future<void> refreshing;
        final editorReturn = editorRouteResult.future.then<void>((_) {
          loadWasRunningWhenEditorReturned = viewModel.load.running;
          refreshing = viewModel.reloadAfterEditor();
        });
        void completeEditorRouteAfterOlderLoad() {
          if (viewModel.items.length == 1 &&
              identical(viewModel.items.single, oldSubmission) &&
              !editorRouteResult.isCompleted) {
            // Complete the route result synchronously after `_load` has
            // handled the older repository response. Its continuation runs
            // before the command's pending finalization continuation.
            editorRouteResult.complete();
          }
        }

        viewModel.addListener(completeEditorRouteAfterOlderLoad);
        addTearDown(
          () => viewModel.removeListener(completeEditorRouteAfterOlderLoad),
        );
        initialList.complete(Result.success(<AdminSubmission>[oldSubmission]));
        await editorReturn;

        expect(loadWasRunningWhenEditorReturned, isTrue);
        expect(viewModel.items, <AdminSubmission>[oldSubmission]);
        await pumpEventQueue();

        expect(repository.listCallCount, 2);

        refreshedList.complete(
          Result.success(<AdminSubmission>[refreshedSubmission]),
        );
        await Future.wait<void>(<Future<void>>[loading, refreshing]);

        expect(viewModel.items, <AdminSubmission>[refreshedSubmission]);
      },
    );

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
