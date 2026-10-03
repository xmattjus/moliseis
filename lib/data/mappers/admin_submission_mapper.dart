import 'package:moliseis/domain/core/event_time.dart';
import 'package:moliseis/domain/models/admin_external_event.dart';
import 'package:moliseis/domain/models/admin_submission.dart';
import 'package:moliseis/domain/models/admin_submission_asset.dart';
import 'package:moliseis/domain/models/admin_submission_input.dart';
import 'package:moliseis/domain/models/admin_submission_promotion.dart';
import 'package:moliseis/domain/models/admin_submission_status.dart';
import 'package:moliseis/domain/models/content_category.dart';

/// Serializes the editor-owned admin submission input for the Edge Function.
Map<String, dynamic> adminSubmissionInputToWireMap(AdminSubmissionInput input) {
  return <String, dynamic>{
    'category': input.category.name,
    'city': input.city,
    'name': input.name,
    'description': input.description,
    'description_delta': input.descriptionDelta,
    'all_day': input.allDay,
    'start_date': input.allDay
        ? null
        : input.startDate?.toUtc().toIso8601String(),
    'end_date': input.allDay ? null : input.endDate?.toUtc().toIso8601String(),
    'start_calendar_date': input.allDay && input.startDate != null
        ? EventTimePolicy().calendarDateForUtc(input.startDate!).toString()
        : null,
    'end_calendar_date': input.allDay && input.endDate != null
        ? EventTimePolicy().calendarDateForUtc(input.endDate!).toString()
        : null,
    'latitude': input.latitude,
    'longitude': input.longitude,
  };
}

/// Parses an admin submission returned by the Edge Function.
AdminSubmission adminSubmissionFromWire(Object? value) {
  final object = _object(value, 'submission');
  final descriptionDelta = _descriptionDelta(object['description_delta']);
  final assets = _assets(object['assets']);

  return AdminSubmission(
    id: _required<int>(object, 'id'),
    city: _required<String>(object, 'city'),
    name: _required<String>(object, 'name'),
    description: _nullableString(object['description'], 'description'),
    descriptionDelta: descriptionDelta,
    allDay: object.containsKey('all_day') && _required<bool>(object, 'all_day'),
    startDate: _nullableDateTime(object['start_date'], 'start_date'),
    endDate: _nullableDateTime(object['end_date'], 'end_date'),
    category: adminSubmissionCategoryFromWire(object['category']),
    userName: _required<String>(object, 'user_name'),
    userEmail: _required<String>(object, 'user_email'),
    status: adminSubmissionStatusFromWire(object['status']),
    createdAt: _requiredDateTime(object, 'created_at'),
    modifiedAt: _requiredDateTime(object, 'modified_at'),
    latitude: _nullableDouble(object['latitude'], 'latitude'),
    longitude: _nullableDouble(object['longitude'], 'longitude'),
    promotion: _promotionFromLinks(
      placeId: _nullablePositiveInt(
        object['promoted_place_id'],
        'promoted_place_id',
      ),
      eventId: _nullablePositiveInt(
        object['promoted_event_id'],
        'promoted_event_id',
      ),
    ),
    assets: assets,
    externalEvent: _externalEvent(object),
    targetEventId: _nullablePositiveInt(
      object['target_event_id'],
      'target_event_id',
    ),
  );
}

/// Parses the promotion response envelope of a successful promote call.
///
/// Requires exactly the keys `target_type` and `entity_id`, a `target_type`
/// of `place` or `event`, and a positive integer `entity_id`; unknown targets,
/// missing or non-positive IDs, doubles, strings, and any other key set are
/// contract violations.
AdminSubmissionPromotion adminSubmissionPromotionFromWire(Object? value) {
  final object = _object(value, 'promotion');
  if (!hasExactKeys(object, const <String>{'target_type', 'entity_id'})) {
    throw const FormatException('promotion envelope is invalid');
  }
  final target = switch (object['target_type']) {
    'place' => AdminPromotionTarget.place,
    'event' => AdminPromotionTarget.event,
    _ => throw const FormatException('target_type is invalid'),
  };
  final entityId = object['entity_id'];
  if (entityId is! int || entityId <= 0) {
    throw const FormatException('entity_id is invalid');
  }
  return AdminSubmissionPromotion(target: target, entityId: entityId);
}

/// Whether [object] carries exactly [keys] and nothing else.
bool hasExactKeys(Map<String, dynamic> object, Set<String> keys) {
  final actualKeys = object.keys.toSet();
  return actualKeys.length == keys.length && actualKeys.containsAll(keys);
}

