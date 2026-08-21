import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/models/admin_submission.dart';
import 'package:moliseis/domain/models/admin_submission_asset.dart';
import 'package:moliseis/domain/models/admin_submission_input.dart';
import 'package:moliseis/domain/models/admin_submission_status.dart';
import 'package:moliseis/domain/models/content_category.dart';

void main() {
  group('AdminSubmissionStatus', () {
    test('exposes Italian labels for every moderation status', () {
      expect(AdminSubmissionStatus.pending.label, 'Da revisionare');
      expect(AdminSubmissionStatus.accepted.label, 'Accettato');
      expect(AdminSubmissionStatus.rejected.label, 'Rifiutato');
    });
  });

  group('AdminSubmission', () {
    test('derives event status from either date', () {
      final noDates = AdminSubmission(
        id: 1,
        city: 'Campobasso',
        name: 'Palazzo',
        category: ContentCategory.history,
        userName: 'Mario Rossi',
        userEmail: 'mario@example.com',
        status: AdminSubmissionStatus.pending,
        createdAt: DateTime.utc(2026),
        modifiedAt: DateTime.utc(2026),
      );
      final startDate = AdminSubmission(
        id: 2,
        city: 'Campobasso',
        name: 'Festival',
        startDate: DateTime.utc(2026, 8, 20),
        category: ContentCategory.folklore,
        userName: 'Mario Rossi',
        userEmail: 'mario@example.com',
        status: AdminSubmissionStatus.pending,
        createdAt: DateTime.utc(2026),
        modifiedAt: DateTime.utc(2026),
      );
      final endDate = AdminSubmission(
        id: 3,
        city: 'Campobasso',
        name: 'Festival',
        endDate: DateTime.utc(2026, 8, 21),
        category: ContentCategory.folklore,
        userName: 'Mario Rossi',
        userEmail: 'mario@example.com',
        status: AdminSubmissionStatus.pending,
        createdAt: DateTime.utc(2026),
        modifiedAt: DateTime.utc(2026),
      );

      expect(noDates.isEvent, isFalse);
      expect(startDate.isEvent, isTrue);
      expect(endDate.isEvent, isTrue);
    });

    test('retains a frozen description Delta after source mutation', () {
      final source = <Map<String, dynamic>>[
        {'insert': 'Descrizione originale\n'},
      ];
      final submission = AdminSubmission(
        id: 1,
        city: 'Campobasso',
        name: 'Palazzo',
        descriptionDelta: source,
        category: ContentCategory.history,
        userName: 'Mario Rossi',
        userEmail: 'mario@example.com',
        status: AdminSubmissionStatus.pending,
        createdAt: DateTime.utc(2026),
        modifiedAt: DateTime.utc(2026),
      );

      source.single['insert'] = 'Descrizione modificata\n';
      source.add({'insert': 'Aggiunta\n'});

      expect(submission.descriptionDelta, [
        {'insert': 'Descrizione originale\n'},
      ]);
    });

    test('retains an unmodifiable assets snapshot', () {
      const asset = AdminSubmissionAsset(
        id: 1,
        url: 'https://example.com/image.jpg',
        width: 1200,
        height: 800,
      );
      final source = <AdminSubmissionAsset>[asset];
      final submission = AdminSubmission(
        id: 1,
        city: 'Campobasso',
        name: 'Palazzo',
        category: ContentCategory.history,
        userName: 'Mario Rossi',
        userEmail: 'mario@example.com',
        status: AdminSubmissionStatus.pending,
        createdAt: DateTime.utc(2026),
        modifiedAt: DateTime.utc(2026),
        assets: source,
      );
      final hashCode = submission.hashCode;

      source.clear();

      expect(submission.assets, [asset]);
      expect(submission.hashCode, hashCode);
      expect(
        () => submission.assets.add(
          const AdminSubmissionAsset(
            id: 2,
            url: 'https://example.com/other.jpg',
            width: 800,
            height: 600,
          ),
        ),
        throwsUnsupportedError,
      );
    });
  });

  group('AdminSubmissionInput', () {
    test('retains a frozen description Delta after source mutation', () {
      final source = <Map<String, dynamic>>[
        {'insert': 'Descrizione originale\n'},
      ];
      final input = AdminSubmissionInput(
        category: ContentCategory.history,
        city: 'Campobasso',
        name: 'Palazzo',
        descriptionDelta: source,
      );

      source.single['insert'] = 'Descrizione modificata\n';
      source.add({'insert': 'Aggiunta\n'});

      expect(input.descriptionDelta, [
        {'insert': 'Descrizione originale\n'},
      ]);
    });
  });
}
