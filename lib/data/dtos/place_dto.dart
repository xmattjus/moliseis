import 'package:dart_mappable/dart_mappable.dart';
import 'package:moliseis/data/core/relation_update.dart';
import 'package:moliseis/data/core/relation_update_hook.dart';
import 'package:moliseis/data/core/relation_update_resolver_hook.dart';
import 'package:moliseis/data/mappers/content_category_mapper.dart';
import 'package:moliseis/domain/core/sync_dto.dart';
import 'package:moliseis/domain/models/content_category.dart';

part 'generated/place_dto.mapper.dart';

@MappableClass(
  caseStyle: CaseStyle.snakeCase,
  hook: RelationUpdateResolverHook(['city_id']),
  generateMethods:
      GenerateMethods.decode |
      GenerateMethods.encode |
      GenerateMethods.stringify,
  includeCustomMappers: [ContentCategoryMapper()],
)
class PlaceDto with PlaceDtoMappable implements SyncDto {
  const PlaceDto({
    required this.id,
    required this.name,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.category,
    this.cityId = const Keep<int>(),
    required this.createdAt,
    required this.modifiedAt,
    this.deletedAt,
  });

  @override
  final int id;
  final String name;
  final String description;
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
