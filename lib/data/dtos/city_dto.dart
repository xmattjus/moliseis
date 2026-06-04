import 'package:dart_mappable/dart_mappable.dart';
import 'package:moliseis/domain/core/sync_dto.dart';

part 'generated/city_dto.mapper.dart';

@MappableClass(
  caseStyle: CaseStyle.snakeCase,
  generateMethods:
      GenerateMethods.decode |
      GenerateMethods.encode |
      GenerateMethods.stringify,
)
class CityDto with CityDtoMappable implements SyncDto {
  const CityDto({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.modifiedAt,
    this.deletedAt,
  });

  @override
  final int id;

  final String name;

  final DateTime createdAt;

  @override
  final DateTime modifiedAt;

  @override
  final DateTime? deletedAt;
}
