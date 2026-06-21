// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of '../place_dto.dart';

class PlaceDtoMapper extends ClassMapperBase<PlaceDto> {
  PlaceDtoMapper._();

  static PlaceDtoMapper? _instance;
  static PlaceDtoMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = PlaceDtoMapper._());
      MapperContainer.globals.useAll([ContentCategoryMapper()]);
    }
    return _instance!;
  }

  @override
  final String id = 'PlaceDto';

  static int _$id(PlaceDto v) => v.id;
  static const Field<PlaceDto, int> _f$id = Field('id', _$id);
  static String _$name(PlaceDto v) => v.name;
  static const Field<PlaceDto, String> _f$name = Field('name', _$name);
  static String? _$description(PlaceDto v) => v.description;
  static const Field<PlaceDto, String> _f$description = Field(
    'description',
    _$description,
  );
  static double _$latitude(PlaceDto v) => v.latitude;
  static const Field<PlaceDto, double> _f$latitude = Field(
    'latitude',
    _$latitude,
  );
  static double _$longitude(PlaceDto v) => v.longitude;
  static const Field<PlaceDto, double> _f$longitude = Field(
    'longitude',
    _$longitude,
  );
  static ContentCategory _$category(PlaceDto v) => v.category;
  static const Field<PlaceDto, ContentCategory> _f$category = Field(
    'category',
    _$category,
  );
  static RelationUpdate<int> _$cityId(PlaceDto v) => v.cityId;
  static const Field<PlaceDto, RelationUpdate<int>> _f$cityId = Field(
    'cityId',
    _$cityId,
    key: r'city_id',
    opt: true,
    def: const Keep<int>(),
    hook: RelationUpdateHook<int>(decoder: relationUpdateDecodeInt),
  );
  static DateTime _$createdAt(PlaceDto v) => v.createdAt;
  static const Field<PlaceDto, DateTime> _f$createdAt = Field(
    'createdAt',
    _$createdAt,
    key: r'created_at',
  );
  static DateTime _$modifiedAt(PlaceDto v) => v.modifiedAt;
  static const Field<PlaceDto, DateTime> _f$modifiedAt = Field(
    'modifiedAt',
    _$modifiedAt,
    key: r'modified_at',
  );
  static DateTime? _$deletedAt(PlaceDto v) => v.deletedAt;
  static const Field<PlaceDto, DateTime> _f$deletedAt = Field(
    'deletedAt',
    _$deletedAt,
    key: r'deleted_at',
    opt: true,
  );

  @override
  final MappableFields<PlaceDto> fields = const {
    #id: _f$id,
    #name: _f$name,
    #description: _f$description,
    #latitude: _f$latitude,
    #longitude: _f$longitude,
    #category: _f$category,
    #cityId: _f$cityId,
    #createdAt: _f$createdAt,
    #modifiedAt: _f$modifiedAt,
    #deletedAt: _f$deletedAt,
  };

  @override
  final MappingHook hook = const RelationUpdateResolverHook(['city_id']);
  static PlaceDto _instantiate(DecodingData data) {
    return PlaceDto(
      id: data.dec(_f$id),
      name: data.dec(_f$name),
      description: data.dec(_f$description),
      latitude: data.dec(_f$latitude),
      longitude: data.dec(_f$longitude),
      category: data.dec(_f$category),
      cityId: data.dec(_f$cityId),
      createdAt: data.dec(_f$createdAt),
      modifiedAt: data.dec(_f$modifiedAt),
      deletedAt: data.dec(_f$deletedAt),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static PlaceDto fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<PlaceDto>(map);
  }

  static PlaceDto fromJson(String json) {
    return ensureInitialized().decodeJson<PlaceDto>(json);
  }
}

mixin PlaceDtoMappable {
  String toJson() {
    return PlaceDtoMapper.ensureInitialized().encodeJson<PlaceDto>(
      this as PlaceDto,
    );
  }

  Map<String, dynamic> toMap() {
    return PlaceDtoMapper.ensureInitialized().encodeMap<PlaceDto>(
      this as PlaceDto,
    );
  }

  @override
  String toString() {
    return PlaceDtoMapper.ensureInitialized().stringifyValue(this as PlaceDto);
  }
}

