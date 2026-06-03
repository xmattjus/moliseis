// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of '../city_dto.dart';

class CityDtoMapper extends ClassMapperBase<CityDto> {
  CityDtoMapper._();

  static CityDtoMapper? _instance;
  static CityDtoMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = CityDtoMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'CityDto';

  static int _$id(CityDto v) => v.id;
  static const Field<CityDto, int> _f$id = Field('id', _$id);
  static String _$name(CityDto v) => v.name;
  static const Field<CityDto, String> _f$name = Field('name', _$name);
  static DateTime _$createdAt(CityDto v) => v.createdAt;
  static const Field<CityDto, DateTime> _f$createdAt = Field(
    'createdAt',
    _$createdAt,
    key: r'created_at',
  );
  static DateTime _$modifiedAt(CityDto v) => v.modifiedAt;
  static const Field<CityDto, DateTime> _f$modifiedAt = Field(
    'modifiedAt',
    _$modifiedAt,
    key: r'modified_at',
  );
  static DateTime? _$deletedAt(CityDto v) => v.deletedAt;
  static const Field<CityDto, DateTime> _f$deletedAt = Field(
    'deletedAt',
    _$deletedAt,
    key: r'deleted_at',
    opt: true,
  );

  @override
  final MappableFields<CityDto> fields = const {
    #id: _f$id,
    #name: _f$name,
    #createdAt: _f$createdAt,
    #modifiedAt: _f$modifiedAt,
    #deletedAt: _f$deletedAt,
  };

  static CityDto _instantiate(DecodingData data) {
    return CityDto(
      id: data.dec(_f$id),
      name: data.dec(_f$name),
      createdAt: data.dec(_f$createdAt),
      modifiedAt: data.dec(_f$modifiedAt),
      deletedAt: data.dec(_f$deletedAt),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static CityDto fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<CityDto>(map);
  }

  static CityDto fromJson(String json) {
    return ensureInitialized().decodeJson<CityDto>(json);
  }
}

mixin CityDtoMappable {
  String toJson() {
    return CityDtoMapper.ensureInitialized().encodeJson<CityDto>(
      this as CityDto,
    );
  }

  Map<String, dynamic> toMap() {
    return CityDtoMapper.ensureInitialized().encodeMap<CityDto>(
      this as CityDto,
    );
  }

  @override
  String toString() {
    return CityDtoMapper.ensureInitialized().stringifyValue(this as CityDto);
  }
}

