import 'package:meta/meta.dart';

/// The kind of published entity a submission was promoted into.
///
/// Deliberately distinct from any submission-level event heuristic: the
/// promotion target is an explicit moderation decision, not something derived
/// from draft dates.
enum AdminPromotionTarget {
  /// The submission was published as a place.
  place,

  /// The submission was published as an event.
  event,
}

/// An immutable record of one successful promotion.
///
/// It serves two purposes with the same shape: the result returned by a
/// successful repository `promote` call, and the durable source-to-published
/// linkage loaded as part of an `AdminSubmission`. Historical accepted
/// submissions may legitimately have no promotion; absence never implies a
/// target.
@immutable
class AdminSubmissionPromotion {
  /// Creates a promotion pointing at [entityId] of kind [target].
  const AdminSubmissionPromotion({
    required this.target,
    required this.entityId,
  });

  /// Kind of the published entity created from the source submission.
  final AdminPromotionTarget target;

  /// Persistent identifier of the published place or event.
  final int entityId;

  @override
  bool operator ==(Object other) {
    return other is AdminSubmissionPromotion &&
        other.target == target &&
        other.entityId == entityId;
  }

  @override
  int get hashCode => Object.hash(target, entityId);
}
