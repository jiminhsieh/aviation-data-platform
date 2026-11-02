# Spec Delta

## Purpose

Automatically collect registered-account live OpenSky state-vector polls for the prescribed region and publish replayable, schema-defined events to the platform.

## ADDED Requirements

### Requirement: Authenticated budgeted polling
The collector SHALL acquire a client-credentials bearer token, poll the fixed OpenSky bounding box (`lamin=-11`, `lamax=21`, `lomin=92`, `lomax=141`) on a two-minute schedule without overlapping runs, and avoid exceeding the documented registered-account daily credit allowance under normal operation.

#### Scenario: Scheduled successful poll
- **WHEN** the next scheduled run starts and OpenSky returns a successful states response
- **THEN** it requests exactly the fixed bounding box, authenticates with a bearer token, and publishes that poll to the stream without manual intervention

#### Scenario: Throttling or temporary outage
- **WHEN** OpenSky returns `429`, a server error, or a request timeout
- **THEN** the run records a non-secret diagnostic and bounds retries or skips that run rather than flooding the API or emitting a fabricated success event

### Requirement: Versioned replayable poll event
The collector SHALL encode each valid response as a schema-versioned Avro poll event retaining the response time and all supported aircraft state fields, and publish only after broker acknowledgement; it SHALL not log tokens or raw credentials.

#### Scenario: Nullable state-vector fields
- **WHEN** a valid poll includes the documented 17-position state vector with null optional fields
- **THEN** the emitted event retains the time, all state values and nulls in their declared types for downstream decoding

#### Scenario: Invalid response
- **WHEN** a response has a missing poll time or a state vector incompatible with the published contract
- **THEN** the collector fails that poll visibly and does not publish a partially converted poll
