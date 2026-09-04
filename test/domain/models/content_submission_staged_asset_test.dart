import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/models/content_submission_staged_asset.dart';

void main() {
  const clientSubmissionId = '2a1b0c3d-4e5f-4a6b-8c9d-0e1f2a3b4c5d';
  const digest = '0123456789abcdef0123456789abcdef01234567';

  group('ContentSubmissionStagedAsset', () {
    test('retains only its ownership, digest, and relative path', () {
      final asset = ContentSubmissionStagedAsset(
        clientSubmissionId: clientSubmissionId,
        digest: digest,
        relativePath: '$clientSubmissionId/$digest',
      );

      expect(asset.clientSubmissionId, clientSubmissionId);
      expect(asset.digest, digest);
      expect(asset.relativePath, '$clientSubmissionId/$digest');
    });

    test('rejects malformed ownership, digest, and relative path', () {
      expect(
        () => ContentSubmissionStagedAsset(
          clientSubmissionId: 'not-a-uuid',
          digest: digest,
          relativePath: '$clientSubmissionId/$digest',
        ),
        throwsArgumentError,
      );
      expect(
        () => ContentSubmissionStagedAsset(
          clientSubmissionId: clientSubmissionId,
          digest: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
          relativePath: '$clientSubmissionId/$digest',
        ),
        throwsArgumentError,
      );
      expect(
        () => ContentSubmissionStagedAsset(
          clientSubmissionId: clientSubmissionId,
          digest: digest,
          relativePath: '../$digest',
        ),
        throwsArgumentError,
      );
    });
  });
}
