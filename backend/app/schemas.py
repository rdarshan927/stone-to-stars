"""Response models for the climate API."""

from pydantic import BaseModel


class Location(BaseModel):
    latitude: float
    longitude: float
    elevation_m: float | None
    requested_latitude: float
    requested_longitude: float


class Dataset(BaseModel):
    provider: str
    endpoint: str
    community: str
    title: str | None
    api_version: str | None
    sources: list[str]
    time_standard: str | None
    fill_value: float


class Period(BaseModel):
    start_year: int
    end_year: int


class MonthlyRecord(BaseModel):
    year: int
    month: int
    value: float


class AnnualRecord(BaseModel):
    year: int
    value: float


class ParameterSeries(BaseModel):
    code: str
    long_name: str | None
    units: str | None
    description: str
    monthly: list[MonthlyRecord]
    annual: list[AnnualRecord]
    missing_monthly_count: int
    missing_annual_count: int


class MonthlyClimateResponse(BaseModel):
    location: Location
    dataset: Dataset
    period: Period
    parameters: dict[str, ParameterSeries]
