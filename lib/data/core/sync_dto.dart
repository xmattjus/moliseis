abstract interface class SyncDto {
  int get id;
  DateTime get modifiedAt;
  DateTime? get deletedAt;
}
