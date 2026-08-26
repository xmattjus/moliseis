import 'package:moliseis/domain/models/admin_submission.dart';
import 'package:moliseis/domain/models/admin_submission_asset.dart';
import 'package:moliseis/domain/models/admin_submission_input.dart';
import 'package:moliseis/domain/models/admin_submission_promotion.dart';
import 'package:moliseis/domain/models/admin_submission_status.dart';
import 'package:moliseis/domain/models/content_category.dart';

/// Serializes the editor-owned admin submission input for the Edge Function.
Map<String, dynamic> adminSubmissionInputToWireMap(
  AdminSubmissionInput input,
) {
  return <String, dynamic>{
    'category': input.category.name,
    'city': input.city,
    'name': input.name,
    'description': input.description,
    'description_delta': input.descriptionDelta,
    'start_date': input.startDate?.toUtc().toIso8601String(),
    'end_date': input.endDate?.toUtc().toIso8601String(),
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
  return AdminSubmissionPromotion(
    target: target,
    entityId: entityId,
  );
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
