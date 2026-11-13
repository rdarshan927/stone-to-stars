"""Climate data endpoints."""

from collections.abc import AsyncIterator
from datetime import date
from typing import Annotated

import httpx
from fastapi import APIRouter, Depends, HTTPException, Query

from app.nasa_power import (
    MIN_YEAR,
    TIMEOUT,
    NasaPowerError,
    fetch_monthly,
    parse_monthly_response,
)
from app.schemas import MonthlyClimateResponse

router = APIRouter(prefix="/api/v1/climate", tags=["climate"])


async def get_http_client() -> AsyncIterator[httpx.AsyncClient]:
    async with httpx.AsyncClient(timeout=TIMEOUT) as client:
        yield client


def last_complete_year() -> int:
    """NASA POWER monthly data runs through the previous complete year."""
    return date.today().year - 1


@router.get("/monthly", response_model=MonthlyClimateResponse)
async def get_monthly_climate(
    client: Annotated[httpx.AsyncClient, Depends(get_http_client)],
    latitude: Annotated[float, Query(ge=-90, le=90)],
    longitude: Annotated[float, Query(ge=-180, le=180)],
    start_year: Annotated[int, Query(ge=MIN_YEAR)] = MIN_YEAR,
    end_year: Annotated[int | None, Query(ge=MIN_YEAR)] = None,
) -> MonthlyClimateResponse:
    max_year = last_complete_year()
    if end_year is None:
        end_year = max_year
    if end_year > max_year:
        raise HTTPException(
            422,
            f"end_year must be at most {max_year} (last complete year "
            "available in NASA POWER monthly data).",
        )
    if start_year > end_year:
        raise HTTPException(422, "start_year must not be after end_year.")

    try:
        raw = await fetch_monthly(client, latitude, longitude, start_year, end_year)
        return parse_monthly_response(raw, latitude, longitude, start_year, end_year)
    except NasaPowerError as exc:
        raise HTTPException(exc.status_code, exc.message) from exc
