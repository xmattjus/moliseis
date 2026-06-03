import 'package:meta/meta.dart';
import 'package:moliseis/domain/models/content_base.dart';

/// A time-bound event.
@immutable
class Event extends ContentBase {
  const Event({
    required super.category,
    required super.city,
    required super.coordinates,
    required super.createdAt,
    required super.description,
    required super.media,
    required super.modifiedAt,
    required super.name,
    required super.remoteId,
    required super.isSaved,
    required this.startDate,
    this.endDate,
  });

  final DateTime startDate;
  final DateTime? endDate;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Event &&
        super == other &&
        other.startDate.isAtSameMomentAs(startDate) &&
        _bothNullOrSameMoment(other.endDate, endDate);
  }

  @override
  int get hashCode => Object.hash(
    super.hashCode,
    startDate.millisecondsSinceEpoch,
    endDate?.millisecondsSinceEpoch,
  );

  /// Whether both [dt] and [other] are null or occur at the same moment.
  static bool _bothNullOrSameMoment(DateTime? dt, DateTime? other) {
    if (dt == null && other == null) return true;

    if (dt != null && other != null && dt.isAtSameMomentAs(other)) {
      return true;
    }

    return false;
  }
}
