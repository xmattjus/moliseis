import 'package:dart_mappable/dart_mappable.dart';
import 'package:moliseis/data/core/relation_update.dart';
import 'package:moliseis/data/core/relation_update_hook.dart';
import 'package:moliseis/data/core/relation_update_resolver_hook.dart';
import 'package:moliseis/domain/core/sync_dto.dart';

part 'generated/media_dto.mapper.dart';

@MappableClass(
  caseStyle: CaseStyle.snakeCase,
  hook: RelationUpdateResolverHook(['event_id', 'place_id']),
  generateMethods:
      GenerateMethods.decode |
      GenerateMethods.encode |
      GenerateMethods.stringify,
)
class MediaDto with MediaDtoMappable implements SyncDto {
  const MediaDto({
    required this.id,
    this.title,
    this.author,
    this.license,
    this.licenseUrl,
    required this.url,
    required this.width,
    required this.height,
    this.placeId = const Keep<int>(),
    this.eventId = const Keep<int>(),
    required this.createdAt,
    required this.modifiedAt,
    this.deletedAt,
  });

  @override
  final int id;

  @MappableField(key: 'description')
  final String? title;
  final String? author;
  final String? license;
  final String? licenseUrl;

  final String url;
  final int width;
  final int height;

  /// Mutually exclusive with [eventId]: when assigned, [eventId] must be
  /// [Clear] — the backend rejects simultaneous assignment of both relations.
  @MappableField(
    hook: RelationUpdateHook<int>(
      decoder: relationUpdateDecodeInt,
    ),
  )
  final RelationUpdate<int> placeId;

  /// Mutually exclusive with [placeId]: when assigned, [placeId] must be
  /// [Clear] — the backend rejects simultaneous assignment of both relations.
  @MappableField(
    hook: RelationUpdateHook<int>(
      decoder: relationUpdateDecodeInt,
    ),
  )
  final RelationUpdate<int> eventId;

  final DateTime createdAt;

  @override
  final DateTime modifiedAt;

  @override
  final DateTime? deletedAt;
}
