// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of '../content_submission_dto.dart';

class ContentSubmissionDtoMapper extends ClassMapperBase<ContentSubmissionDto> {
  ContentSubmissionDtoMapper._();

  static ContentSubmissionDtoMapper? _instance;
  static ContentSubmissionDtoMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ContentSubmissionDtoMapper._());
      MapperContainer.globals.useAll([ContentCategoryMapper()]);
    }
    return _instance!;
  }

  @override
  final String id = 'ContentSubmissionDto';

  static String _$city(ContentSubmissionDto v) => v.city;
  static const Field<ContentSubmissionDto, String> _f$city = Field(
    'city',
    _$city,
  );
  static String _$name(ContentSubmissionDto v) => v.name;
  static const Field<ContentSubmissionDto, String> _f$name = Field(
    'name',
    _$name,
  );
  static String? _$description(ContentSubmissionDto v) => v.description;
  static const Field<ContentSubmissionDto, String> _f$description = Field(
    'description',
    _$description,
    opt: true,
  );
  static double? _$latitude(ContentSubmissionDto v) => v.latitude;
  static const Field<ContentSubmissionDto, double> _f$latitude = Field(
    'latitude',
    _$latitude,
    opt: true,
  );
  static double? _$longitude(ContentSubmissionDto v) => v.longitude;
  static const Field<ContentSubmissionDto, double> _f$longitude = Field(
    'longitude',
    _$longitude,
    opt: true,
  );
  static String? _$address(ContentSubmissionDto v) => v.address;
  static const Field<ContentSubmissionDto, String> _f$address = Field(
    'address',
    _$address,
    opt: true,
  );
  static DateTime? _$startDate(ContentSubmissionDto v) => v.startDate;
  static const Field<ContentSubmissionDto, DateTime> _f$startDate = Field(
    'startDate',
    _$startDate,
    key: r'start_date',
    opt: true,
  );
  static DateTime? _$endDate(ContentSubmissionDto v) => v.endDate;
  static const Field<ContentSubmissionDto, DateTime> _f$endDate = Field(
    'endDate',
    _$endDate,
    key: r'end_date',
    opt: true,
  );
  static ContentCategory? _$category(ContentSubmissionDto v) => v.category;
  static const Field<ContentSubmissionDto, ContentCategory> _f$category = Field(
    'category',
    _$category,
    opt: true,
  );
  static String _$userEmail(ContentSubmissionDto v) => v.userEmail;
  static const Field<ContentSubmissionDto, String> _f$userEmail = Field(
    'userEmail',
    _$userEmail,
    key: r'user_email',
  );
  static String _$userName(ContentSubmissionDto v) => v.userName;
  static const Field<ContentSubmissionDto, String> _f$userName = Field(
    'userName',
    _$userName,
    key: r'user_name',
  );
  static String _$userId(ContentSubmissionDto v) => v.userId;
  static const Field<ContentSubmissionDto, String> _f$userId = Field(
    'userId',
    _$userId,
    key: r'user_id',
  );
  static DateTime? _$createdAt(ContentSubmissionDto v) => v.createdAt;
  static const Field<ContentSubmissionDto, DateTime> _f$createdAt = Field(
    'createdAt',
    _$createdAt,
    key: r'created_at',
    opt: true,
  );
  static DateTime? _$modifiedAt(ContentSubmissionDto v) => v.modifiedAt;
  static const Field<ContentSubmissionDto, DateTime> _f$modifiedAt = Field(
    'modifiedAt',
    _$modifiedAt,
    key: r'modified_at',
    opt: true,
  );

  @override
  final MappableFields<ContentSubmissionDto> fields = const {
    #city: _f$city,
    #name: _f$name,
    #description: _f$description,
    #latitude: _f$latitude,
    #longitude: _f$longitude,
    #address: _f$address,
    #startDate: _f$startDate,
    #endDate: _f$endDate,
    #category: _f$category,
    #userEmail: _f$userEmail,
    #userName: _f$userName,
    #userId: _f$userId,
    #createdAt: _f$createdAt,
    #modifiedAt: _f$modifiedAt,
  };

  static ContentSubmissionDto _instantiate(DecodingData data) {
    return ContentSubmissionDto(
      city: data.dec(_f$city),
      name: data.dec(_f$name),
      description: data.dec(_f$description),
      latitude: data.dec(_f$latitude),
      longitude: data.dec(_f$longitude),
      address: data.dec(_f$address),
      startDate: data.dec(_f$startDate),
      endDate: data.dec(_f$endDate),
      category: data.dec(_f$category),
      userEmail: data.dec(_f$userEmail),
      userName: data.dec(_f$userName),
      userId: data.dec(_f$userId),
      createdAt: data.dec(_f$createdAt),
      modifiedAt: data.dec(_f$modifiedAt),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ContentSubmissionDto fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ContentSubmissionDto>(map);
  }

  static ContentSubmissionDto fromJson(String json) {
    return ensureInitialized().decodeJson<ContentSubmissionDto>(json);
  }
}

mixin ContentSubmissionDtoMappable {
  String toJson() {
    return ContentSubmissionDtoMapper.ensureInitialized()
        .encodeJson<ContentSubmissionDto>(this as ContentSubmissionDto);
  }

  Map<String, dynamic> toMap() {
    return ContentSubmissionDtoMapper.ensureInitialized()
        .encodeMap<ContentSubmissionDto>(this as ContentSubmissionDto);
  }

  @override
  String toString() {
    return ContentSubmissionDtoMapper.ensureInitialized().stringifyValue(
      this as ContentSubmissionDto,
    );
  }
}

