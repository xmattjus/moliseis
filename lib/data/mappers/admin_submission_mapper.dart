import 'package:moliseis/domain/models/admin_submission.dart';
import 'package:moliseis/domain/models/admin_submission_asset.dart';
import 'package:moliseis/domain/models/admin_submission_input.dart';
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
    assets: assets,
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
