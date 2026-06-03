import 'package:meta/meta.dart';
import 'package:moliseis/domain/models/content_base.dart';

/// A point of interest.
@immutable
class Place extends ContentBase {
  const Place({
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
  });
}
