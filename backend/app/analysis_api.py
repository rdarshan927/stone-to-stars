"""Climate analysis endpoint."""

from typing import Annotated

import httpx
from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel

from app.analysis import (
    Methodology,
    PrecipitationAnalysis,
    TemperatureAnalysis,
    analyze_monthly_climate,
)
from app.climate import get_http_client, load_monthly, resolve_period
from app.nasa_power import MIN_YEAR
from app.schemas import Dataset, Location, Period

router = APIRouter(prefix="/api/v1/analysis", tags=["analysis"])


class ClimateAnalysisResponse(BaseModel):
    """Trend analysis for one location.

    Annual series and excluded years are in ``temperature.annual`` and
    ``precipitation.annual``; baseline information is in
    ``*.anomalies.baseline``.
    """

    location: Location
    dataset: Dataset
    period: Period
    methodology: Methodology
    temperature: TemperatureAnalysis
    precipitation: PrecipitationAnalysis


@router.get("/climate", response_model=ClimateAnalysisResponse)
async def get_climate_analysis(
    client: Annotated[httpx.AsyncClient, Depends(get_http_client)],
    latitude: Annotated[float, Query(ge=-90, le=90)],
    longitude: Annotated[float, Query(ge=-180, le=180)],
    start_year: Annotated[int, Query(ge=MIN_YEAR)] = MIN_YEAR,
    end_year: Annotated[int | None, Query(ge=MIN_YEAR)] = None,
) -> ClimateAnalysisResponse:
    start_year, end_year = resolve_period(start_year, end_year)
    monthly = await load_monthly(client, latitude, longitude, start_year, end_year)
    analysis = analyze_monthly_climate(monthly)
    return ClimateAnalysisResponse(
        location=monthly.location,
        dataset=monthly.dataset,
        period=monthly.period,
        methodology=analysis.methodology,
        temperature=analysis.temperature,
        precipitation=analysis.precipitation,
    )
