import 'package:moliseis/domain/models/admin_submission.dart';
import 'package:moliseis/domain/models/admin_submission_input.dart';
import 'package:moliseis/domain/models/admin_submission_status.dart';
import 'package:moliseis/domain/repositories/admin_content_submission_repository.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';

/// Typed-error implementation used until the admin backend contract exists.
///
/// The backend round will add the real data dependencies once its APIs and
/// access rules are defined.
class AdminContentSubmissionRepositoryImpl
    implements AdminContentSubmissionRepository {
  /// Creates the placeholder with its failure logger.
  AdminContentSubmissionRepositoryImpl({required Logger logger})
    : _logger = logger;

  final Logger _logger;

  @override
  Future<Result<List<AdminSubmission>>> list() async => _unavailable();

  @override
  Future<Result<AdminSubmission>> getById(int id) async => _unavailable();

  @override
  Future<Result<AdminSubmission>> create(AdminSubmissionInput input) async =>
      _unavailable();

  @override
  Future<Result<AdminSubmission>> update(
    int id,
    AdminSubmissionInput input,
  ) async => _unavailable();

  @override
  Future<Result<void>> changeStatus(
    int id,
    AdminSubmissionStatus status,
  ) async => _unavailable();

  /// Logs the unavailable backend consistently for every repository operation.
  Result<T> _unavailable<T>() {
    _logger.log(const AdminBackendUnavailable());
    return Result.error(
      Exception(
        "L'area redazione non è ancora disponibile: "
        'backend in fase di definizione.',
      ),
    );
  }
}
