"""NASA POWER Monthly Point API client and response parser."""

import math
from typing import Any

import httpx

from app.schemas import (
    AnnualRecord,
    Dataset,
    Location,
    MonthlyClimateResponse,
    MonthlyRecord,
    ParameterSeries,
    Period,
)

ENDPOINT = "https://power.larc.nasa.gov/api/temporal/monthly/point"
COMMUNITY = "AG"
PARAMETERS = ("T2M", "PRECTOTCORR")
MIN_YEAR = 1981  # NASA POWER meteorological record starts in 1981
TIMEOUT = httpx.Timeout(30.0, connect=10.0)

# Our own descriptions of the verified temporal definitions of each parameter.
PARAMETER_DESCRIPTIONS = {
    "T2M": "Monthly mean of 2 m air temperature.",
    "PRECTOTCORR": (
        "Monthly mean DAILY precipitation rate (mm/day), not a monthly "
        "accumulated total."
    ),
}


class NasaPowerError(Exception):
    """Failure talking to, or understanding, NASA POWER."""

    def __init__(self, message: str, status_code: int = 502):
        super().__init__(message)
        self.message = message
        self.status_code = status_code


async def fetch_monthly(
    client: httpx.AsyncClient,
    latitude: float,
    longitude: float,
    start_year: int,
    end_year: int,
) -> dict[str, Any]:
    """Request monthly point data from NASA POWER and return the raw JSON."""
    params = {
        "parameters": ",".join(PARAMETERS),
        "community": COMMUNITY,
        "latitude": latitude,
        "longitude": longitude,
        "start": start_year,
        "end": end_year,
        "format": "JSON",
    }
    try:
        response = await client.get(ENDPOINT, params=params)
    except httpx.TimeoutException as exc:
        raise NasaPowerError("NASA POWER request timed out.", 504) from exc
    except httpx.HTTPError as exc:
        raise NasaPowerError(f"Could not reach NASA POWER: {exc}", 502) from exc

    if response.status_code != 200:
        detail = response.text[:300]
        raise NasaPowerError(
            f"NASA POWER returned HTTP {response.status_code}: {detail}", 502
        )
    try:
        return response.json()
    except ValueError as exc:
        raise NasaPowerError("NASA POWER returned invalid JSON.") from exc


def _is_missing(value: Any, fill_value: float) -> bool:
    if value is None:
        return True
    if not isinstance(value, (int, float)) or isinstance(value, bool):
        raise NasaPowerError(f"Non-numeric value in NASA POWER response: {value!r}")
    return math.isnan(value) or value == fill_value


def _parse_series(
    code: str, values: dict[str, Any], meta: dict[str, Any], fill_value: float
) -> ParameterSeries:
    monthly: list[MonthlyRecord] = []
    annual: list[AnnualRecord] = []
    missing_monthly = 0
    missing_annual = 0

    for key, value in values.items():
        if len(key) != 6 or not key.isdigit():
            raise NasaPowerError(f"Unexpected time key '{key}' for {code}.")
        year, suffix = int(key[:4]), int(key[4:])
        missing = _is_missing(value, fill_value)
        if 1 <= suffix <= 12:
            if missing:
                missing_monthly += 1
            else:
                monthly.append(MonthlyRecord(year=year, month=suffix, value=value))
        elif suffix == 13:  # annual summary, not a 13th month
            if missing:
                missing_annual += 1
            else:
                annual.append(AnnualRecord(year=year, value=value))
        else:
            raise NasaPowerError(f"Unexpected time key '{key}' for {code}.")

    monthly.sort(key=lambda r: (r.year, r.month))
    annual.sort(key=lambda r: r.year)
    return ParameterSeries(
        code=code,
        long_name=meta.get("longname"),
        units=meta.get("units"),
        description=PARAMETER_DESCRIPTIONS.get(code, ""),
        monthly=monthly,
        annual=annual,
        missing_monthly_count=missing_monthly,
        missing_annual_count=missing_annual,
    )


def parse_monthly_response(
    raw: dict[str, Any],
    requested_latitude: float,
    requested_longitude: float,
    start_year: int,
    end_year: int,
) -> MonthlyClimateResponse:
    """Validate a NASA POWER monthly point response and convert it."""
    try:
        coords = raw["geometry"]["coordinates"]
        header = raw["header"]
        fill_value = float(header["fill_value"])
        data = raw["properties"]["parameter"]
        meta = raw.get("parameters", {})
        longitude, latitude = float(coords[0]), float(coords[1])
        elevation = float(coords[2]) if len(coords) > 2 else None
    except (KeyError, IndexError, TypeError, ValueError) as exc:
        raise NasaPowerError(
            f"Unexpected NASA POWER response structure: {exc!r}"
        ) from exc

    missing_params = [p for p in PARAMETERS if p not in data]
    if missing_params:
        raise NasaPowerError(
            f"NASA POWER response lacks parameters: {', '.join(missing_params)}."
        )

    api = header.get("api")
    return MonthlyClimateResponse(
        location=Location(
            latitude=latitude,
            longitude=longitude,
            elevation_m=elevation,
            requested_latitude=requested_latitude,
            requested_longitude=requested_longitude,
        ),
        dataset=Dataset(
            provider="NASA POWER",
            endpoint=ENDPOINT,
            community=COMMUNITY,
            title=header.get("title"),
            api_version=api.get("version") if isinstance(api, dict) else None,
            sources=list(header.get("sources", [])),
            time_standard=header.get("time_standard"),
            fill_value=fill_value,
        ),
        period=Period(start_year=start_year, end_year=end_year),
        parameters={
            code: _parse_series(code, data[code], meta.get(code, {}), fill_value)
            for code in PARAMETERS
        },
    )
