# OpenSky REST API

> Offline copy of the official [OpenSky REST API documentation](https://openskynetwork.github.io/opensky-api/rest.html), version 1.4.0. Retrieved 2026-11-03.
>
> The source page remains authoritative; refresh this file when the upstream API changes.

The root URL of our REST API is:

    https://opensky-network.org/api

There are several functions available to retrieve state vectors, flights and tracks for the whole network, a particular sensor, or a particular aircraft. Note that the functions to retrieve state vectors of sensors other than your own are rate limited (see limitations).

> [!NOTE]
> Routes, ADS-C and MLAT data are currently not available through the REST API. State vectors therefore do not contain MLAT positions (`position_source` 2). ADS-C and MLAT state vectors are available through Trino in the tables `readsb_adsc_sv` and `readsb_mlat_sv`.

## All State Vectors

The following API call can be used to retrieve any state vector of the OpenSky. Please note that rate limits apply for this call (see limitations). For API calls without rate limitation, see own-states.

### Operation

`GET /states/all`

### Request

You can (optionally) request state vectors for particular airplanes or times using the following request parameters:

| Property | Type | Description |
|----|----|----|
| *time* | integer | The time in seconds since epoch (Unix time stamp to retrieve states for. Current time will be used if omitted. |
| *icao24* | string | One or more ICAO24 transponder addresses represented by a hex string (e.g. `abc9f3`). To filter multiple ICAO24 append the property once for each address. If omitted, the state vectors of all aircraft are returned. |

In addition to that, it is possible to query a certain area defined by a bounding box of WGS84 coordinates. For this purpose, add all of the following parameters:

| Property | Type  | Description                                      |
|----------|-------|--------------------------------------------------|
| *lamin*  | float | lower bound for the latitude in decimal degrees  |
| *lomin*  | float | lower bound for the longitude in decimal degrees |
| *lamax*  | float | upper bound for the latitude in decimal degrees  |
| *lomax*  | float | upper bound for the longitude in decimal degrees |

Lastly, you can request the category of aircraft by adding the following request parameter:

| Property   | Type    | Description          |
|------------|---------|----------------------|
| *extended* | integer | Set to 1 if required |

Example query with time and aircraft: `https://opensky-network.org/api/states/all?time=1458564121&icao24=3c6444`

Example query with bounding box covering Switzerland: `https://opensky-network.org/api/states/all?lamin=45.8389&lomin=5.9962&lamax=47.8229&lomax=10.5226`

### Response

The response is a JSON object with the following properties

| Property | Type | Description |
|----|----|----|
| *time* | integer | The time which the state vectors in this response are associated with. All vectors represent the state of a vehicle with the interval ([time - 1, time]).  |
| *states* | array | The state vectors. |

The *states* property is a two-dimensional array. Each row represents a state vector and contains the following fields:

<table style="width:98%;">
<colgroup>
<col style="width: 7%" />
<col style="width: 18%" />
<col style="width: 9%" />
<col style="width: 62%" />
</colgroup>
<thead>
<tr>
<th><p>Index</p></th>
<th><p>Property</p></th>
<th><p>Type</p></th>
<th><p>Description</p></th>
</tr>
</thead>
<tbody>
<tr>
<td><p>0</p></td>
<td><p><em>icao24</em></p></td>
<td><p>string</p></td>
<td><p>Unique ICAO 24-bit address of the transponder in hex string representation.</p></td>
</tr>
<tr>
<td><p>1</p></td>
<td><p><em>callsign</em></p></td>
<td><p>string</p></td>
<td><p>Callsign of the vehicle (8 chars). Can be null if no callsign has been received.</p></td>
</tr>
<tr>
<td><p>2</p></td>
<td><p><em>origin_country</em></p></td>
<td><p>string</p></td>
<td><p>Country name inferred from the ICAO 24-bit address.</p></td>
</tr>
<tr>
<td><p>3</p></td>
<td><p><em>time_position</em></p></td>
<td><p>int</p></td>
<td><p>Unix timestamp (seconds) for the last position update. Can be null if no position report was received by OpenSky within the past 15s.</p></td>
</tr>
<tr>
<td><p>4</p></td>
<td><p><em>last_contact</em></p></td>
<td><p>int</p></td>
<td><p>Unix timestamp (seconds) for the last update in general. This field is updated for any new, valid message received from the transponder.</p></td>
</tr>
<tr>
<td><p>5</p></td>
<td><p><em>longitude</em></p></td>
<td><p>float</p></td>
<td><p>WGS-84 longitude in decimal degrees. Can be null.</p></td>
</tr>
<tr>
<td><p>6</p></td>
<td><p><em>latitude</em></p></td>
<td><p>float</p></td>
<td><p>WGS-84 latitude in decimal degrees. Can be null.</p></td>
</tr>
<tr>
<td><p>7</p></td>
<td><p><em>baro_altitude</em></p></td>
<td><p>float</p></td>
<td><p>Barometric altitude in meters. Can be null.</p></td>
</tr>
<tr>
<td><p>8</p></td>
<td><p><em>on_ground</em></p></td>
<td><p>boolean</p></td>
<td><p>Boolean value which indicates if the position was retrieved from a surface position report.</p></td>
</tr>
<tr>
<td><p>9</p></td>
<td><p><em>velocity</em></p></td>
<td><p>float</p></td>
<td><p>Velocity over ground in m/s. Can be null.</p></td>
</tr>
<tr>
<td><p>10</p></td>
<td><p><em>true_track</em></p></td>
<td><p>float</p></td>
<td><p>True track in decimal degrees clockwise from north (north=0°). Can be null.</p></td>
</tr>
<tr>
<td><p>11</p></td>
<td><p><em>vertical_rate</em></p></td>
<td><p>float</p></td>
<td><p>Vertical rate in m/s. A positive value indicates that the airplane is climbing, a negative value indicates that it descends. Can be null.</p></td>
</tr>
<tr>
<td><p>12</p></td>
<td><p><em>sensors</em></p></td>
<td><p>int[]</p></td>
<td><p>IDs of the receivers which contributed to this state vector. Is null if no filtering for sensor was used in the request.</p></td>
</tr>
<tr>
<td><p>13</p></td>
<td><p><em>geo_altitude</em></p></td>
<td><p>float</p></td>
<td><p>Geometric altitude in meters. Can be null.</p></td>
</tr>
<tr>
<td><p>14</p></td>
<td><p><em>squawk</em></p></td>
<td><p>string</p></td>
<td><p>The transponder code aka Squawk. Can be null.</p></td>
</tr>
<tr>
<td><p>15</p></td>
<td><p><em>spi</em></p></td>
<td><p>boolean</p></td>
<td><p>Whether flight status indicates special purpose indicator.</p></td>
</tr>
<tr>
<td><p>16</p></td>
<td><p><em>position_source</em></p></td>
<td><p>int</p></td>
<td><p>Origin of this state's position.</p>
<ul>
<li>0 = ADS-B</li>
<li>1 = ASTERIX</li>
<li>2 = MLAT</li>
<li>3 = FLARM</li>
</ul></td>
</tr>
<tr>
<td><p>17</p></td>
<td><p><em>category</em></p></td>
<td><p>int</p></td>
<td><p>Aircraft category.</p>
<ul>
<li>0 = No information at all</li>
<li>1 = No ADS-B Emitter Category Information</li>
<li>2 = Light (&lt; 15500 lbs)</li>
<li>3 = Small (15500 to 75000 lbs)</li>
<li>4 = Large (75000 to 300000 lbs)</li>
<li>5 = High Vortex Large (aircraft such as B-757)</li>
<li>6 = Heavy (&gt; 300000 lbs)</li>
<li>7 = High Performance (&gt; 5g acceleration and 400 kts)</li>
<li>8 = Rotorcraft</li>
<li>9 = Glider / sailplane</li>
<li>10 = Lighter-than-air</li>
<li>11 = Parachutist / Skydiver</li>
<li>12 = Ultralight / hang-glider / paraglider</li>
<li>13 = Reserved</li>
<li>14 = Unmanned Aerial Vehicle</li>
<li>15 = Space / Trans-atmospheric vehicle</li>
<li>16 = Surface Vehicle – Emergency Vehicle</li>
<li>17 = Surface Vehicle – Service Vehicle</li>
<li>18 = Point Obstacle (includes tethered balloons)</li>
<li>19 = Cluster Obstacle</li>
<li>20 = Line Obstacle</li>
</ul></td>
</tr>
</tbody>
</table>

### Authentication

OpenSky exclusively supports the OAuth2 *client credentials* flow. Basic authentication with username and password is no longer accepted.

To get started:

1.  Log in to your OpenSky account and visit the [Account](https://opensky-network.org/my-opensky/account) page.
2.  Create a new API client and retrieve your `client_id` and `client_secret`.
3.  Exchange these for an access token, then pass it as a `Bearer` token on every request.

``` bash
export CLIENT_ID=your_client_id
export CLIENT_SECRET=your_client_secret

export TOKEN=$(curl -X POST "https://auth.opensky-network.org/auth/realms/opensky-network/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" | jq -r .access_token)

curl -H "Authorization: Bearer $TOKEN" https://opensky-network.org/api/states/all | jq .
```

Tokens expire after 30 minutes. A `401 Unauthorized` response means the token has expired - request a new one and retry.

#### Python Token Manager Example

For scripts making multiple calls, use this `TokenManager` class to handle token refresh automatically:

``` python
import requests
from datetime import datetime, timedelta

TOKEN_URL = "https://auth.opensky-network.org/auth/realms/opensky-network/protocol/openid-connect/token"
CLIENT_ID = "your_client_id"
CLIENT_SECRET = "your_client_secret"

# How many seconds before expiry to proactively refresh the token.
TOKEN_REFRESH_MARGIN = 30


class TokenManager:
    def __init__(self):
        self.token = None
        self.expires_at = None

    def get_token(self):
        """Return a valid access token, refreshing automatically if needed."""
        if self.token and self.expires_at and datetime.now() < self.expires_at:
            return self.token
        return self._refresh()

    def _refresh(self):
        """Fetch a new access token from the OpenSky authentication server."""
        r = requests.post(
            TOKEN_URL,
            data={
                "grant_type": "client_credentials",
                "client_id": CLIENT_ID,
                "client_secret": CLIENT_SECRET,
            },
        )
        r.raise_for_status()

        data = r.json()
        self.token = data["access_token"]
        expires_in = data.get("expires_in", 1800)
        self.expires_at = datetime.now() + timedelta(seconds=expires_in - TOKEN_REFRESH_MARGIN)
        return self.token

    def headers(self):
        """Return request headers with a valid Bearer token."""
        return {"Authorization": f"Bearer {self.get_token()}"}


# Create a single shared instance for your script.
tokens = TokenManager()

# Use it for any API call - the token is refreshed automatically.
response = requests.get(
    "https://opensky-network.org/api/states/all",
    headers=tokens.headers(),
)
print(response.json())
```

- `get_token()` only fetches a new token when the current one is about to expire.
- `headers()` can be passed directly to any `requests` call.
- Create **one** `TokenManager` instance and reuse it for all requests in your script.

### Limitations

**Anonymous users** (unauthenticated, bucketed by IP):

- Only the most recent state vectors are available - the `time` parameter is ignored.
- Time resolution is 10 seconds: (now - (now % 10)).

**Authenticated users:**

- State vectors up to 1 hour in the past. Requests with (t \< now - 3600) return `400 Bad Request`.
- Time resolution is 5 seconds: (t - (t % 5)).

> [!NOTE]
> You can retrieve state vectors from your own receivers without any credit cost or time restriction. See own-states.

### API Credits

All endpoints consume credits except `/states/own`. Credits are tracked in **three independent buckets** - one each for `/states/*`, `/tracks/*`, and `/flights/*`. Spending credits on one endpoint has no effect on the others.

**Credit quotas by tier - per endpoint (states, tracks, and flights each have their own independent quota):**

| Tier                              | Credits | Refill |
|-----------------------------------|---------|--------|
| Anonymous                         | 400     | Daily  |
| Standard user                     | 4,000   | Daily  |
| Active feeder (≥30% uptime/month) | 8,000   | Daily  |
| Licensed user                     | 14,400  | Hourly |

> [!NOTE]
> Active feeder status is recalculated every 2 hours. Tier upgrades take effect after ~50 requests. To confirm you are receiving the 8,000-credit allowance, check that `X-Rate-Limit-Remaining` exceeds 4,000 at the start of a day.

**Credit cost - `/states/all`** (bounding box area in sq° = latitude range × longitude range):

| Bounding box area             | Credits |
|-------------------------------|---------|
| ≤ 25 sq° or serial-only query | 1       |
| 25 – 100 sq°                  | 2       |
| 100 – 400 sq°                 | 3       |
| \> 400 sq° or global          | 4       |

**Credit cost - \`\`/flights/\*\`\` and \`\`/tracks/\*\`\`** (by day partitions - calendar day boundaries crossed by the time range):

| Partitions     | Credits |
|----------------|---------|
| Live / \< 24 h | 4       |
| 1 – 2          | 30      |
| 3 – 10         | 60 × N  |
| 11 – 15        | 120 × N |
| 16 – 20        | 240 × N |
| 21 – 25        | 480 × N |
| \> 25          | 960 × N |

When credits are available, `X-Rate-Limit-Remaining` shows your remaining balance. When exhausted, the API returns `429 Too Many Requests` and `X-Rate-Limit-Retry-After-Seconds` indicates how many seconds to wait.

### Examples

Retrieve all states as an anonymous user:

``` bash
$ curl -s "https://opensky-network.org/api/states/all" | python -m json.tool
```

Retrieve all states as an authenticated OpenSky user:

``` bash
$ curl -H "Authorization: Bearer $TOKEN" -s "https://opensky-network.org/api/states/all" | python -m json.tool
```

Retrieve states of two particular airplanes:

``` bash
$ curl -s "https://opensky-network.org/api/states/all?icao24=3c6444&icao24=3e1bf9" | python -m json.tool
```

------------------------------------------------------------------------

## Own State Vectors

The following API call can be used to retrieve state vectors for your own sensors without rate limitations. Note that authentication is required for this operation, otherwise you will get a `403 - Forbidden`.

### Operation

`GET /states/own`

### Request

Pass one of the following (optional) properties as request parameters to the `GET` request.

| Property | Type | Description |
|----|----|----|
| *time* | integer | The time in seconds since epoch (Unix timestamp to retrieve states for. Current time will be used if omitted. |
| *icao24* | string | One or more ICAO24 transponder addresses represented by a hex string (e.g. `abc9f3`). To filter multiple ICAO24 append the property once for each address. If omitted, the state vectors of all aircraft are returned. |
| *serials* | integer | Retrieve only states of a subset of your receivers. You can pass this argument several time to filter state of more than one of your receivers. In this case, the API returns all states of aircraft that are visible to at least one of the given receivers. |

### Response

The response is a JSON object with the following properties

| Property | Type | Description |
|----|----|----|
| *time* | integer | The time which the state vectors in this response are associated with. All vectors represent the state of a vehicle with the interval ([time - 1, time]).  |
| *states* | array | The state vectors. |

The *states* property is a two-dimensional array. Each row represents a state vector and contains the following fields:

<table style="width:98%;">
<colgroup>
<col style="width: 7%" />
<col style="width: 18%" />
<col style="width: 9%" />
<col style="width: 62%" />
</colgroup>
<thead>
<tr>
<th><p>Index</p></th>
<th><p>Property</p></th>
<th><p>Type</p></th>
<th><p>Description</p></th>
</tr>
</thead>
<tbody>
<tr>
<td><p>0</p></td>
<td><p><em>icao24</em></p></td>
<td><p>string</p></td>
<td><p>Unique ICAO 24-bit address of the transponder in hex string representation.</p></td>
</tr>
<tr>
<td><p>1</p></td>
<td><p><em>callsign</em></p></td>
<td><p>string</p></td>
<td><p>Callsign of the vehicle (8 chars). Can be null if no callsign has been received.</p></td>
</tr>
<tr>
<td><p>2</p></td>
<td><p><em>origin_country</em></p></td>
<td><p>string</p></td>
<td><p>Country name inferred from the ICAO 24-bit address.</p></td>
</tr>
<tr>
<td><p>3</p></td>
<td><p><em>time_position</em></p></td>
<td><p>int</p></td>
<td><p>Unix timestamp (seconds) for the last position update. Can be null if no position report was received by OpenSky within the past 15s.</p></td>
</tr>
<tr>
<td><p>4</p></td>
<td><p><em>last_contact</em></p></td>
<td><p>int</p></td>
<td><p>Unix timestamp (seconds) for the last update in general. This field is updated for any new, valid message received from the transponder.</p></td>
</tr>
<tr>
<td><p>5</p></td>
<td><p><em>longitude</em></p></td>
<td><p>float</p></td>
<td><p>WGS-84 longitude in decimal degrees. Can be null.</p></td>
</tr>
<tr>
<td><p>6</p></td>
<td><p><em>latitude</em></p></td>
<td><p>float</p></td>
<td><p>WGS-84 latitude in decimal degrees. Can be null.</p></td>
</tr>
<tr>
<td><p>7</p></td>
<td><p><em>baro_altitude</em></p></td>
<td><p>float</p></td>
<td><p>Barometric altitude in meters. Can be null.</p></td>
</tr>
<tr>
<td><p>8</p></td>
<td><p><em>on_ground</em></p></td>
<td><p>boolean</p></td>
<td><p>Boolean value which indicates if the position was retrieved from a surface position report.</p></td>
</tr>
<tr>
<td><p>9</p></td>
<td><p><em>velocity</em></p></td>
<td><p>float</p></td>
<td><p>Velocity over ground in m/s. Can be null.</p></td>
</tr>
<tr>
<td><p>10</p></td>
<td><p><em>true_track</em></p></td>
<td><p>float</p></td>
<td><p>True track in decimal degrees clockwise from north (north=0°). Can be null.</p></td>
</tr>
<tr>
<td><p>11</p></td>
<td><p><em>vertical_rate</em></p></td>
<td><p>float</p></td>
<td><p>Vertical rate in m/s. A positive value indicates that the airplane is climbing, a negative value indicates that it descends. Can be null.</p></td>
</tr>
<tr>
<td><p>12</p></td>
<td><p><em>sensors</em></p></td>
<td><p>int[]</p></td>
<td><p>IDs of the receivers which contributed to this state vector. Is null if no filtering for sensor was used in the request.</p></td>
</tr>
<tr>
<td><p>13</p></td>
<td><p><em>geo_altitude</em></p></td>
<td><p>float</p></td>
<td><p>Geometric altitude in meters. Can be null.</p></td>
</tr>
<tr>
<td><p>14</p></td>
<td><p><em>squawk</em></p></td>
<td><p>string</p></td>
<td><p>The transponder code aka Squawk. Can be null.</p></td>
</tr>
<tr>
<td><p>15</p></td>
<td><p><em>spi</em></p></td>
<td><p>boolean</p></td>
<td><p>Whether flight status indicates special purpose indicator.</p></td>
</tr>
<tr>
<td><p>16</p></td>
<td><p><em>position_source</em></p></td>
<td><p>int</p></td>
<td><p>Origin of this state's position.</p>
<ul>
<li>0 = ADS-B</li>
<li>1 = ASTERIX</li>
<li>2 = MLAT</li>
<li>3 = FLARM</li>
</ul></td>
</tr>
<tr>
<td><p>17</p></td>
<td><p><em>category</em></p></td>
<td><p>int</p></td>
<td><p>Aircraft category.</p>
<ul>
<li>0 = No information at all</li>
<li>1 = No ADS-B Emitter Category Information</li>
<li>2 = Light (&lt; 15500 lbs)</li>
<li>3 = Small (15500 to 75000 lbs)</li>
<li>4 = Large (75000 to 300000 lbs)</li>
<li>5 = High Vortex Large (aircraft such as B-757)</li>
<li>6 = Heavy (&gt; 300000 lbs)</li>
<li>7 = High Performance (&gt; 5g acceleration and 400 kts)</li>
<li>8 = Rotorcraft</li>
<li>9 = Glider / sailplane</li>
<li>10 = Lighter-than-air</li>
<li>11 = Parachutist / Skydiver</li>
<li>12 = Ultralight / hang-glider / paraglider</li>
<li>13 = Reserved</li>
<li>14 = Unmanned Aerial Vehicle</li>
<li>15 = Space / Trans-atmospheric vehicle</li>
<li>16 = Surface Vehicle – Emergency Vehicle</li>
<li>17 = Surface Vehicle – Service Vehicle</li>
<li>18 = Point Obstacle (includes tethered balloons)</li>
<li>19 = Cluster Obstacle</li>
<li>20 = Line Obstacle</li>
</ul></td>
</tr>
</tbody>
</table>

### Examples

Retrieve states for all sensors that belong to you:

``` bash
$ curl -H "Authorization: Bearer $TOKEN" -s "https://opensky-network.org/api/states/own" | python -m json.tool
```

Retrieve states as seen by a specific sensor with serial `123456`

``` bash
$ curl -H "Authorization: Bearer $TOKEN" -s "https://opensky-network.org/api/states/own?serials=123456" | python -m json.tool
```

Retrieve states for several receivers:

``` bash
$ curl -H "Authorization: Bearer $TOKEN" -s "https://opensky-network.org/api/states/own?serials=123456&serials=98765" | python -m json.tool
```

## Flights in Time Interval

This API call retrieves flights for a certain time interval [begin, end]. If no flights are found for the given time period, HTTP status `404 - Not found` is returned with an empty response body.

### Operation

`GET /flights/all`

### Request

These are the required request parameters:

| Property | Type | Description |
|----|----|----|
| *begin* | integer | Start of time interval to retrieve flights for as Unix time (seconds since epoch) |
| *end* | integer | End of time interval to retrieve flights for as Unix time (seconds since epoch) |

The given time interval must not be larger than two hours!

### Response

The response is a JSON array of flights where each flight is an object with the following properties:

| Property | Type | Description |
|----|----|----|
| *icao24* | string | Unique ICAO 24-bit address of the transponder in hex string representation. All letters are lower case. |
| *firstSeen* | integer | Estimated time of departure for the flight as Unix time (seconds since epoch). |
| *estDepartureAirport* | string | ICAO code of the estimated departure airport. Can be null if the airport could not be identified. |
| *lastSeen* | integer | Estimated time of arrival for the flight as Unix time (seconds since epoch) |
| *estArrivalAirport* | string | ICAO code of the estimated arrival airport. Can be null if the airport could not be identified. |
| *callsign* | string | Callsign of the vehicle (8 chars). Can be null if no callsign has been received. If the vehicle transmits multiple callsigns during the flight, we take the one seen most frequently |
| *estDepartureAirportHorizDistance* | integer | Horizontal distance of the last received airborne position to the estimated departure airport in meters |
| *estDepartureAirportVertDistance* | integer | Vertical distance of the last received airborne position to the estimated departure airport in meters |
| *estArrivalAirportHorizDistance* | integer | Horizontal distance of the last received airborne position to the estimated arrival airport in meters |
| *estArrivalAirportVertDistance* | integer | Vertical distance of the last received airborne position to the estimated arrival airport in meters |
| *departureAirportCandidatesCount* | integer | Number of other possible departure airports. These are airports in short distance to *estDepartureAirport*. |
| *arrivalAirportCandidatesCount* | integer | Number of other possible arrival airports. These  are airports in short distance to *estArrivalAirport*. |

### Examples

Get flights from 12pm to 1pm on Jan 29 2018:

``` bash
$ curl -H "Authorization: Bearer $TOKEN" -s "https://opensky-network.org/api/flights/all?begin=1517227200&end=1517230800" | python -m json.tool
```

## Flights by Aircraft

This API call retrieves flights for a particular aircraft within a certain time interval. Resulting flights departed and arrived within [begin, end]. If no flights are found for the given period, HTTP stats `404 - Not found` is returned with an empty response body.

> [!NOTE]
> Flights are updated by a batch process at night, i.e., only flights from the previous day or earlier are available using this endpoint.

### Operation

`GET /flights/aircraft`

### Request

These are the required request parameters:

| Property | Type | Description |
|----|----|----|
| *icao24* | string | Unique ICAO 24-bit address of the transponder in hex string representation. All letters need to be lower case |
| *begin* | integer | Start of time interval to retrieve flights for as Unix time (seconds since epoch) |
| *end* | integer | End of time interval to retrieve flights for as Unix time (seconds since epoch) |

The given time interval must not be larger than 2 days!

### Response

The response is a JSON array of flights where each flight is an object with the following properties:

| Property | Type | Description |
|----|----|----|
| *icao24* | string | Unique ICAO 24-bit address of the transponder in hex string representation. All letters are lower case. |
| *firstSeen* | integer | Estimated time of departure for the flight as Unix time (seconds since epoch). |
| *estDepartureAirport* | string | ICAO code of the estimated departure airport. Can be null if the airport could not be identified. |
| *lastSeen* | integer | Estimated time of arrival for the flight as Unix time (seconds since epoch) |
| *estArrivalAirport* | string | ICAO code of the estimated arrival airport. Can be null if the airport could not be identified. |
| *callsign* | string | Callsign of the vehicle (8 chars). Can be null if no callsign has been received. If the vehicle transmits multiple callsigns during the flight, we take the one seen most frequently |
| *estDepartureAirportHorizDistance* | integer | Horizontal distance of the last received airborne position to the estimated departure airport in meters |
| *estDepartureAirportVertDistance* | integer | Vertical distance of the last received airborne position to the estimated departure airport in meters |
| *estArrivalAirportHorizDistance* | integer | Horizontal distance of the last received airborne position to the estimated arrival airport in meters |
| *estArrivalAirportVertDistance* | integer | Vertical distance of the last received airborne position to the estimated arrival airport in meters |
| *departureAirportCandidatesCount* | integer | Number of other possible departure airports. These are airports in short distance to *estDepartureAirport*. |
| *arrivalAirportCandidatesCount* | integer | Number of other possible arrival airports. These  are airports in short distance to *estArrivalAirport*. |

### Examples

Get flights for D-AIZZ (3c675a) on Jan 29 2018:

``` bash
$ curl -H "Authorization: Bearer $TOKEN" -s "https://opensky-network.org/api/flights/aircraft?icao24=3c675a&begin=1517184000&end=1517270400" | python -m json.tool
```

## Arrivals by Airport

Retrieve flights for a certain airport which arrived within a given time interval [begin, end]. If no flights are found for the given period, HTTP stats `404 - Not found` is returned with an empty response body.

> [!NOTE]
> Similar to flights, arrivals are updated by a batch process at night, i.e., only arrivals from the previous day or earlier are available using this endpoint.

### Operation

`GET /flights/arrival`

### Request

These are the required request parameters:

| Property | Type | Description |
|----|----|----|
| *airport* | string | ICAO identier for the airport |
| *begin* | integer | Start of time interval to retrieve flights for as Unix time (seconds since epoch) |
| *end* | integer | End of time interval to retrieve flights for as Unix time (seconds since epoch) |

The given time interval must not be larger than two days!

### Response

The response is a JSON array of flights where each flight is an object with the following properties:

| Property | Type | Description |
|----|----|----|
| *icao24* | string | Unique ICAO 24-bit address of the transponder in hex string representation. All letters are lower case. |
| *firstSeen* | integer | Estimated time of departure for the flight as Unix time (seconds since epoch). |
| *estDepartureAirport* | string | ICAO code of the estimated departure airport. Can be null if the airport could not be identified. |
| *lastSeen* | integer | Estimated time of arrival for the flight as Unix time (seconds since epoch) |
| *estArrivalAirport* | string | ICAO code of the estimated arrival airport. Can be null if the airport could not be identified. |
| *callsign* | string | Callsign of the vehicle (8 chars). Can be null if no callsign has been received. If the vehicle transmits multiple callsigns during the flight, we take the one seen most frequently |
| *estDepartureAirportHorizDistance* | integer | Horizontal distance of the last received airborne position to the estimated departure airport in meters |
| *estDepartureAirportVertDistance* | integer | Vertical distance of the last received airborne position to the estimated departure airport in meters |
| *estArrivalAirportHorizDistance* | integer | Horizontal distance of the last received airborne position to the estimated arrival airport in meters |
| *estArrivalAirportVertDistance* | integer | Vertical distance of the last received airborne position to the estimated arrival airport in meters |
| *departureAirportCandidatesCount* | integer | Number of other possible departure airports. These are airports in short distance to *estDepartureAirport*. |
| *arrivalAirportCandidatesCount* | integer | Number of other possible arrival airports. These  are airports in short distance to *estArrivalAirport*. |

### Examples

Get all flights arriving at Frankfurt International Airport (EDDF) from 12pm to 1pm on Jan 29 2018:

``` bash
$ curl -H "Authorization: Bearer $TOKEN" -s "https://opensky-network.org/api/flights/arrival?airport=EDDF&begin=1517227200&end=1517230800" | python -m json.tool
```

## Departures by Airport

Retrieve flights for a certain airport which departed within a given time interval [begin, end]. If no flights are found for the given period, HTTP stats `404 - Not found` is returned with an empty response body.

### Operation

`GET /flights/departure`

### Request

These are the required request parameters:

| Property | Type | Description |
|----|----|----|
| *airport* | string | ICAO identier for the airport (usually upper case) |
| *begin* | integer | Start of time interval to retrieve flights for as Unix time (seconds since epoch) |
| *end* | integer | End of time interval to retrieve flights for as Unix time (seconds since epoch) |

The given time interval must cover more than two days (UTC)!

### Response

The response is a JSON array of flights where each flight is an object with the following properties

| Property | Type | Description |
|----|----|----|
| *icao24* | string | Unique ICAO 24-bit address of the transponder in hex string representation. All letters are lower case. |
| *firstSeen* | integer | Estimated time of departure for the flight as Unix time (seconds since epoch). |
| *estDepartureAirport* | string | ICAO code of the estimated departure airport. Can be null if the airport could not be identified. |
| *lastSeen* | integer | Estimated time of arrival for the flight as Unix time (seconds since epoch) |
| *estArrivalAirport* | string | ICAO code of the estimated arrival airport. Can be null if the airport could not be identified. |
| *callsign* | string | Callsign of the vehicle (8 chars). Can be null if no callsign has been received. If the vehicle transmits multiple callsigns during the flight, we take the one seen most frequently |
| *estDepartureAirportHorizDistance* | integer | Horizontal distance of the last received airborne position to the estimated departure airport in meters |
| *estDepartureAirportVertDistance* | integer | Vertical distance of the last received airborne position to the estimated departure airport in meters |
| *estArrivalAirportHorizDistance* | integer | Horizontal distance of the last received airborne position to the estimated arrival airport in meters |
| *estArrivalAirportVertDistance* | integer | Vertical distance of the last received airborne position to the estimated arrival airport in meters |
| *departureAirportCandidatesCount* | integer | Number of other possible departure airports. These are airports in short distance to *estDepartureAirport*. |
| *arrivalAirportCandidatesCount* | integer | Number of other possible arrival airports. These  are airports in short distance to *estArrivalAirport*. |

### Examples

Get all flights departing at Frankfurt International Airport (EDDF) from 12pm to 1pm on Jan 29 2018:

``` bash
$ curl -H "Authorization: Bearer $TOKEN" -s "https://opensky-network.org/api/flights/departure?airport=EDDF&begin=1517227200&end=1517230800" | python -m json.tool
```

## Track by Aircraft

> [!NOTE]
> The tracks endpoint is purely **experimental**. You can use the flights endpoint for historical data: flights-all.

Retrieve the trajectory for a certain aircraft at a given time. The trajectory is a list of waypoints containing position, barometric altitude, true track and an on-ground flag.

In contrast to state vectors, trajectories do not contain all information we have about the flight, but rather show the aircraft's general movement pattern. For this reason, waypoints are selected among available state vectors given the following set of rules:

- The first point is set immediately after the the aircraft's expected departure, or after the network received the first position when the aircraft entered its reception range.
- The last point is set right before the aircraft's expected arrival, or the aircraft left the networks reception range.
- There is a waypoint at least every 15 minutes when the aircraft is in-flight.
- A waypoint is added if the aircraft changes its track more than 2.5°.
- A waypoint is added if the aircraft changes altitude by more than 100m (~330ft).
- A waypoint is added if the on-ground state changes.

Tracks are strongly related to flights. Internally, we compute flights and tracks within the same processing step. As such, it may be beneficial to retrieve a list of flights with the API methods from above, and use these results with the given time stamps to retrieve detailed track information.

### Operation

`GET /tracks`

### Request

| Property | Type | Description |
|----|----|----|
| *icao24* | string | Unique ICAO 24-bit address of the transponder in hex string representation. All letters need to be lower case |
| *time* | integer | Unix time in seconds since epoch. It can be any time between start and end of a known flight. If time = 0, get the live track if there is any flight ongoing for the given aircraft. |

### Response

This endpoint is experimental and can be out of order at any time.

The response is a JSON object with the following properties:

| Property | Type | Description |
|----|----|----|
| *icao24* | string | Unique ICAO 24-bit address of the transponder in lower case hex string representation. |
| *startTime* | integer | Time of the first waypoint in seconds since epoch (Unix time). |
| *endTime* | integer | Time of the last waypoint in seconds since epoch (Unix time). |
| *calllsign* | string | Callsign (8 characters) that holds for the whole track. Can be null. |
| *path* | array | Waypoints of the trajectory (description below). |

Waypoints are represented as JSON arrays to save bandwidth. Each point contains the following information:

| Index | Property | Type | Description |
|----|----|----|----|
| 0 | *time* | integer | Time which the given waypoint is associated with in seconds since epoch (Unix time). |
| 1 | *latitude* | float | WGS-84 latitude in decimal degrees. Can be null. |
| 2 | *longitude* | float | WGS-84 longitude in decimal degrees. Can be null. |
| 3 | *baro_altitude* | float | Barometric altitude in meters. Can be null. |
| 4 | *true_track* | float | True track in decimal degrees clockwise from north (north=0°). Can be null. |
| 5 | *on_ground* | boolean | Boolean value which indicates if the position was retrieved from a surface position report. |

### Limitations

It is not possible to access flight tracks from more than 30 days in the past.

### Examples

Get the live track for aircraft with transponder address `3c4b26` (D-ABYF)

``` bash
$ curl -H "Authorization: Bearer $TOKEN" -s "https://opensky-network.org/api/tracks/all?icao24=3c4b26&time=0"
```

> For historical data spanning more than one hour, use the Trino/MinIO interface instead of the REST API.
