# Previous ObjectBox cache

`data.mdb.gz` was written and closed by the unchanged generated ObjectBox model
at commit `d7f747782b7ab924111b96f906599c28917c64d6`, before allDay inputs or generated
bindings were changed. The producer used `TestObjectBoxEnvironment` and real
ObjectBox boxes; gzip only compresses the resulting database file.

Fixture rows:
- Event 71: start 2026-10-11T22:00:00Z, no end, `isSaved=true`.
- Supported draft 1: identity `1fdbfe1e-a1b2-4b23-9b42-111111111111`, event enabled,
  start 2026-10-11T16:00:00Z, end 2026-10-14T21:59:59.999999Z.

`objectbox-model.json` is an exact copy of the producer's generated model.
The reopen regression must copy/decompress the fixture into a fresh temporary
directory and open it with current bindings; it must never overwrite this cache
by seeding it with the current model.

Producer verification: `flutter test test/data/all_day_previous_store_capture_test.dart`
passed against the unchanged model. The temporary producer was removed after
capture so running the current suite cannot replace previous-model evidence.

Previous model SHA-256: 4b6b25b9df2dffb96d240f5e85243ce1d5ef501a8052105f7f442a988b35a8ca
