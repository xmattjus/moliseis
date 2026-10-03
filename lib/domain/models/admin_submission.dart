import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:moliseis/domain/core/description_delta.dart';
import 'package:moliseis/domain/models/admin_external_event.dart';
import 'package:moliseis/domain/models/admin_submission_asset.dart';
import 'package:moliseis/domain/models/admin_submission_promotion.dart';
import 'package:moliseis/domain/models/admin_submission_status.dart';
import 'package:moliseis/domain/models/content_category.dart';

/// A moderation submission used for both dashboard summaries and editor detail.
///
/// One model intentionally serves both views while the editorial dashboard is
/// small; a backend round can split transport models later if needed.
@immutable
class AdminSubmission {
  /// Creates a submission with immutable snapshots of [descriptionDelta] and
  /// [assets].
  AdminSubmission({
    required this.id,
    required this.city,
    required this.name,
    this.description,
    List<Map<String, dynamic>>? descriptionDelta,
    this.startDate,
    this.endDate,
    this.allDay = false,
    required this.category,
    required this.userName,
    required this.userEmail,
    required this.status,
    required this.createdAt,
    required this.modifiedAt,
    this.latitude,
    this.longitude,
    this.promotion,
    this.externalEvent,
    this.targetEventId,
    List<AdminSubmissionAsset> assets = const [],
  }) : descriptionDelta = freezeDescriptionDelta(descriptionDelta),
       assets = List<AdminSubmissionAsset>.unmodifiable(assets);

  /// Persistent backend identifier for the submission.
  final int id;

  /// Municipality selected by the contributor.
  final String city;

  /// Contributor-provided title of the place or event.
  final String name;

  /// Plain-text description, when available.
  final String? description;

  /// Immutable rich-text Delta operations, when available.
  final List<Map<String, dynamic>>? descriptionDelta;

  /// Event start date and time, when this is an event.
  final DateTime? startDate;

  /// Event end date and time, when this is an event.
  final DateTime? endDate;

  /// Whether a meaningful initial clock is unavailable.
  final bool allDay;

  /// Non-null content category required by the backend schema.
  final ContentCategory category;

  /// Name of the contributor who created the submission.
  final String userName;

  /// E-mail address of the contributor who created the submission.
  final String userEmail;

  /// Current moderation state.
  final AdminSubmissionStatus status;

  /// Timestamp at which the submission was created.
  final DateTime createdAt;

  /// Timestamp at which the submission was last modified.
  final DateTime modifiedAt;

  /// Optional geographical latitude in decimal degrees, when present.
  ///
  /// Loaded values are transported faithfully; ranges and pairing are enforced
  /// at the write boundaries, so legacy malformed rows can load for repair.
  final double? latitude;

  /// Optional geographical longitude in decimal degrees, when present.
  final double? longitude;

  /// Durable source-to-published linkage, when this submission was promoted.
  ///
  /// Null for pending and rejected submissions and for historical accepted
  /// rows promoted before durable links existed; null absence never implies a
  /// target.
  final AdminSubmissionPromotion? promotion;

  /// Immutable snapshot of persisted remote assets displayed read-only by the
  /// editor.
  final List<AdminSubmissionAsset> assets;

  /// External provenance is absent for human and legacy submissions.
  final AdminExternalEvent? externalEvent;

  /// Acceptance against an existing Event, distinct from promotion.
  final int? targetEventId;

  /// Whether dates identify this submission as an event.
  ///
  /// The backend has no event flag, so this intentionally matches the public
  /// form's date-based heuristic.
  bool get isEvent => startDate != null || endDate != null;

  @override
  bool operator ==(Object other) {
    return other is AdminSubmission &&
        other.id == id &&
        other.city == city &&
        other.name == name &&
        other.description == description &&
        const DeepCollectionEquality().equals(
          other.descriptionDelta,
          descriptionDelta,
        ) &&
        other.startDate == startDate &&
        other.endDate == endDate &&
        other.allDay == allDay &&
        other.category == category &&
        other.userName == userName &&
        other.userEmail == userEmail &&
        other.status == status &&
        other.createdAt == createdAt &&
        other.modifiedAt == modifiedAt &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.promotion == promotion &&
        other.externalEvent == externalEvent &&
        other.targetEventId == targetEventId &&
        const DeepCollectionEquality().equals(other.assets, assets);
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    city,
    name,
    description,
    const DeepCollectionEquality().hash(descriptionDelta),
    startDate,
    endDate,
    allDay,
    category,
    userName,
    userEmail,
    status,
    createdAt,
    modifiedAt,
    latitude,
    longitude,
    promotion,
    externalEvent,
    targetEventId,
    const DeepCollectionEquality().hash(assets),
  ]);
}
