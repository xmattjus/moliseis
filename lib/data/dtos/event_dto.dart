import 'package:dart_mappable/dart_mappable.dart';
import 'package:moliseis/data/core/relation_update.dart';
import 'package:moliseis/data/core/relation_update_hook.dart';
import 'package:moliseis/data/core/relation_update_resolver_hook.dart';
import 'package:moliseis/data/mappers/content_category_mapper.dart';
import 'package:moliseis/domain/core/sync_dto.dart';
import 'package:moliseis/domain/models/content_category.dart';

part 'generated/event_dto.mapper.dart';

@MappableClass(
  caseStyle: CaseStyle.snakeCase,
  hook: RelationUpdateResolverHook(['city_id']),
  generateMethods:
      GenerateMethods.decode |
      GenerateMethods.encode |
      GenerateMethods.stringify,
  includeCustomMappers: [ContentCategoryMapper()],
)
class EventDto with EventDtoMappable implements SyncDto {
  const EventDto({
    required this.id,
    required this.name,
    required this.description,
    required this.startDate,
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.createdAt,
    required this.modifiedAt,
    this.cityId = const Keep<int>(),
    this.deletedAt,
    this.endDate,
  });

  @override
  final int id;
  final String name;
  final String description;
  final DateTime startDate;
  final DateTime? endDate;
  final double latitude;
  final double longitude;
  final ContentCategory category;
  @MappableField(
    hook: RelationUpdateHook<int>(
      decoder: relationUpdateDecodeInt,
    ),
  )
  final RelationUpdate<int> cityId;
  final DateTime createdAt;
  @override
  final DateTime modifiedAt;
  @override
  final DateTime? deletedAt;
}
