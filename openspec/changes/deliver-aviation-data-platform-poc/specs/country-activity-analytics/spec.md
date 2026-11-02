# Spec Delta

## Purpose

Give data scientists a self-service SQL table of recent aircraft activity by OpenSky origin country, with explicit measures and minute-scale freshness.

## ADDED Requirements

### Requirement: Hourly country activity table
Gold SHALL aggregate silver observations by UTC hour of response time and `origin_country`, with a distinct `icao24` aircraft count and average non-null `geo_altitude` over observations; it SHALL preserve at least the last 24 hours of results and document that origin country is not the aircraft's current location.

#### Scenario: Different observations for the same aircraft
- **WHEN** an aircraft has multiple silver observations in the same hour
- **THEN** its country/hour aircraft count increases by one and each non-null altitude observation contributes to the average

#### Scenario: All altitudes missing
- **WHEN** all observations in a country/hour have null `geo_altitude`
- **THEN** the aircraft count is still correct and the average altitude is null rather than zero

#### Scenario: Replayed or late observation
- **WHEN** a previously seen silver key is replayed or a previously unseen observation arrives for an older hour
- **THEN** the affected hour/country result is recomputed from silver without double counting or erasing other hours

### Requirement: Fresh self-service querying
The gold table SHALL be accessible by SQL to an authorized data scientist without an engineer running a query; successful normal-operation polls containing valid observations SHALL be reflected in gold within five minutes of collection, and the runbook SHALL show how to inspect both poll and gold freshness.

#### Scenario: Data scientist queries the last day
- **WHEN** a data scientist runs the documented last-24-hours query with read/query access
- **THEN** hourly counts and average altitude by origin country are returned from gold without pipeline write privileges

#### Scenario: Pipeline stalls
- **WHEN** no new successful poll has reached gold within the documented freshness target
- **THEN** operators can distinguish a stalled pipeline from an empty/unchanged feed by comparing the latest raw response time, latest gold response time, and pipeline/job status
