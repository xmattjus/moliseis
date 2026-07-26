// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of '../submission_asset_dto.dart';

class SubmissionAssetDtoMapper extends ClassMapperBase<SubmissionAssetDto> {
  SubmissionAssetDtoMapper._();

  static SubmissionAssetDtoMapper? _instance;
  static SubmissionAssetDtoMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = SubmissionAssetDtoMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'SubmissionAssetDto';

  static String _$url(SubmissionAssetDto v) => v.url;
  static const Field<SubmissionAssetDto, String> _f$url = Field('url', _$url);
  static int _$width(SubmissionAssetDto v) => v.width;
  static const Field<SubmissionAssetDto, int> _f$width = Field(
    'width',
    _$width,
  );
  static int _$height(SubmissionAssetDto v) => v.height;
  static const Field<SubmissionAssetDto, int> _f$height = Field(
    'height',
    _$height,
  );
  static String? _$mimeType(SubmissionAssetDto v) => v.mimeType;
  static const Field<SubmissionAssetDto, String> _f$mimeType = Field(
    'mimeType',
    _$mimeType,
    key: r'mime_type',
    opt: true,
  );
  static int? _$durationSeconds(SubmissionAssetDto v) => v.durationSeconds;
  static const Field<SubmissionAssetDto, int> _f$durationSeconds = Field(
    'durationSeconds',
    _$durationSeconds,
    key: r'duration_seconds',
    opt: true,
  );

  @override
  final MappableFields<SubmissionAssetDto> fields = const {
    #url: _f$url,
    #width: _f$width,
    #height: _f$height,
    #mimeType: _f$mimeType,
    #durationSeconds: _f$durationSeconds,
  };

  static SubmissionAssetDto _instantiate(DecodingData data) {
    return SubmissionAssetDto(
      url: data.dec(_f$url),
      width: data.dec(_f$width),
      height: data.dec(_f$height),
      mimeType: data.dec(_f$mimeType),
      durationSeconds: data.dec(_f$durationSeconds),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static SubmissionAssetDto fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<SubmissionAssetDto>(map);
  }

  static SubmissionAssetDto fromJson(String json) {
    return ensureInitialized().decodeJson<SubmissionAssetDto>(json);
  }
}

mixin SubmissionAssetDtoMappable {
  String toJson() {
    return SubmissionAssetDtoMapper.ensureInitialized()
        .encodeJson<SubmissionAssetDto>(this as SubmissionAssetDto);
  }

  Map<String, dynamic> toMap() {
    return SubmissionAssetDtoMapper.ensureInitialized()
        .encodeMap<SubmissionAssetDto>(this as SubmissionAssetDto);
  }

  @override
  String toString() {
    return SubmissionAssetDtoMapper.ensureInitialized().stringifyValue(
      this as SubmissionAssetDto,
    );
  }
}

