import 'dart:math' show Random;

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:moliseis/domain/core/description_delta.dart';
import 'package:moliseis/domain/core/event_time.dart';
import 'package:moliseis/domain/models/admin_submission_status.dart';
import 'package:moliseis/domain/models/content_category.dart';

/// Stable account/session ownership, independent of a database technical ID.
@immutable
final class AdminDraftOwner {
  /// Creates a local owner, generating a secure UUID-v4 session when absent.
  AdminDraftOwner({
    required this.accountId,
    String? sessionId,
    this.submissionId,
  }) : sessionId = sessionId ?? _newSessionId() {
    if (!isValidAccountId(accountId) ||
        !isValidSessionId(this.sessionId) ||
        (submissionId != null && submissionId! <= 0)) {
      throw ArgumentError('Invalid Admin draft ownership.');
    }
  }

  /// Authenticated editor account, not the remote contributor identity.
  final String accountId;

  /// Stable local identity retained across checkpoints and restoration.
  final String sessionId;

  /// Existing remote target; null denotes a genuinely new local submission.
  final int? submissionId;

  /// Unambiguous lookup for one resumable account/target session.
  String get lookupKey => '$accountId/${submissionId ?? 'new'}';

  static final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );
  static final _sessionUuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  /// Whether an account is a canonical UUID suitable for private ownership.
  static bool isValidAccountId(String value) => _uuid.hasMatch(value);

  /// Whether a session is a canonical UUID-v4.
  static bool isValidSessionId(String value) => _sessionUuid.hasMatch(value);

  static String _newSessionId() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  @override
  bool operator ==(Object other) =>
      other is AdminDraftOwner &&
      accountId == other.accountId &&
      sessionId == other.sessionId &&
      submissionId == other.submissionId;

  @override
  int get hashCode => Object.hash(accountId, sessionId, submissionId);
}

/// Lossless immutable fields, including values not yet valid for remote Save.
@immutable
final class AdminDraftSnapshot {
  /// Captures fields and recursively freezes the caller's rich-text Delta.
  AdminDraftSnapshot({
    this.category,
    this.city,
    this.name,
    this.description,
    List<Map<String, dynamic>>? descriptionDelta,
    this.eventDates = const EventDateDraft.disabled(),
    this.latitudeText = '',
    this.longitudeText = '',
  }) : descriptionDelta = freezeDescriptionDelta(descriptionDelta);

  /// Selected category, including an unfinished null selection.
  final ContentCategory? category;

  /// Unnormalized editor municipality.
  final String? city;

  /// Unnormalized editor title.
  final String? name;

  /// Plain-text projection accompanying [descriptionDelta].
  final String? description;

  /// Deeply immutable rich-text operations, without UI codec dependencies.
  final List<Map<String, dynamic>>? descriptionDelta;

  /// Complete temporal mode, civil dates and unresolved/exact instants.
  final EventDateDraft eventDates;

  /// Exact latitude editor text, including invalid or incomplete input.
  final String latitudeText;

  /// Exact longitude editor text, including invalid or incomplete input.
  final String longitudeText;

  /// Compares fields exactly, or uses validated coordinates for remote truth.
  ///
  /// Invalid coordinates never count as remotely confirmed. Numeric spelling
  /// differences remain significant in ordinary local structural equality.
  bool fieldsEqualTo(
    AdminDraftSnapshot other, {
    bool semanticCoordinates = false,
  }) {
    final fieldsEqual =
        category == other.category &&
        city == other.city &&
        name == other.name &&
        description == other.description &&
        const DeepCollectionEquality().equals(
          descriptionDelta,
          other.descriptionDelta,
        ) &&
        eventDates == other.eventDates;
    if (!fieldsEqual) return false;
    if (!semanticCoordinates) {
      return latitudeText == other.latitudeText &&
          longitudeText == other.longitudeText;
    }
    final coordinates = _coordinates();
    final otherCoordinates = other._coordinates();
    return coordinates != null && coordinates == otherCoordinates;
  }

  (double?, double?)? _coordinates() {
    final lat = latitudeText.trim();
    final lon = longitudeText.trim();
    if (lat.isEmpty && lon.isEmpty) return (null, null);
    final latitude = double.tryParse(lat.replaceAll(',', '.'));
    final longitude = double.tryParse(lon.replaceAll(',', '.'));
    if (latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }
    return (latitude, longitude);
  }

  static const _unset = Object();

  /// Copies editable fields while distinguishing null from an omitted value.
  AdminDraftSnapshot copyWith({
    Object? category = _unset,
    Object? city = _unset,
    Object? name = _unset,
    Object? description = _unset,
    Object? descriptionDelta = _unset,
    EventDateDraft? eventDates,
    String? latitudeText,
    String? longitudeText,
  }) => AdminDraftSnapshot(
    category: identical(category, _unset)
        ? this.category
        : category as ContentCategory?,
    city: identical(city, _unset) ? this.city : city as String?,
    name: identical(name, _unset) ? this.name : name as String?,
    description: identical(description, _unset)
        ? this.description
        : description as String?,
    descriptionDelta: identical(descriptionDelta, _unset)
        ? this.descriptionDelta
        : descriptionDelta as List<Map<String, dynamic>>?,
    eventDates: eventDates ?? this.eventDates,
    latitudeText: latitudeText ?? this.latitudeText,
    longitudeText: longitudeText ?? this.longitudeText,
  );

  @override
  bool operator ==(Object other) =>
      other is AdminDraftSnapshot && fieldsEqualTo(other);

  @override
  int get hashCode => Object.hash(
    category,
    city,
    name,
    description,
    const DeepCollectionEquality().hash(descriptionDelta),
    eventDates,
    latitudeText,
    longitudeText,
  );
}

/// Last confirmed remote projection; persisted values are historical on load.
@immutable
final class AdminRemoteBaseline {
  /// Captures a remote projection without implying current authorization.
  AdminRemoteBaseline({
    required this.snapshot,
    required this.status,
    required DateTime modifiedAt,
  }) : modifiedAt = modifiedAt.toUtc();

  /// Editable fields confirmed by the remote response.
  final AdminDraftSnapshot snapshot;

  /// Moderation status observed in that same response.
  final AdminSubmissionStatus status;

  /// Observed server timestamp, not a compare-and-swap or idempotency key.
  final DateTime modifiedAt;

  @override
  bool operator ==(Object other) =>
      other is AdminRemoteBaseline &&
      snapshot == other.snapshot &&
      status == other.status &&
      modifiedAt == other.modifiedAt;

  @override
  int get hashCode => Object.hash(snapshot, status, modifiedAt);
}

/// One durable checkpoint and the remote baseline known when it was captured.
@immutable
final class AdminSubmissionDraft {
  /// Captures field durability independently of staged-asset ownership.
  const AdminSubmissionDraft({
    required this.owner,
    required this.snapshot,
    this.remoteBaseline,
  });

  /// Exact account/session/target identity retained by every replacement.
  final AdminDraftOwner owner;

  /// Last explicitly persisted editable field snapshot.
  final AdminDraftSnapshot snapshot;

  /// Historical remote truth; local persistence never confirms a remote Save.
  final AdminRemoteBaseline? remoteBaseline;

  @override
  bool operator ==(Object other) =>
      other is AdminSubmissionDraft &&
      owner == other.owner &&
      snapshot == other.snapshot &&
      remoteBaseline == other.remoteBaseline;

  @override
  int get hashCode => Object.hash(owner, snapshot, remoteBaseline);
}
