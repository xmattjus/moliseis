abstract interface class SyncEntity {
  int get remoteId;
  DateTime get modifiedAt;
  bool get isDeleted;
}
