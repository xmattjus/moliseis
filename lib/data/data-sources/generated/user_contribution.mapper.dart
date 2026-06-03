// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of '../user_contribution.dart';

class UserContributionMapper extends ClassMapperBase<UserContribution> {
  UserContributionMapper._();

  static UserContributionMapper? _instance;
  static UserContributionMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = UserContributionMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'UserContribution';

  static int? _$id(UserContribution v) => v.id;
  static const Field<UserContribution, int> _f$id = Field(
    'id',
    _$id,
    opt: true,
  );
  static ContentCategory? _$type(UserContribution v) => v.type;
  static const Field<UserContribution, ContentCategory> _f$type = Field(
    'type',
    _$type,
    opt: true,
  );
  static String? _$city(UserContribution v) => v.city;
  static const Field<UserContribution, String> _f$city = Field(
    'city',
    _$city,
    opt: true,
  );
  static String? _$place(UserContribution v) => v.place;
  static const Field<UserContribution, String> _f$place = Field(
    'place',
    _$place,
    opt: true,
  );
  static String? _$description(UserContribution v) => v.description;
  static const Field<UserContribution, String> _f$description = Field(
    'description',
    _$description,
    opt: true,
  );
  static DateTime? _$startDate(UserContribution v) => v.startDate;
  static const Field<UserContribution, DateTime> _f$startDate = Field(
    'startDate',
    _$startDate,
    key: r'start_date',
    opt: true,
  );
  static DateTime? _$endDate(UserContribution v) => v.endDate;
  static const Field<UserContribution, DateTime> _f$endDate = Field(
    'endDate',
    _$endDate,
    key: r'end_date',
    opt: true,
  );
  static List<String>? _$media(UserContribution v) => v.media;
  static const Field<UserContribution, List<String>> _f$media = Field(
    'media',
    _$media,
    opt: true,
  );
  static String? _$authorEmail(UserContribution v) => v.authorEmail;
  static const Field<UserContribution, String> _f$authorEmail = Field(
    'authorEmail',
    _$authorEmail,
    key: r'author_email',
    opt: true,
  );
  static String? _$authorName(UserContribution v) => v.authorName;
  static const Field<UserContribution, String> _f$authorName = Field(
    'authorName',
    _$authorName,
    key: r'author_name',
    opt: true,
  );
  static DateTime? _$createdAt(UserContribution v) => v.createdAt;
  static const Field<UserContribution, DateTime> _f$createdAt = Field(
    'createdAt',
    _$createdAt,
    key: r'created_at',
    opt: true,
  );
  static DateTime? _$modifiedAt(UserContribution v) => v.modifiedAt;
  static const Field<UserContribution, DateTime> _f$modifiedAt = Field(
    'modifiedAt',
    _$modifiedAt,
    key: r'modified_at',
    opt: true,
  );

  @override
  final MappableFields<UserContribution> fields = const {
    #id: _f$id,
    #type: _f$type,
    #city: _f$city,
    #place: _f$place,
    #description: _f$description,
    #startDate: _f$startDate,
    #endDate: _f$endDate,
    #media: _f$media,
    #authorEmail: _f$authorEmail,
    #authorName: _f$authorName,
    #createdAt: _f$createdAt,
    #modifiedAt: _f$modifiedAt,
  };

