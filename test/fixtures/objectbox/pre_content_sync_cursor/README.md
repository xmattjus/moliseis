# Previous ObjectBox content-sync cache

`data.mdb.gz` is a real closed ObjectBox store written with unchanged bindings at
producer HEAD `58efee0f36c1f1051f49e7c58b0f4d8ef1f79de9`, before adding
`AppSettings.contentSyncCursorAt`. The temporary producer used the shared
`TestObjectBoxEnvironment` and entity factories, closed the store, asserted
`Store.isClosed()`, then compressed `data.mdb` and copied the unchanged model.

Producer gate: `flutter test test/data/content_sync_previous_store_capture_test.dart`
passed (one test). The producer was removed after capture; the ordinary suite must
never recreate this fixture with the new model.

Producer model SHA-256:
`32301ed8101b89ef4ebcaa547afbb44307e10591ed741a333b80ea6843fd0470`.
`objectbox-model.json` is the exact producer model. Its AppSettings entity UID is
`6:8898619296747710534`; its last property is lastSyncedAt
`10:398867547277998639`. All model UIDs are preserved in this copy.

Expected rows:

- Settings ID 1: theme `app`, brightness `dark`, sort `byDate`, crash reporting
  false, lastSyncedAt `2026-10-12T08:30:00Z`. The producer has no cursor property.
- City 101: `Previous city`.
- Event 102: `Previous event`, city 101, saved true, allDay true, start
  `2026-10-15T00:00:00Z`, raw description Delta containing
  `Previous event description\n`.
- Place 103: `Previous place`, city 101, saved true.
- Media 104: `Previous media`, event 102, URL `https://cdn.example.com/img.jpg`,
  width 800, height 600.
- All four canonical rows: createdAt `2026-10-01T10:00:00Z`, modifiedAt
  `2026-10-02T11:00:00Z`, isDeleted false.

The reopen regression decompresses a copy into a fresh temporary directory and
opens it with current bindings. Existing values/relations/identities must remain,
`contentSyncCursorAt` must be null, and subsequently stored cursor/completion
values must survive a second reopen. Preserve the independent `pre_all_day`
fixture and its regression test.
