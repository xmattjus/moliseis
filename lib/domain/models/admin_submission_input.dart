import 'package:meta/meta.dart';
import 'package:moliseis/domain/core/description_delta.dart';
import 'package:moliseis/domain/models/content_category.dart';

/// The editable payload owned by the admin submission editor.
///
/// Contributor identity is derived by the future backend from the authenticated
/// session. IDs, moderation state, timestamps, location coordinates, address,
/// and assets are deliberately absent so the frontend cannot imply a full-row
/// update that could clear data it does not own. Whether this is an event is
/// derived from its dates.
@immutable
class AdminSubmissionInput {
  /// Creates an editor-owned payload with an immutable Delta snapshot.
  AdminSubmissionInput({
    required this.category,
    required this.city,
    required this.name,
    this.description,
    List<Map<String, dynamic>>? descriptionDelta,
    this.startDate,
    this.endDate,
  }) : descriptionDelta = freezeDescriptionDelta(descriptionDelta);

  /// Non-null category normalized by the editor before saving.
  final ContentCategory category;

  /// Municipality selected by the editor.
  final String city;

  /// Place or event name selected by the editor.
  final String name;

  /// Plain-text description, when available.
  final String? description;

  /// Immutable rich-text Delta operations, when available.
  final List<Map<String, dynamic>>? descriptionDelta;

  /// Event start date and time, when this is an event.
  final DateTime? startDate;

  /// Event end date and time, when this is an event.
  final DateTime? endDate;
}
