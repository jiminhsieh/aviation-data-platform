# Spec Delta

## Purpose

Turn immutable source-shaped Bronze Avro snapshots into typed, validated Silver observations through deterministic complete-hour replacement and recoverable file progress independently of Gold.

## ADDED Requirements

### Requirement: Checkpointed canonical file processing
The pipeline SHALL discover canonical Avro files recursively under a stable Bronze source root using an explicit compatible schema and a dedicated durable checkpoint outside source/table storage. It SHALL decode the actual positional Avro-union representation, preserve file provenance and fail visibly on malformed or incompatible canonical files rather than silently skipping them. Ingestion, not this pipeline, owns the durable Bronze archive.

#### Scenario: New source-hour directory
- **WHEN** a valid file arrives in a newly created UTC-hour directory under the watched root
- **THEN** it is eligible for discovery without changing the source root or checkpoint and source `time` determines its processing hour

#### Scenario: Incompatible canonical input
- **WHEN** a discovered file has malformed Avro, unexpected length/type or an invalid source timestamp
- **THEN** processing fails visibly without successful checkpoint acknowledgement or silent data exclusion and preserves the original Bronze evidence

### Requirement: Typed validated Silver observations
Silver SHALL retain one observation per `(snapshot_time, icao24)`, where `snapshot_time` is the top-level source `time`, with named typed source fields, explicit measurement units, Bronze-file provenance and nullable optional values. Callsigns SHALL be trimmed only in Silver; null/blank countries SHALL remain unchanged until Gold. Invalid aircraft identifiers (not six hexadecimal characters) or out-of-range coordinates SHALL be rejected and counted with file/row provenance in restricted diagnostics; failure to record required accounting SHALL fail the batch.

#### Scenario: Missing optional measurements
- **WHEN** a state has a valid aircraft identifier and null coordinates, altitude or callsign
- **THEN** Silver preserves the observation and genuine nulls without invented measurements or a premature `Unknown` country label

#### Scenario: Invalid identifier or coordinates
- **WHEN** an observation has an invalid identifier or longitude/latitude outside their valid ranges
- **THEN** it is excluded from Silver, rejection count/reason/provenance are recorded, and its original remains in immutable Bronze

#### Scenario: Duplicate aircraft snapshot
- **WHEN** multiple observations have the same `(snapshot_time, icao24)` within a complete rebuilt hour
- **THEN** one deterministic survivor is selected by greatest `last_contact`, then `time_position`, then stable normalized observation-content hash, with null ordering defined consistently

### Requirement: Source-time hourly partition contract
Silver SHALL use `snapshot_time` as Unix-seconds BIGINT and UTC TIMESTAMP values for `snapshot_at_utc`, `snapshot_hour_utc` and five-minute `bucket_start_utc`. Hour and bucket values SHALL derive from `floor(snapshot_time / 3600) * 3600` and `floor(snapshot_time / 300) * 300` respectively before timestamp conversion. The table SHALL be physically partitioned by the full-date `snapshot_hour_utc`.

#### Scenario: Source crosses a UTC day boundary
- **WHEN** observations cross a UTC hour/day/month boundary or are uploaded late
- **THEN** each timestamp, hour partition and five-minute bucket follows source time, independently of upload time or session-local timezone

### Requirement: Atomic complete-hour replacement
Each processing batch SHALL identify affected UTC hours before expanding aircraft arrays, reread all present canonical Bronze files for those hours, verify that each discovered input remains readable and validate source/path agreement, normalize/validate/deduplicate the hour inputs and atomically replace only the affected Silver hours in one commit. The replacement SHALL preserve the table/schema/grants, enforce the explicit hour scope and keep unrelated hours unchanged. It SHALL never use only the newly discovered snapshots as a complete-hour replacement.

#### Scenario: Second snapshot in an existing hour
- **WHEN** a new snapshot arrives in an hour already represented in Silver
- **THEN** the full Bronze hour is reread and the replacement preserves earlier snapshots while adding the new business observations without duplicate keys

#### Scenario: Batch spans multiple hours
- **WHEN** newly discovered files include current and late historical hours
- **THEN** all affected hours are rebuilt from their present canonical inputs and replaced atomically while unrelated partitions remain unchanged

#### Scenario: Empty input or zero-observation hour
- **WHEN** a batch has no affected hours
- **THEN** it makes no Silver write; an affected hour whose validated rebuild from present canonical inputs has zero surviving observations instead receives an explicit schema-correct empty replacement that clears only that hour

#### Scenario: Unreadable or inconsistent source hour
- **WHEN** an affected hour is outside the retained rebuild horizon, a discovered file is no longer readable, or a present canonical file is malformed or inconsistent with its source-time path
- **THEN** processing stops before replacement rather than interpreting that failure as zero aircraft

### Requirement: Recoverable independent Silver progress
The pipeline SHALL rely on operational retention of immutable canonical Bronze for the retained Silver/rebuild horizon; it SHALL NOT merge old Silver rows into a rebuilt hour. Without an authoritative file inventory, scanning Bronze cannot detect an earlier file that is already absent: loss or incomplete restoration is an accepted PoC risk, not a verified complete-hour guarantee. The pipeline SHALL serialize stream/backfill writers and acknowledge source progress only after successful Silver processing and required accounting, independently of Gold. Ordinary restarts SHALL preserve the checkpoint. Controlled bounded replay SHALL pause the normal writer, expand selected paths to full UTC hours, check selected files and all present canonical inputs for readability and path agreement, reuse the same transformation/replacement, validate results, refresh Gold independently and resume the original stream. Suspected loss requires independent source/backup investigation before replay; lost/incompatible checkpoints and file-age/discovery bounds require explicit recovery rather than automatic reset.

#### Scenario: Failure after Silver commit
- **WHEN** Silver commits but the callback or checkpoint acknowledgement fails
- **THEN** replay rebuilds the complete hours without duplicate business keys; unchanged Bronze/rules preserve business rows while processing audit timestamps can change

#### Scenario: Gold refresh failure
- **WHEN** the independently scheduled Gold task fails
- **THEN** Silver continues processing and committing its own checkpoint and no Silver retry depends on Gold success

#### Scenario: Historical file excluded by discovery bounds
- **WHEN** an old restored file is not eligible for ordinary streaming discovery
- **THEN** an operator can perform the documented complete-hour replay without concurrent Silver writers, altering canonical files or casually deleting the normal checkpoint

#### Scenario: Valid empty snapshot
- **WHEN** a null/empty `states` snapshot is processed successfully
- **THEN** its hour participates in the full-hour rebuild and source-processing freshness is recorded operationally without fabricated Silver rows or added Bronze fields
