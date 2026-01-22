import 'package:latlong2/latlong.dart';
import 'package:meta/meta.dart';
import 'package:moliseis/data/sources/event.dart';
import 'package:moliseis/domain/models/content_base.dart';

@immutable
class EventContent extends ContentBase {
  const EventContent({
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

  factory EventContent.fromEvent(Event event) => EventContent(
    category: event.category,
    city: event.city,
    coordinates: LatLng(event.coordinates[0], event.coordinates[1]),
    createdAt: event.createdAt,
    description: event.description ?? '',
    media: event.media,
    modifiedAt: event.modifiedAt,
    name: event.name!,
    remoteId: event.remoteId,
    startDate: event.startDate!,
    endDate: event.endDate,
    isSaved: event.isSaved,
  );
}
