// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of '../media_dto.dart';

class MediaDtoMapper extends ClassMapperBase<MediaDto> {
  MediaDtoMapper._();

  static MediaDtoMapper? _instance;
  static MediaDtoMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = MediaDtoMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'MediaDto';

  static int _$id(MediaDto v) => v.id;
  static const Field<MediaDto, int> _f$id = Field('id', _$id);
  static String? _$title(MediaDto v) => v.title;
  static const Field<MediaDto, String> _f$title = Field(
    'title',
    _$title,
    opt: true,
  );
  static String? _$author(MediaDto v) => v.author;
  static const Field<MediaDto, String> _f$author = Field(
    'author',
    _$author,
    opt: true,
  );
  static String? _$license(MediaDto v) => v.license;
  static const Field<MediaDto, String> _f$license = Field(
    'license',
    _$license,
    opt: true,
  );
  static String? _$licenseUrl(MediaDto v) => v.licenseUrl;
  static const Field<MediaDto, String> _f$licenseUrl = Field(
    'licenseUrl',
    _$licenseUrl,
    key: r'license_url',
    opt: true,
  );
  static String _$url(MediaDto v) => v.url;
  static const Field<MediaDto, String> _f$url = Field('url', _$url);
  static int _$width(MediaDto v) => v.width;
  static const Field<MediaDto, int> _f$width = Field('width', _$width);
  static int _$height(MediaDto v) => v.height;
  static const Field<MediaDto, int> _f$height = Field('height', _$height);
  static RelationUpdate<int> _$placeId(MediaDto v) => v.placeId;
  static const Field<MediaDto, RelationUpdate<int>> _f$placeId = Field(
    'placeId',
    _$placeId,
    key: r'place_id',
    opt: true,
    def: const Keep<int>(),
    hook: RelationUpdateHook<int>(decoder: relationUpdateDecodeInt),
  );
  static RelationUpdate<int> _$eventId(MediaDto v) => v.eventId;
  static const Field<MediaDto, RelationUpdate<int>> _f$eventId = Field(
    'eventId',
    _$eventId,
    key: r'event_id',
    opt: true,
    def: const Keep<int>(),
    hook: RelationUpdateHook<int>(decoder: relationUpdateDecodeInt),
  );
  static DateTime _$createdAt(MediaDto v) => v.createdAt;
  static const Field<MediaDto, DateTime> _f$createdAt = Field(
    'createdAt',
    _$createdAt,
    key: r'created_at',
  );
  static DateTime _$modifiedAt(MediaDto v) => v.modifiedAt;
  static const Field<MediaDto, DateTime> _f$modifiedAt = Field(
    'modifiedAt',
    _$modifiedAt,
    key: r'modified_at',
  );
  static DateTime? _$deletedAt(MediaDto v) => v.deletedAt;
  static const Field<MediaDto, DateTime> _f$deletedAt = Field(
    'deletedAt',
    _$deletedAt,
    key: r'deleted_at',
    opt: true,
  );

  @override
  final MappableFields<MediaDto> fields = const {
    #id: _f$id,
    #title: _f$title,
    #author: _f$author,
    #license: _f$license,
    #licenseUrl: _f$licenseUrl,
    #url: _f$url,
    #width: _f$width,
    #height: _f$height,
    #placeId: _f$placeId,
    #eventId: _f$eventId,
    #createdAt: _f$createdAt,
    #modifiedAt: _f$modifiedAt,
    #deletedAt: _f$deletedAt,
  };

  @override
  final MappingHook hook = const RelationUpdateResolverHook([
    'event_id',
    'place_id',
  ]);
  static MediaDto _instantiate(DecodingData data) {
    return MediaDto(
      id: data.dec(_f$id),
      title: data.dec(_f$title),
      author: data.dec(_f$author),
      license: data.dec(_f$license),
      licenseUrl: data.dec(_f$licenseUrl),
      url: data.dec(_f$url),
      width: data.dec(_f$width),
      height: data.dec(_f$height),
      placeId: data.dec(_f$placeId),
      eventId: data.dec(_f$eventId),
      createdAt: data.dec(_f$createdAt),
      modifiedAt: data.dec(_f$modifiedAt),
      deletedAt: data.dec(_f$deletedAt),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static MediaDto fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<MediaDto>(map);
  }

  static MediaDto fromJson(String json) {
    return ensureInitialized().decodeJson<MediaDto>(json);
  }
}

mixin MediaDtoMappable {
  String toJson() {
    return MediaDtoMapper.ensureInitialized().encodeJson<MediaDto>(
      this as MediaDto,
    );
  }

  Map<String, dynamic> toMap() {
    return MediaDtoMapper.ensureInitialized().encodeMap<MediaDto>(
      this as MediaDto,
    );
  }

  @override
  String toString() {
    return MediaDtoMapper.ensureInitialized().stringifyValue(this as MediaDto);
  }
}

