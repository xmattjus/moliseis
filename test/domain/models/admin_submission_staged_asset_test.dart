import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/models/admin_submission_draft.dart';
import 'package:moliseis/domain/models/admin_submission_staged_asset.dart';

void main() {
  final owner = AdminDraftOwner(
    accountId: '10000000-0000-4000-8000-000000000001',
  );
  final digest = 'a' * 40;
  test('canonical descriptor equality includes exact owner', () {
    final path = '${owner.accountId}/${owner.sessionId}/$digest';
    final first = AdminSubmissionStagedAsset(
      owner: owner,
      digest: digest,
      relativePath: path,
    );
    final same = AdminSubmissionStagedAsset(
      owner: owner,
      digest: digest,
      relativePath: path,
    );
    expect(first, same);
    expect(first.hashCode, same.hashCode);
    expect(
      () => AdminSubmissionStagedAsset(
        owner: owner,
        digest: digest,
        relativePath: '../$digest',
      ),
      throwsArgumentError,
    );
    expect(
      () => AdminSubmissionStagedAsset(
        owner: owner,
        digest: 'A' * 40,
        relativePath: path,
      ),
      throwsArgumentError,
    );
  });
}
