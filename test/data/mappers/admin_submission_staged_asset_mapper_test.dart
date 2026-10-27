import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/data-sources/admin_submission_staged_asset_entity.dart';
import 'package:moliseis/data/mappers/admin_submission_staged_asset_mapper.dart';
import 'package:moliseis/domain/models/admin_submission_draft.dart';
import 'package:moliseis/domain/models/admin_submission_staged_asset.dart';

void main() {
  final owner = AdminDraftOwner(
    accountId: '10000000-0000-4000-8000-000000000001',
    submissionId: 7,
  );
  final digest = 'a' * 40;
  test('valid descriptor round-trips exact owner and path', () {
    final asset = AdminSubmissionStagedAsset(
      owner: owner,
      digest: digest,
      relativePath: '${owner.accountId}/${owner.sessionId}/$digest',
    );
    expect(asset.toEntity().toModel(), asset);
  });
  test('invalid ownership and escaping paths are quarantined', () {
    for (final path in [
      '/outside/$digest',
      '../$digest',
      '${owner.accountId}/another/$digest',
    ]) {
      expect(
        AdminSubmissionStagedAssetEntity(
          accountId: owner.accountId,
          sessionId: owner.sessionId,
          submissionId: 7,
          digest: digest,
          relativePath: path,
        ).toModel(),
        isNull,
      );
    }
    expect(
      AdminSubmissionStagedAssetEntity(
        accountId: 'invalid',
        sessionId: owner.sessionId,
        submissionId: 7,
        digest: digest,
        relativePath: digest,
      ).toModel(),
      isNull,
    );
  });
}
