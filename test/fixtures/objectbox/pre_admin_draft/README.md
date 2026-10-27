# Populated store before Admin local foundations

`data.mdb.gz` was produced and closed using the unchanged generated ObjectBox
schema at commit `05855326266e6e54763bbfd804ef8d4fbc83e7f0`.
`objectbox-model.json` is the producer's exact generated model. The producer
used the existing real `TestObjectBoxEnvironment`, then compressed the closed
store. It was removed after capture so current bindings cannot reseed this
historical fixture.

Rows intentionally cover the existing persistence boundaries:

- Settings singleton: crash reporting false; content sync cursor
  `2026-10-20T00:00:00Z`; last sync `2026-10-21T00:00:00Z`.
- City remote 71 (`Fixture city`), related Event 72 (`Fixture event`, all-day),
  and related Place 73 (`Fixture place`).
- Public draft 1: UUID `1fdbfe1e-a1b2-4b23-9b42-111111111111`, name
  `Fixture public draft`, all-day.
- Public staged descriptor: that UUID, forty `a` digest, canonical relative path.

The repeatable upgrade regression decompresses a copy into a fresh temporary
store, opens it with current bindings, verifies these rows and relationships,
and then exercises the additive Admin entities. The descriptor is intentionally
not reconciled against a filesystem: this fixture verifies schema/data survival.
