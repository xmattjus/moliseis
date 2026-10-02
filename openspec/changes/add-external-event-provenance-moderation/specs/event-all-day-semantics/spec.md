## MODIFIED Requirements

### Requirement: Import adapters own source interpretation
An import adapter SHALL explicitly decide whether a source provides a meaningful start time; the interpreted source values SHALL cross the shared normalization contract owned by `event-temporal-input-validity`. Existing EventiMolise imports SHALL remain timed and retain their existing end parsing. Source ingestion SHALL use provider-scoped strong identity as defined by external-event-provenance-moderation; Rome-day/title/city similarity SHALL remain advisory candidate evidence only and SHALL NOT suppress provenance persistence. The prepared/import persistence contract SHALL support date-only single-day, timed single-day, date-only multi-day, and timed-start/final-date-only events without another schema, domain, cache, or display change. No new live provider is required. Multiple provider identities MAY link through moderation to one canonical Event without changing temporal interpretation.

#### Scenario: Current EventiMolise input stays timed
- **WHEN** a currently supported EventiMolise source row is prepared and persisted
- **THEN** its mode is explicitly false, its time interpretation and end handling remain unchanged, and repeated appearances converge through strong source identity; the Rome start day remains available for advisory moderation matching

#### Scenario: Date-only adapter fixture uses the existing pipeline
- **WHEN** a test adapter supplies a single civil date or an initial/final civil-date pair without a meaningful start time
- **THEN** the adapter selects true and the existing prepared/import contract carries the resulting date-only event without a new provider framework

#### Scenario: Timed adapter fixture has a final date without time
- **WHEN** a test adapter supplies a meaningful start time and only a final civil date
- **THEN** the adapter selects false and retains the known start-time meaning under the mixed-precision contract