  static UserContribution _instantiate(DecodingData data) {
    return UserContribution(
      id: data.dec(_f$id),
      type: data.dec(_f$type),
      city: data.dec(_f$city),
      place: data.dec(_f$place),
      description: data.dec(_f$description),
      startDate: data.dec(_f$startDate),
      endDate: data.dec(_f$endDate),
      media: data.dec(_f$media),
      authorEmail: data.dec(_f$authorEmail),
      authorName: data.dec(_f$authorName),
      createdAt: data.dec(_f$createdAt),
      modifiedAt: data.dec(_f$modifiedAt),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static UserContribution fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<UserContribution>(map);
  }

  static UserContribution fromJson(String json) {
    return ensureInitialized().decodeJson<UserContribution>(json);
  }
}

mixin UserContributionMappable {
  String toJson() {
    return UserContributionMapper.ensureInitialized()
        .encodeJson<UserContribution>(this as UserContribution);
  }

  Map<String, dynamic> toMap() {
    return UserContributionMapper.ensureInitialized()
        .encodeMap<UserContribution>(this as UserContribution);
  }

  UserContributionCopyWith<UserContribution, UserContribution, UserContribution>
  get copyWith =>
      _UserContributionCopyWithImpl<UserContribution, UserContribution>(
        this as UserContribution,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return UserContributionMapper.ensureInitialized().stringifyValue(
      this as UserContribution,
    );
  }

  @override
  bool operator ==(Object other) {
    return UserContributionMapper.ensureInitialized().equalsValue(
      this as UserContribution,
      other,
    );
  }

  @override
  int get hashCode {
    return UserContributionMapper.ensureInitialized().hashValue(
      this as UserContribution,
    );
  }
}

extension UserContributionValueCopy<$R, $Out>
    on ObjectCopyWith<$R, UserContribution, $Out> {
  UserContributionCopyWith<$R, UserContribution, $Out>
  get $asUserContribution =>
      $base.as((v, t, t2) => _UserContributionCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class UserContributionCopyWith<$R, $In extends UserContribution, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>>? get media;
  $R call({
    int? id,
    ContentCategory? type,
    String? city,
    String? place,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? media,
    String? authorEmail,
    String? authorName,
    DateTime? createdAt,
    DateTime? modifiedAt,
  });
  UserContributionCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _UserContributionCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, UserContribution, $Out>
    implements UserContributionCopyWith<$R, UserContribution, $Out> {
  _UserContributionCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<UserContribution> $mapper =
      UserContributionMapper.ensureInitialized();
  @override
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>>? get media =>
      $value.media != null
      ? ListCopyWith(
          $value.media!,
          (v, t) => ObjectCopyWith(v, $identity, t),
          (v) => call(media: v),
        )
      : null;
  @override
  $R call({
    Object? id = $none,
    Object? type = $none,
    Object? city = $none,
    Object? place = $none,
    Object? description = $none,
    Object? startDate = $none,
    Object? endDate = $none,
    Object? media = $none,
    Object? authorEmail = $none,
    Object? authorName = $none,
    Object? createdAt = $none,
    Object? modifiedAt = $none,
  }) => $apply(
    FieldCopyWithData({
      if (id != $none) #id: id,
      if (type != $none) #type: type,
      if (city != $none) #city: city,
      if (place != $none) #place: place,
      if (description != $none) #description: description,
      if (startDate != $none) #startDate: startDate,
      if (endDate != $none) #endDate: endDate,
      if (media != $none) #media: media,
      if (authorEmail != $none) #authorEmail: authorEmail,
      if (authorName != $none) #authorName: authorName,
      if (createdAt != $none) #createdAt: createdAt,
      if (modifiedAt != $none) #modifiedAt: modifiedAt,
    }),
  );
  @override
  UserContribution $make(CopyWithData data) => UserContribution(
    id: data.get(#id, or: $value.id),
    type: data.get(#type, or: $value.type),
    city: data.get(#city, or: $value.city),
    place: data.get(#place, or: $value.place),
    description: data.get(#description, or: $value.description),
    startDate: data.get(#startDate, or: $value.startDate),
    endDate: data.get(#endDate, or: $value.endDate),
    media: data.get(#media, or: $value.media),
    authorEmail: data.get(#authorEmail, or: $value.authorEmail),
    authorName: data.get(#authorName, or: $value.authorName),
    createdAt: data.get(#createdAt, or: $value.createdAt),
    modifiedAt: data.get(#modifiedAt, or: $value.modifiedAt),
  );

  @override
  UserContributionCopyWith<$R2, UserContribution, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _UserContributionCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

