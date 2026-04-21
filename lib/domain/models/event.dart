import 'package:meta/meta.dart';
import 'package:moliseis/domain/models/content_base.dart';

/// A time-bound event taking place in the Molise region.
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
}
