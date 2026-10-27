import 'dart:convert';

import 'package:moliseis/data/data-sources/admin_submission_draft_entity.dart';
import 'package:moliseis/domain/core/event_time.dart';
import 'package:moliseis/domain/models/admin_submission_draft.dart';
import 'package:moliseis/domain/models/admin_submission_status.dart';
import 'package:moliseis/domain/models/content_category.dart';

/// Decodes supported, structurally valid rows without inventing fresh owners.
extension AdminSubmissionDraftEntityMapper on AdminSubmissionDraftEntity {
  /// Throws [FormatException] for malformed/unsupported ownership or payload.
  AdminSubmissionDraft toModel() {
    if (!AdminDraftOwner.isValidAccountId(accountId) ||
        !AdminDraftOwner.isValidSessionId(sessionId) ||
        (submissionId != null && submissionId! <= 0)) {
      throw const FormatException('Invalid Admin checkpoint ownership.');
    }
    final owner = AdminDraftOwner(
      accountId: accountId,
      sessionId: sessionId,
      submissionId: submissionId,
    );
    if (lookupKey != owner.lookupKey) {
      throw const FormatException('Invalid Admin account/target key.');
    }
    final data = _object(jsonDecode(payload));
    if (data['version'] is! int || data['version'] != 1) {
      throw const FormatException('Unsupported Admin checkpoint version.');
    }
    final remote = data['remote'];
    AdminRemoteBaseline? baseline;
    if (remote != null) {
      if (submissionId == null) {
        throw const FormatException('New target cannot have remote history.');
      }
      final value = _object(remote);
      final status = _string(value['status']);
      final matched = AdminSubmissionStatus.values.where(
        (value) => value.name == status,
      );
      if (matched.isEmpty) {
        throw const FormatException('Invalid remote moderation status.');
      }
      baseline = AdminRemoteBaseline(
        snapshot: _snapshot(value['snapshot']),
        status: matched.single,
        modifiedAt: _instant(value['modifiedAt']),
      );
    }
    return AdminSubmissionDraft(
      owner: owner,
      snapshot: _snapshot(data['snapshot']),
      remoteBaseline: baseline,
    );
  }
}

/// Encodes only durable checkpoint and historical remote information.
extension AdminSubmissionDraftMapper on AdminSubmissionDraft {
  /// Retains [id] when replacing an existing exact owner row.
  AdminSubmissionDraftEntity toEntity({int id = 0}) {
    if (owner.submissionId == null && remoteBaseline != null) {
      throw const FormatException('New target cannot have remote history.');
    }
    final baseline = remoteBaseline;
    return AdminSubmissionDraftEntity(
      id: id,
      lookupKey: owner.lookupKey,
      accountId: owner.accountId,
      sessionId: owner.sessionId,
      submissionId: owner.submissionId,
      payload: jsonEncode({
        'version': 1,
        'snapshot': _encodeSnapshot(snapshot),
        'remote': baseline == null
            ? null
            : {
                'snapshot': _encodeSnapshot(baseline.snapshot),
                'status': baseline.status.name,
                'modifiedAt': baseline.modifiedAt.toUtc().toIso8601String(),
              },
      }),
    );
  }
}

Map<String, Object?> _encodeSnapshot(AdminDraftSnapshot value) => {
  'category': value.category?.name,
  'city': value.city,
  'name': value.name,
  'description': value.description,
  'delta': value.descriptionDelta,
  'latitude': value.latitudeText,
  'longitude': value.longitudeText,
  'dates': {
    'enabled': value.eventDates.enabled,
    'allDay': value.eventDates.allDay,
    'startDay': value.eventDates.startCalendarDate?.toString(),
    'endDay': value.eventDates.endCalendarDate?.toString(),
    'start': value.eventDates.startInstantUtc?.toIso8601String(),
    'end': value.eventDates.endInstantUtc?.toIso8601String(),
  },
};

AdminDraftSnapshot _snapshot(Object? raw) {
  final data = _object(raw);
  final categoryName = _nullableString(data['category']);
  final category = ContentCategory.values.where((c) => c.name == categoryName);
  if (categoryName != null && category.isEmpty) {
    throw const FormatException('Invalid Admin category.');
  }
  final delta = data['delta'];
  if (delta != null && delta is! List) {
    throw const FormatException('Invalid Admin Delta.');
  }
  return AdminDraftSnapshot(
    category: categoryName == null ? null : category.single,
    city: _nullableString(data['city']),
    name: _nullableString(data['name']),
    description: _nullableString(data['description']),
    descriptionDelta: delta == null
        ? null
        : (delta as List).map(_object).toList(),
    latitudeText: _string(data['latitude']),
    longitudeText: _string(data['longitude']),
    eventDates: _dates(data['dates']),
  );
}

EventDateDraft _dates(Object? raw) {
  final data = _object(raw);
  final enabled = data['enabled'];
  final allDay = data['allDay'];
  if (enabled is! bool || allDay is! bool) {
    throw const FormatException('Invalid Admin temporal mode.');
  }
  final startDay = _day(data['startDay']);
  final endDay = _day(data['endDay']);
  final start = data['start'] == null ? null : _instant(data['start']);
  final end = data['end'] == null ? null : _instant(data['end']);
  if (!enabled) {
    if (allDay ||
        startDay != null ||
        endDay != null ||
        start != null ||
        end != null) {
      throw const FormatException('Disabled event has temporal values.');
    }
    return const EventDateDraft.disabled();
  }
  if (startDay == null) {
    if (endDay != null || start != null || end != null) {
      throw const FormatException('Temporal values require a start day.');
    }
    return EventDateDraft.enabledEmpty(allDay: allDay);
  }
  if (start == null) {
    if (end != null || allDay) {
      throw const FormatException('Invalid unresolved event state.');
    }
    return EventDateDraft.unresolvedStart(startDay, endCalendarDate: endDay);
  }
  return EventDateDraft.exact(
    startCalendarDate: startDay,
    endCalendarDate: endDay,
    startInstantUtc: start,
    endInstantUtc: end,
    allDay: allDay,
  );
}

Map<String, dynamic> _object(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Expected Admin checkpoint object.');
  }
  return value;
}

String _string(Object? value) {
  if (value is! String) {
    throw const FormatException('Expected checkpoint text.');
  }
  return value;
}

String? _nullableString(Object? value) => value == null ? null : _string(value);

DateTime _instant(Object? value) {
  final text = _string(value);
  final parsed = DateTime.tryParse(text);
  if (parsed == null ||
      parsed.toIso8601String() != text ||
      !text.endsWith('Z')) {
    throw const FormatException('Expected UTC checkpoint instant.');
  }
  return parsed;
}

EventCalendarDate? _day(Object? value) {
  if (value == null) {
    return null;
  }
  final text = _string(value);
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text);
  if (match == null) {
    throw const FormatException('Invalid checkpoint civil day.');
  }
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final normalized = DateTime.utc(year, month, day);
  if (normalized.year != year ||
      normalized.month != month ||
      normalized.day != day) {
    throw const FormatException('Invalid checkpoint civil day.');
  }
  return EventCalendarDate(year, month, day);
}
