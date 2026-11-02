# Spec Delta

## Purpose

Retain an auditable copy of incoming OpenSky Avro events while producing validated aircraft observations that remain stable across retries and replay.

## ADDED Requirements

### Requirement: Durable raw archive
The Kafka-to-lake pipeline SHALL retain every consumed event's original Avro value and Kafka coordinates in a durable raw layer and SHALL avoid duplicating the same topic/partition/offset on replay.

#### Scenario: Retry after an incomplete microbatch
- **WHEN** an input batch is retried after raw was written but before later stages completed
- **THEN** the raw layer still contains one record per Kafka coordinate with the same Avro bytes and processing resumes without data loss

### Requirement: Typed validated silver observations
The pipeline SHALL decode the versioned Avro contract into typed records with one observation per response time and non-empty `icao24`, preserving nullable fields, trimming callsign, checking obvious coordinate/range errors, and recording rejected-row counts while leaving their source events in raw.

#### Scenario: Duplicate aircraft snapshot
- **WHEN** the same aircraft and response time appear again in a replay or later poll
- **THEN** silver contains one deterministic observation for that key

#### Scenario: Missing position and malformed row
- **WHEN** a state has null coordinates but a valid aircraft ID
- **THEN** silver retains it with null coordinates; when coordinates are out of range or the aircraft ID is empty, the row is excluded from silver and counted as rejected while raw remains available

#### Scenario: Unsupported schema version
- **WHEN** an event has an incompatible or unknown schema version
- **THEN** the pipeline reports the failure, retains the last successfully committed position for replay, and does not silently corrupt silver

### Requirement: Recoverable ordered processing
The pipeline SHALL persist checkpoints and commit raw before silver and silver before downstream gold, so that a failed batch can be replayed safely without advancing its source position before all required outputs succeed.

#### Scenario: Gold refresh failure
- **WHEN** raw and silver succeed but gold update fails
- **THEN** the batch is retried and the pre-existing raw and silver results remain correct rather than producing duplicates