/// Builds the durable promotion from the two nullable link fields.
///
/// Both links absent parses as no promotion; exactly one link selects its
/// target. A row carrying both links violates the database CHECK constraint,
/// so it is rejected defensively instead of being mapped.
AdminSubmissionPromotion? _promotionFromLinks({
  required int? placeId,
  required int? eventId,
}) {
  if (placeId == null && eventId == null) {
    return null;
  }
  if (placeId != null && eventId != null) {
    throw const FormatException(
      'promoted_place_id and promoted_event_id are mutually exclusive',
    );
  }
  return AdminSubmissionPromotion(
    target: placeId != null
        ? AdminPromotionTarget.place
        : AdminPromotionTarget.event,
    entityId: placeId ?? eventId!,
  );
}

/// Parses read-only persisted asset metadata returned by the Edge Function.
AdminSubmissionAsset adminSubmissionAssetFromWire(Object? value) {
  final object = _object(value, 'asset');
  return AdminSubmissionAsset(
    id: _required<int>(object, 'id'),
    url: _required<String>(object, 'url'),
    width: _required<int>(object, 'width'),
    height: _required<int>(object, 'height'),
  );
}

/// Parses a content category returned by the Edge Function.
ContentCategory adminSubmissionCategoryFromWire(Object? value) {
  return switch (value) {
    'unknown' => ContentCategory.unknown,
    'nature' => ContentCategory.nature,
    'history' => ContentCategory.history,
    'folklore' => ContentCategory.folklore,
    'food' => ContentCategory.food,
    'allure' => ContentCategory.allure,
    'experience' => ContentCategory.experience,
    _ => throw const FormatException('category is invalid'),
  };
}

/// Parses a moderation status returned by the Edge Function.
AdminSubmissionStatus adminSubmissionStatusFromWire(Object? value) {
  return switch (value) {
    'pending' => AdminSubmissionStatus.pending,
    'accepted' => AdminSubmissionStatus.accepted,
    'rejected' => AdminSubmissionStatus.rejected,
    _ => throw const FormatException('status is invalid'),
  };
}

Map<String, dynamic> _object(Object? value, String path) {
  if (value is! Map) {
    throw FormatException('$path must be an object');
  }

  final object = <String, dynamic>{};
  for (final MapEntry(:key, :value) in value.entries) {
    if (key is! String) {
      throw FormatException('$path has a non-string key');
    }
    object[key] = value;
  }
  return object;
}

T _required<T>(Map<String, dynamic> object, String field) {
  final value = object[field];
  if (value is! T) {
    throw FormatException('$field is invalid');
  }
  return value;
}

String? _nullableString(Object? value, String field) {
  if (value == null) {
    return null;
  }
  if (value is String) {
    return value;
  }
  throw FormatException('$field is invalid');
}

/// Tolerant nullable coordinate parsing: absent keys and null values parse as
/// null, JSON numbers normalize to double, and anything else is a contract
/// violation. Ranges are not checked here; the mapper transports faithfully.
double? _nullableDouble(Object? value, String field) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  throw FormatException('$field is invalid');
}

/// Tolerant nullable positive-integer parsing for durable link columns:
/// absent keys and null values parse as null, a positive JSON integer parses
/// as the value, and doubles, strings, zero, and negatives are contract
/// violations.
int? _nullablePositiveInt(Object? value, String field) {
  if (value == null) {
    return null;
  }
  if (value is int && value > 0) {
    return value;
  }
  throw FormatException('$field is invalid');
}

DateTime _requiredDateTime(Map<String, dynamic> object, String field) {
  return _dateTime(_required<String>(object, field), field);
}

DateTime? _nullableDateTime(Object? value, String field) {
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw FormatException('$field is invalid');
  }
  return _dateTime(value, field);
}

DateTime _dateTime(String value, String field) {
  try {
    return DateTime.parse(value);
  } on FormatException {
    throw FormatException('$field is invalid');
  }
}

List<Map<String, dynamic>>? _descriptionDelta(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is! List) {
    throw const FormatException('description_delta is invalid');
  }
  return value
      .map((entry) => _object(entry, 'description_delta entry'))
      .toList(growable: false);
}

List<AdminSubmissionAsset> _assets(Object? value) {
  if (value is! List) {
    throw const FormatException('assets is invalid');
  }
  return value.map(adminSubmissionAssetFromWire).toList(growable: false);
}

