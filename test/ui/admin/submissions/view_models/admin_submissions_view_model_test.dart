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
