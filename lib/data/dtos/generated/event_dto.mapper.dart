// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of '../event_dto.dart';

class EventDtoMapper extends ClassMapperBase<EventDto> {
  EventDtoMapper._();

  static EventDtoMapper? _instance;
  static EventDtoMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = EventDtoMapper._());
      MapperContainer.globals.useAll([ContentCategoryMapper()]);
    }
    return _instance!;
  }

  @override
  final String id = 'EventDto';

  static int _$id(EventDto v) => v.id;
  static const Field<EventDto, int> _f$id = Field('id', _$id);
  static String _$name(EventDto v) => v.name;
  static const Field<EventDto, String> _f$name = Field('name', _$name);
  static String? _$description(EventDto v) => v.description;
  static const Field<EventDto, String> _f$description = Field(
    'description',
    _$description,
  );
  static DateTime _$startDate(EventDto v) => v.startDate;
  static const Field<EventDto, DateTime> _f$startDate = Field(
    'startDate',
    _$startDate,
    key: r'start_date',
  );
  static double _$latitude(EventDto v) => v.latitude;
  static const Field<EventDto, double> _f$latitude = Field(
    'latitude',
    _$latitude,
  );
  static double _$longitude(EventDto v) => v.longitude;
  static const Field<EventDto, double> _f$longitude = Field(
    'longitude',
    _$longitude,
  );
  static ContentCategory _$category(EventDto v) => v.category;
  static const Field<EventDto, ContentCategory> _f$category = Field(
    'category',
    _$category,
  );
  static DateTime _$createdAt(EventDto v) => v.createdAt;
  static const Field<EventDto, DateTime> _f$createdAt = Field(
    'createdAt',
    _$createdAt,
    key: r'created_at',
  );
  static DateTime _$modifiedAt(EventDto v) => v.modifiedAt;
  static const Field<EventDto, DateTime> _f$modifiedAt = Field(
    'modifiedAt',
    _$modifiedAt,
    key: r'modified_at',
  );
  static RelationUpdate<int> _$cityId(EventDto v) => v.cityId;
  static const Field<EventDto, RelationUpdate<int>> _f$cityId = Field(
    'cityId',
    _$cityId,
    key: r'city_id',
    opt: true,
    def: const Keep<int>(),
    hook: RelationUpdateHook<int>(decoder: relationUpdateDecodeInt),
  );
  static DateTime? _$deletedAt(EventDto v) => v.deletedAt;
  static const Field<EventDto, DateTime> _f$deletedAt = Field(
    'deletedAt',
    _$deletedAt,
    key: r'deleted_at',
    opt: true,
  );
  static DateTime? _$endDate(EventDto v) => v.endDate;
  static const Field<EventDto, DateTime> _f$endDate = Field(
    'endDate',
    _$endDate,
    key: r'end_date',
    opt: true,
  );

  @override
  final MappableFields<EventDto> fields = const {
    #id: _f$id,
    #name: _f$name,
    #description: _f$description,
    #startDate: _f$startDate,
    #latitude: _f$latitude,
    #longitude: _f$longitude,
    #category: _f$category,
    #createdAt: _f$createdAt,
    #modifiedAt: _f$modifiedAt,
    #cityId: _f$cityId,
    #deletedAt: _f$deletedAt,
    #endDate: _f$endDate,
  };

  @override
  final MappingHook hook = const RelationUpdateResolverHook(['city_id']);
  static EventDto _instantiate(DecodingData data) {
    return EventDto(
      id: data.dec(_f$id),
      name: data.dec(_f$name),
      description: data.dec(_f$description),
      startDate: data.dec(_f$startDate),
      latitude: data.dec(_f$latitude),
      longitude: data.dec(_f$longitude),
      category: data.dec(_f$category),
      createdAt: data.dec(_f$createdAt),
      modifiedAt: data.dec(_f$modifiedAt),
      cityId: data.dec(_f$cityId),
      deletedAt: data.dec(_f$deletedAt),
      endDate: data.dec(_f$endDate),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static EventDto fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<EventDto>(map);
  }

  static EventDto fromJson(String json) {
    return ensureInitialized().decodeJson<EventDto>(json);
  }
}

mixin EventDtoMappable {
  String toJson() {
    return EventDtoMapper.ensureInitialized().encodeJson<EventDto>(
      this as EventDto,
    );
  }

  Map<String, dynamic> toMap() {
    return EventDtoMapper.ensureInitialized().encodeMap<EventDto>(
      this as EventDto,
    );
  }

  @override
  String toString() {
    return EventDtoMapper.ensureInitialized().stringifyValue(this as EventDto);
  }
}

