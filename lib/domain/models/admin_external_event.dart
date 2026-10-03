import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:moliseis/domain/core/description_delta.dart';

/// Whether a source proposal establishes or updates a canonical Event.
enum AdminExternalEventMode { create, update }

/// Immutable source state; values retain the backend's canonical
/// representation.
/// Flutter displays and copies these values, but never canonicalizes them.
@immutable
final class AdminExternalEvent {
  AdminExternalEvent({
    required this.recordId,
    required this.snapshotHash,
    required this.snapshotVersion,
    required Map<String, dynamic> snapshot,
    required this.mode,
    this.eventId,
    this.currentHash,
    Map<String, dynamic>? currentSnapshot,
  }) : snapshot = freezeDescriptionDelta([snapshot])!.single,
       currentSnapshot = currentSnapshot == null
           ? null
           : freezeDescriptionDelta([currentSnapshot])!.single;

  final int recordId;
  final String snapshotHash;
  final int snapshotVersion;
  final Map<String, dynamic> snapshot;
  final AdminExternalEventMode? mode;
  final int? eventId;
  final String? currentHash;
  final Map<String, dynamic>? currentSnapshot;

  /// Acknowledgement is available only for a displayed, different source hash.
  bool get stale => currentHash != null && currentHash != snapshotHash;
  @override
  bool operator ==(Object other) =>
      other is AdminExternalEvent &&
      other.recordId == recordId &&
      other.snapshotHash == snapshotHash &&
      other.snapshotVersion == snapshotVersion &&
      other.mode == mode &&
      other.eventId == eventId &&
      other.currentHash == currentHash &&
      const DeepCollectionEquality().equals(other.snapshot, snapshot) &&
      const DeepCollectionEquality().equals(
        other.currentSnapshot,
        currentSnapshot,
      );

  @override
  int get hashCode => Object.hash(
    recordId,
    snapshotHash,
    snapshotVersion,
    mode,
    eventId,
    currentHash,
    const DeepCollectionEquality().hash(snapshot),
    const DeepCollectionEquality().hash(currentSnapshot),
  );
}

/// One atomic merge group computed authoritatively by the backend.
final class AdminEventMergeGroup {
  AdminEventMergeGroup({
    required this.name,
    required this.providerChanged,
    required this.moderatorChanged,
    required this.apply,
    required this.overwrite,
    required Map<String, dynamic> base,
    required Map<String, dynamic> source,
    required Map<String, dynamic> moderated,
    required Map<String, dynamic> current,
  }) : base = freezeDescriptionDelta([base])!.single,
       source = freezeDescriptionDelta([source])!.single,
       moderated = freezeDescriptionDelta([moderated])!.single,
       current = freezeDescriptionDelta([current])!.single;

  final String name;
  final bool providerChanged;
  final bool moderatorChanged;
  final bool apply;
  final bool overwrite;
  final Map<String, dynamic> base;
  final Map<String, dynamic> source;
  final Map<String, dynamic> moderated;
  final Map<String, dynamic> current;
}

/// Preview tokens are opaque strings, independent of display timestamps.
final class AdminEventMergePreview {
  AdminEventMergePreview({
    required this.targetEventId,
    required this.submissionVersionToken,
    required this.eventVersionToken,
    required List<AdminEventMergeGroup> groups,
    this.currentSourceHash,
    Map<String, dynamic>? currentSourceSnapshot,
  }) : groups = List.unmodifiable(groups),
       currentSourceSnapshot = currentSourceSnapshot == null
           ? null
           : freezeDescriptionDelta([currentSourceSnapshot])!.single;

  final int targetEventId;
  final String submissionVersionToken;
  final String eventVersionToken;
  final List<AdminEventMergeGroup> groups;
  final String? currentSourceHash;
  final Map<String, dynamic>? currentSourceSnapshot;
}

/// Selectable canonical Event summary or advisory pending-submission warning.
final class AdminEventCandidate {
  const AdminEventCandidate({required this.id, required this.name, this.city});
  final int id;
  final String name;
  final String? city;
}

/// Pending warnings are deliberately separate from selectable Event targets.
final class AdminEventCandidates {
  AdminEventCandidates({
    required List<AdminEventCandidate> events,
    required List<AdminEventCandidate> pendingWarnings,
  }) : events = List.unmodifiable(events),
       pendingWarnings = List.unmodifiable(pendingWarnings);
  final List<AdminEventCandidate> events;
  final List<AdminEventCandidate> pendingWarnings;
}

/// Durable resolution and any next pending revision returned by the backend.
final class AdminEventResolution {
  const AdminEventResolution({
    required this.outcome,
    this.eventId,
    this.pendingId,
  });
  final String outcome;
  final int? eventId;
  final int? pendingId;
}

/// Minimal ignored-source listing, independently reachable from any submission.
final class AdminIgnoredSource {
  const AdminIgnoredSource({
    required this.id,
    required this.provider,
    required this.externalId,
    required this.name,
    required this.ignoredAt,
    this.eventId,
    this.occurrenceKey,
  });
  final int id;
  final String provider;
  final String externalId;
  final String name;
  final String ignoredAt;
  final int? eventId;
  final String? occurrenceKey;
}
