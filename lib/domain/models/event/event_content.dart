import 'package:meta/meta.dart';
import 'package:moliseis/domain/models/core/content_base.dart';
import 'package:moliseis/domain/models/event/event.dart';

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
    coordinates: event.coordinates,
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
