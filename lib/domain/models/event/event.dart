import 'package:json_annotation/json_annotation.dart';
import 'package:objectbox/objectbox.dart';

part 'event.g.dart';

@Entity()
@JsonSerializable()
class Event {
  const Event({
    required this.id,
    this.title,
    this.description,
    this.startDate,
    this.endDate,
    this.createdAt,
    this.modifiedAt,
  });

  @Id(assignable: true)
  final int id;

  final String? title;

  final String? description;

  @JsonKey(name: 'start_date')
  @Property(type: PropertyType.dateNano)
  final DateTime? startDate;

  @JsonKey(name: 'end_date')
  @Property(type: PropertyType.dateNano)
  final DateTime? endDate;

  @JsonKey(name: 'created_at')
  @Property(type: PropertyType.dateNano)
  final DateTime? createdAt;

  @JsonKey(name: 'modified_at')
  @Property(type: PropertyType.dateNano)
  final DateTime? modifiedAt;

  @override
  bool operator ==(Object other) =>
      other is Event &&
      other.id == id &&
      other.title == title &&
      other.description == description &&
      _bothNullOrSameMoment(startDate, other.startDate) &&
      _bothNullOrSameMoment(endDate, other.endDate) &&
      _bothNullOrSameMoment(createdAt, other.createdAt) &&
      _bothNullOrSameMoment(modifiedAt, other.modifiedAt);

  @override
  int get hashCode => Object.hash(
    id,
    title,
    description,
    startDate,
    endDate,
    createdAt,
    modifiedAt,
  );

  Event copyWith({
    // required int id,
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    // DateTime? createdAt,
    DateTime? modifiedAt,
  }) => Event(
    id: id,
    title: title ?? this.title,
    description: description ?? this.description,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    createdAt: createdAt,
    modifiedAt: modifiedAt ?? this.modifiedAt,
  );

  factory Event.fromJson(Map<String, dynamic> json) => _$EventFromJson(json);

  Map<String, dynamic> toJson() => _$EventToJson(this);

  /// Whether both [dt] and [other] are null or occur at the same moment.
  bool _bothNullOrSameMoment(DateTime? dt, DateTime? other) {
    if (dt == null && other == null) {
      return true;
    }

    if (dt != null && other != null && dt.isAtSameMomentAs(other)) {
      return true;
    }

    return false;
  }
}