AdminExternalEvent? _externalEvent(Map<String, dynamic> object) {
  final id = _nullablePositiveInt(
    object['external_event_record_id'],
    'external_event_record_id',
  );
  if (id == null) return null;
  return AdminExternalEvent(
    recordId: id,
    snapshotHash: _required<String>(object, 'external_moderation_hash'),
    snapshotVersion: _required<int>(object, 'external_normalization_version'),
    snapshot: _object(object['external_normalized'], 'external_normalized'),
    mode: switch (object['external_mode']) {
      null => null,
      'create' => AdminExternalEventMode.create,
      'update' => AdminExternalEventMode.update,
      _ => throw const FormatException('external_mode is invalid'),
    },
    eventId: _nullablePositiveInt(
      object['external_event_id'],
      'external_event_id',
    ),
    currentHash: _nullableString(object['moderation_hash'], 'moderation_hash'),
    currentSnapshot: object['current_source_normalized'] == null
        ? null
        : _object(
            object['current_source_normalized'],
            'current_source_normalized',
          ),
  );
}

/// Reads opaque preview tokens without parsing, trimming or reserializing.
AdminEventMergePreview adminEventMergePreviewFromWire(Object? value) {
  final object = _object(value, 'preview');
  final groups = object['groups'];
  if (groups is! List) throw const FormatException('groups is invalid');
  return AdminEventMergePreview(
    targetEventId: _required<int>(object, 'target_event_id'),
    submissionVersionToken: _required<String>(
      object,
      'submission_version_token',
    ),
    eventVersionToken: _required<String>(object, 'event_version_token'),
    currentSourceHash: _nullableString(
      object['moderation_hash'],
      'moderation_hash',
    ),
    currentSourceSnapshot: object['current_source_normalized'] == null
        ? null
        : _object(
            object['current_source_normalized'],
            'current_source_normalized',
          ),
    groups: groups.map((value) {
      final group = _object(value, 'group');
      final name = _required<String>(group, 'group');
      if (!const {
        'name',
        'category',
        'description',
        'schedule',
        'location',
      }.contains(name)) {
        throw const FormatException('group is invalid');
      }
      return AdminEventMergeGroup(
        name: name,
        providerChanged: _required<bool>(group, 'provider_changed'),
        moderatorChanged: _required<bool>(group, 'moderator_changed'),
        apply: _required<bool>(group, 'apply'),
        overwrite: _required<bool>(group, 'overwrite'),
        base: _object(group['base'], 'base'),
        source: _object(group['source'], 'source'),
        moderated: _object(group['moderated'], 'moderated'),
        current: _object(group['current'], 'current'),
      );
    }).toList(),
  );
}

/// Candidate warnings remain distinct from canonical targets.
AdminEventCandidates adminEventCandidatesFromWire(Object? value) {
  final object = _object(value, 'candidates');
  List<AdminEventCandidate> read(String key) {
    final values = object[key];
    if (values is! List) throw FormatException('$key is invalid');
    return values.map((value) {
      final item = _object(value, key);
      return AdminEventCandidate(
        id: _required<int>(item, 'id'),
        name: _required<String>(item, 'name'),
        city: _nullableString(item['city'], 'city'),
      );
    }).toList();
  }

  return AdminEventCandidates(
    events: read('events'),
    pendingWarnings: read('pending_warnings'),
  );
}

/// Parses a stable resolution outcome and the optional next revision.
AdminEventResolution adminEventResolutionFromWire(Object? value) {
  final object = _object(value, 'resolution');
  final outcome = _required<String>(object, 'outcome');
  if (!const {
    'linked',
    'applied',
    'already_resolved',
    'unignored',
  }.contains(outcome)) {
    throw const FormatException('resolution outcome is invalid');
  }
  return AdminEventResolution(
    outcome: outcome,
    eventId: _nullablePositiveInt(object['target_event_id'], 'target_event_id'),
    pendingId: _nullablePositiveInt(
      object['pending_submission_id'],
      'pending_submission_id',
    ),
  );
}

/// Parses only the metadata exposed by the minimal ignored-source list.
AdminIgnoredSource adminIgnoredSourceFromWire(Object? value) {
  final object = _object(value, 'ignored source');
  return AdminIgnoredSource(
    id: _required<int>(object, 'id'),
    provider: _required<String>(object, 'provider'),
    externalId: _required<String>(object, 'external_id'),
    name: _required<String>(object, 'name'),
    ignoredAt: _required<String>(object, 'ignored_at'),
    eventId: _nullablePositiveInt(object['event_id'], 'event_id'),
    occurrenceKey: _nullableString(object['occurrence_key'], 'occurrence_key'),
  );
}
