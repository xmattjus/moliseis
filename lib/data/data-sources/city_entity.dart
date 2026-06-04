import 'package:moliseis/data/data-sources/event_entity.dart';
import 'package:moliseis/data/data-sources/place_entity.dart';
import 'package:moliseis/domain/core/sync_entity.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
class CityEntity implements SyncEntity {
  const CityEntity({
    required this.remoteId,
    required this.name,
    required this.createdAt,
    required this.modifiedAt,
    required this.places,
    required this.events,
    this.isDeleted = false,
  });

  @override
  @Id(assignable: true)
  final int remoteId;

  final String name;

  @Property(type: PropertyType.dateNano)
  final DateTime createdAt;

  @override
  @Property(type: PropertyType.dateNano)
  final DateTime modifiedAt;

  @override
  final bool isDeleted;

  @Backlink('city')
  final ToMany<PlaceEntity> places;

  @Backlink('city')
  final ToMany<EventEntity> events;

  CityEntity copyWith({
    String? name,
    DateTime? createdAt,
    DateTime? modifiedAt,
    bool? isDeleted,
  }) => CityEntity(
    remoteId: remoteId,
    name: name ?? this.name,
    createdAt: createdAt ?? this.createdAt,
    modifiedAt: modifiedAt ?? this.modifiedAt,
    isDeleted: isDeleted ?? this.isDeleted,
    places: places,
    events: events,
  );
}
