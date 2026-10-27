import 'package:objectbox/objectbox.dart';

/// One retained account/target owner and its versioned field checkpoint.
@Entity()
class AdminSubmissionDraftEntity {
  /// Creates a persistence row; malformed rows remain detectable on loading.
  AdminSubmissionDraftEntity({
    required this.lookupKey,
    required this.accountId,
    required this.sessionId,
    required this.submissionId,
    required this.payload,
    this.id = 0,
  });

  /// Auto-assigned storage identity, never a domain/session UUID.
  @Id()
  int id;

  /// Unique canonical account/target key, validated against the other fields.
  @Unique()
  final String lookupKey;

  /// Editing account used for isolated lookup and validation.
  @Index()
  final String accountId;

  /// Stable UUID-v4 owner; another target cannot reuse it.
  @Unique()
  final String sessionId;

  /// Existing remote target, or null for the account's new local target.
  final int? submissionId;

  /// Versioned JSON containing checkpoint fields and historical remote truth.
  final String payload;
}
