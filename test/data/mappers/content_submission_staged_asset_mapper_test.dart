import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/data-sources/content_submission_staged_asset_entity.dart';
import 'package:moliseis/data/mappers/content_submission_staged_asset_mapper.dart';
import 'package:moliseis/domain/models/content_submission_staged_asset.dart';

void main() {
  const clientSubmissionId = '2a1b0c3d-4e5f-4a6b-8c9d-0e1f2a3b4c5d';
  const digest = '0123456789abcdef0123456789abcdef01234567';

  group('ContentSubmissionStagedAsset mapper', () {
    test('round-trips the validated descriptor fields', () {
      final asset = ContentSubmissionStagedAsset(
        clientSubmissionId: clientSubmissionId,
        digest: digest,
        relativePath: '$clientSubmissionId/$digest',
      );

      expect(asset.toEntity().toModel(), asset);
    });

    test('does not map malformed persisted paths or ownership', () {
      expect(
        ContentSubmissionStagedAssetEntity(
          clientSubmissionId: clientSubmissionId,
          digest: digest,
          relativePath: '../$digest',
        ).toModel(),
        isNull,
      );
      expect(
        ContentSubmissionStagedAssetEntity(
          clientSubmissionId: 'not-a-uuid',
          digest: digest,
          relativePath: '$clientSubmissionId/$digest',
        ).toModel(),
        isNull,
      );
    });
  });
}
