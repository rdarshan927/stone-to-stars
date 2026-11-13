import calendar

import pytest

from app.analysis import (
    aggregate_annual_precipitation,
    aggregate_annual_temperature,
    days_in_month,
    monthly_accumulated_precipitation,
)
from app.nasa_power import parse_monthly_response
from tests.helpers import make_records


def test_days_in_month_handles_leap_years():
    assert days_in_month(1984, 2) == 29
    assert days_in_month(1981, 2) == 28
    assert days_in_month(1900, 2) == 28
    assert days_in_month(2000, 2) == 29


def test_temperature_is_day_weighted_and_leap_aware():
    # Only February differs: weight is 29/366 in a leap year, 28/365 otherwise.
    records = make_records(
        lambda y, m: 10.0 if m == 2 else 0.0, 1983, 1984
    )
    result = aggregate_annual_temperature(records)
    by_year = {r.year: r.mean_temperature_c for r in result.series}
    assert by_year[1983] == pytest.approx(10 * 28 / 365)
    assert by_year[1984] == pytest.approx(10 * 29 / 366)
    assert result.excluded_years == []


def test_temperature_day_weighting_differs_from_plain_mean():
    records = make_records(lambda y, m: float(m), 1981, 1981)
    result = aggregate_annual_temperature(records)
    plain = sum(range(1, 13)) / 12
    weighted = sum(m * calendar.monthrange(1981, m)[1] for m in range(1, 13)) / 365
    assert result.series[0].mean_temperature_c == pytest.approx(weighted)
    assert weighted != pytest.approx(plain)


def test_precipitation_unit_conversion_and_leap_year():
    records = make_records(lambda y, m: 1.0, 1983, 1984)
    result = aggregate_annual_precipitation(records)
    by_year = {r.year: r for r in result.series}
    # 1 mm/day everywhere -> total equals the number of days in the year
    assert by_year[1983].total_mm_per_year == pytest.approx(365)
    assert by_year[1984].total_mm_per_year == pytest.approx(366)
    assert by_year[1983].mean_rate_mm_per_day == pytest.approx(1.0)
    assert by_year[1984].mean_rate_mm_per_day == pytest.approx(1.0)


def test_monthly_accumulation_multiplies_rate_by_days():
    records = make_records(lambda y, m: 2.0 if m == 2 else 1.0, 1983, 1984)
    monthly = {
        (r.year, r.month): r for r in monthly_accumulated_precipitation(records)
    }
    assert monthly[(1983, 2)].accumulated_mm == pytest.approx(56.0)
    assert monthly[(1984, 2)].accumulated_mm == pytest.approx(58.0)
    assert monthly[(1984, 2)].days_in_month == 29
    assert monthly[(1984, 2)].rate_mm_per_day == 2.0
    assert monthly[(1984, 1)].accumulated_mm == pytest.approx(31.0)


def test_annual_rate_is_not_sum_of_monthly_rates():
    records = make_records(lambda y, m: 3.0, 1990, 1990)
    result = aggregate_annual_precipitation(records)
    assert result.series[0].mean_rate_mm_per_day == pytest.approx(3.0)
    assert result.series[0].total_mm_per_year == pytest.approx(3.0 * 365)


def test_incomplete_and_absent_years_are_excluded_and_reported():
    def value(year, month):
        if year == 1990 and month == 5:
            return None  # one missing month
        if year == 2000:
            return None  # entire year missing
        return 1.0

    records = make_records(value, 1981, 2005)
    for aggregate in (aggregate_annual_temperature, aggregate_annual_precipitation):
        result = aggregate(records, 1981, 2005)
        years = {r.year for r in result.series}
        assert 1990 not in years and 2000 not in years
        assert len(years) == 23
        excluded = {e.year: e for e in result.excluded_years}
        assert set(excluded) == {1990, 2000}
        assert excluded[1990].valid_months == 11
        assert excluded[1990].missing_months == [5]
        assert excluded[2000].valid_months == 0
        assert excluded[2000].missing_months == list(range(1, 13))


def test_without_year_range_only_years_with_data_are_reported():
    records = make_records(lambda y, m: None if (y == 1990 and m == 5) else 1.0, 1989, 1991)
    result = aggregate_annual_temperature(records)
    assert [e.year for e in result.excluded_years] == [1990]


def test_duplicate_records_rejected():
    records = make_records(lambda y, m: 1.0, 1990, 1990)
    with pytest.raises(ValueError):
        aggregate_annual_temperature(records + records[:1])


def test_fixture_annual_means_match_nasa_annual_values_without_using_them(sample):
    parsed = parse_monthly_response(sample, 7.3, 81.8, 1981, 2025)
    raw = sample["properties"]["parameter"]

    temp = aggregate_annual_temperature(parsed.parameters["T2M"].monthly, 1981, 2025)
    assert len(temp.series) == 45 and temp.excluded_years == []
    for r in temp.series:
        # NASA publishes 2-decimal annual values
        assert r.mean_temperature_c == pytest.approx(raw["T2M"][f"{r.year}13"], abs=0.0051)

    prec = aggregate_annual_precipitation(
        parsed.parameters["PRECTOTCORR"].monthly, 1981, 2025
    )
    for r in prec.series:
        assert r.mean_rate_mm_per_day == pytest.approx(
            raw["PRECTOTCORR"][f"{r.year}13"], abs=0.0051
        )
        assert r.total_mm_per_year == pytest.approx(
            r.mean_rate_mm_per_day * (366 if calendar.isleap(r.year) else 365)
        )


def test_fixture_missing_month_excludes_year_despite_nasa_annual_value(sample):
    parsed = parse_monthly_response(sample, 7.3, 81.8, 1981, 2025)
    monthly = [
        r
        for r in parsed.parameters["T2M"].monthly
        if not (r.year == 1990 and r.month == 1)
    ]
    assert "199013" in sample["properties"]["parameter"]["T2M"]  # NASA has it
    result = aggregate_annual_temperature(monthly, 1981, 2025)
    assert 1990 not in {r.year for r in result.series}
    assert [e.year for e in result.excluded_years] == [1990]
