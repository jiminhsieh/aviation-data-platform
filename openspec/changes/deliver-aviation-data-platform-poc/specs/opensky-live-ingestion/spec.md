# Spec Delta

## Purpose

Automatically collect authenticated OpenSky state-vector snapshots for the prescribed region and preserve replayable, source-shaped Avro responses directly in durable Bronze storage.

## ADDED Requirements

### Requirement: Authenticated budgeted polling
The collector SHALL obtain an OAuth2 client-credentials bearer token and request `GET /api/states/all` with exactly `lamin=-11`, `lamax=21`, `lomin=92`, `lomax=141` every two minutes in UTC without overlapping runs. Normal operation SHALL make one states request per run: 720 requests/day at four credits each, or 2,880 credits against the documented 4,000-credit allowance. All application retries, pod retries, manual validation and live environments sharing that allowance SHALL share the remaining 1,120 credits (at most 280 additional states requests/day).

#### Scenario: Scheduled successful poll
- **WHEN** a scheduled run receives a valid OpenSky response
- **THEN** it uses the fixed bounding box and bearer authentication and archives the response without manual intervention or triggering a Databricks job

#### Scenario: Throttling or temporary outage
- **WHEN** OpenSky returns `429`, a server error or a timeout
- **THEN** retries are bounded by the shared quota and run deadline, `429` handling respects `X-Rate-Limit-Retry-After-Seconds`, and an unsuccessful run produces a redacted diagnostic and nonzero exit rather than fabricated success

#### Scenario: Multiple live environments
- **WHEN** an operator considers enabling multiple collectors against one registered allowance
- **THEN** the runbook budgets all requests/retries together and warns that three two-minute collectors consume 8,640 credits/day before retries and cannot run at that cadence within the shared 4,000-credit budget

### Requirement: Source-shaped Bronze Avro
The collector SHALL encode each valid response as one Snappy-compressed Avro object container containing one record with exactly `time` (the original Unix-seconds timestamp) and `states` (null or the original array of 17-position aircraft arrays). It SHALL preserve source values/types, nulls, padded strings and nested sensors without named aircraft records, lossy coercion or added payload fields such as schema version, hash or fetch time. Per-position field counts/types SHALL be validated, not merely accepted by a permissive union schema. Decoding SHALL reproduce the original structure and values, not the exact JSON bytes.

#### Scenario: Mixed and nullable state-vector fields
- **WHEN** a valid response includes numeric/boolean values, padded callsigns, optional nulls and nested sensors
- **THEN** decoding its single Avro record reproduces all 17 positional values/types and only the two original top-level fields

#### Scenario: Empty source snapshot
- **WHEN** a valid response has `states: null` or `states: []`
- **THEN** it is durably archived as a successful zero-aircraft snapshot without inventing observations

#### Scenario: Invalid source response
- **WHEN** the timestamp, payload structure, field count or positional types violate the contract
- **THEN** the original response is retained in restricted quarantine, the run fails visibly and no partial or coerced canonical Bronze object is published

### Requirement: Immutable source-time publication
Canonical Bronze SHALL use `opensky/states/year=YYYY/month=MM/day=DD/hour=HH/<response.time>.avro`, deriving every directory key from source `time` in UTC, not upload time or aircraft contact time. Publication SHALL atomically create the complete object only if absent, never overwrite a canonical object or expose a partial final object, and report success only after durable publication or verification of identical existing decoded content.

#### Scenario: Retry or late arrival across an hour boundary
- **WHEN** a snapshot is uploaded after its source hour has ended
- **THEN** it retains its source-hour path; timestamp `1793013825` maps to `opensky/states/year=2026/month=10/day=26/hour=11/1793013825.avro`

#### Scenario: Identical snapshot already exists
- **WHEN** a conditional upload finds the canonical timestamp path already present
- **THEN** decoded `time`/`states` equality gives idempotent success without another canonical file or reliance on binary Avro-byte equality

#### Scenario: Conflicting snapshot already exists
- **WHEN** the existing canonical path has different decoded content for the same timestamp
- **THEN** the canonical object is preserved, the conflicting original is archived under a unique restricted quarantine path outside normal Bronze discovery, and the run alerts and fails

### Requirement: Visible archival outcomes
Authentication, secret retrieval, Bronze read/upload or quarantine failures SHALL produce a nonzero exit. Structured diagnostics SHALL expose source/fetch times, archive outcome/path, durations, aircraft count and remaining credits when available, without credentials, tokens or extra Bronze metadata. Repeated source timestamps SHALL remain visible separately from request success.

#### Scenario: Storage or quarantine is unavailable
- **WHEN** the collector cannot complete required publication, collision verification or quarantine archival
- **THEN** it does not report the response as successfully archived and emits a redacted failure for operator recovery

#### Scenario: Source repeatedly returns an old snapshot
- **WHEN** successful API calls keep returning identical content with an old timestamp
- **THEN** canonical publication remains idempotent while source-age monitoring identifies stale data rather than treating request success as fresh observations
