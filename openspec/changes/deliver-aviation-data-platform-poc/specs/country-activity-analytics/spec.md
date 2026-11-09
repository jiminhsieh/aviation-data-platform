# Spec Delta

## Purpose

Give authorized analysts self-service SQL access to five-minute country activity and per-aircraft barometric-altitude metrics with explicit history, freshness and recovery semantics.

## ADDED Requirements

### Requirement: Five-minute country activity table
Gold SHALL expose `aviation.gold.aircraft_activity_5m` grouped by source-time five-minute UTC `bucket_start_utc` and `origin_country`, physically partitioned by UTC TIMESTAMP `bucket_hour_utc`, the full hour containing the bucket. Each `(bucket, icao24)` SHALL count once, attributed to its latest Silver observation's country. Null/blank countries SHALL become `Unknown` only in Gold. Documentation SHALL explain that country is a registration-country proxy, not current geographic location, operator country or flight origin.

#### Scenario: Repeated observations and country change
- **WHEN** an aircraft has several observations within a bucket, including a later country change
- **THEN** it contributes exactly one aircraft to the latest observation's normalized country and does not remain counted in its earlier country

#### Scenario: UTC boundary
- **WHEN** a bucket crosses into another UTC hour/day/month relative to previous observations
- **THEN** its full-date `bucket_hour_utc` matches the hour of `bucket_start_utc`, independently of refresh time

### Requirement: Per-aircraft within-bucket barometric altitude
Gold SHALL calculate `avg_baro_altitude_m` from each counted aircraft's latest non-null `baro_altitude_m` within the same bucket, never across buckets. It SHALL expose `aircraft_count`, `altitude_sample_count`, `last_source_time` (the latest selected source timestamp in the group) and `updated_at_utc` (refresh time). Missing altitudes SHALL be excluded from the mean, not treated as zero.

#### Scenario: Latest altitude is null
- **WHEN** an aircraft's latest observation has null barometric altitude but an earlier observation in the same bucket has a value
- **THEN** the latest non-null within-bucket value contributes once to the latest observation's country group

#### Scenario: Unequal observation counts
- **WHEN** two aircraft have different numbers of observations in one bucket
- **THEN** each aircraft contributes at most one altitude sample so frequent observations do not receive extra weight

#### Scenario: All altitudes missing
- **WHEN** no counted aircraft has a non-null barometric altitude within the bucket
- **THEN** the aircraft count remains correct, `altitude_sample_count` is zero and `avg_baro_altitude_m` is null without carrying a value from a prior bucket

### Requirement: Independent atomic SQL refresh
Gold SHALL refresh through an independently scheduled SQL-file task, initially every two minutes in UTC on a Pro or Serverless SQL warehouse with one active writer. Each refresh SHALL derive all Gold from a consistent snapshot of all retained Silver and atomically replace the existing table's complete data across all hourly partitions, preserving its schema/catalog object/grants. It SHALL not rely on stream-checkpoint progress, additive counters, upsert-only groups, dynamic partition overwrite or separately committed delete/insert operations.

#### Scenario: Retry or late historical observation
- **WHEN** a refresh repeats or Silver receives an observation for an older hour
- **THEN** a full refresh converges to the correct retained business aggregates without double counting; `updated_at_utc` can change on retry

#### Scenario: Obsolete country group or hour
- **WHEN** a group or entire hour is absent from the current Silver derivation
- **THEN** it is removed from Gold instead of surviving as stale data in an untouched partition

#### Scenario: Silver is genuinely empty
- **WHEN** a successful full refresh reads a genuinely empty Silver table
- **THEN** Gold becomes empty across all partitions in the same atomic operation

#### Scenario: SQL task fails
- **WHEN** a refresh cannot complete
- **THEN** readers retain the previous committed Gold, Silver continues independently, and an alerted SQL retry recomputes Gold from current Silver

### Requirement: Recent self-service history
Gold SHALL retain at least the trailing 24 hours after collection warm-up, initially planning approximately 30 days of retained history. An authorized analyst SHALL be able to run the documented rolling-24-hour SQL query without an engineer, write privileges or storage keys. The query SHALL combine hourly partition pruning with the exact five-minute bucket cutoff rather than treating 24 partitions as an exact 24-hour window.

#### Scenario: Analyst queries the last day
- **WHEN** an authorized data scientist runs the documented query after warm-up
- **THEN** it returns five-minute counts and altitude/sample metrics by country over the rolling last 24 hours, potentially spanning 25 hourly partitions

#### Scenario: Demonstration before warm-up
- **WHEN** less than 24 hours of real source history has been collected
- **THEN** the available history is stated honestly and any 24-hour test fixture is explicitly labeled rather than presented as live collection

### Requirement: Measured freshness and empty-source-aware health
The platform SHALL target measured p95 source-snapshot-to-queryable-Gold freshness below five minutes under normal operation, not guarantee each poll's latency from its schedule. Operational evidence SHALL separately expose source/request age, Bronze archival, stream progress, Silver commits, SQL refresh success and Gold freshness, including successfully processed zero-aircraft snapshots.

#### Scenario: Measure live latency
- **WHEN** operators run at least one hour of live acceptance telemetry
- **THEN** they report p50/p95/max landing, Silver and Gold lags and actual compute uptime, including scheduling/startup effects rather than inferring latency from configured intervals

#### Scenario: No aircraft or stale source
- **WHEN** Gold's maximum represented source time stops advancing
- **THEN** operators can distinguish valid empty snapshots, repeated stale source timestamps, a stalled stream and a failed/delayed SQL task without equating checkpoint advancement or request success with fresh Gold
