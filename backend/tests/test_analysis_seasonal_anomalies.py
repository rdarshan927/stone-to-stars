import numpy as np
import pymannkendall as mk
import pytest

from app.analysis import (
    ALPHA,
    MIN_OBSERVATIONS,
    STANDARD_BASELINE,
    analyze_monthly_climate,
    analyze_precipitation,
    analyze_temperature,
    compute_anomalies,
    days_in_month,
    holm_adjust,
    month_wise_trends,
    seasonal_mann_kendall,
)
from app.nasa_power import parse_monthly_response
from tests.helpers import make_records


def seasonal_series(trend_per_year=0.0, noise=0.3, seed=5, amplitude=10.0):
    rng = np.random.default_rng(seed)
    noise_values = rng.normal(0, noise, (46, 12))

    def value(year, month):
        cycle = amplitude * np.sin(2 * np.pi * (month - 1) / 12)
        return float(
            25 + cycle + trend_per_year * (year - 1981) + noise_values[year - 1981, month - 1]
        )

    return make_records(value)


# ---- Seasonal Mann-Kendall -------------------------------------------------


def test_seasonal_detects_trend_through_strong_seasonal_cycle():
    r = seasonal_mann_kendall(seasonal_series(0.03), "degC")
    assert r.status == "ok"
    assert r.direction == "increasing"
    assert r.significant
    assert r.sen_slope_per_year == pytest.approx(0.03, abs=0.005)
    assert r.sen_slope_per_decade == pytest.approx(0.3, abs=0.05)
    assert r.n_observations == 540
    assert set(r.observations_per_month) == set(range(1, 13))
    assert r.autocorrelation_adjusted is False


def test_seasonal_cycle_alone_is_not_a_trend():
    r = seasonal_mann_kendall(seasonal_series(0.0), "degC")
    assert r.significant is False
    assert r.p_value > ALPHA
    assert "does not show that the climate is stable" in r.interpretation


def test_seasonal_matches_pymannkendall_on_complete_data():
    records = seasonal_series(0.02, seed=9)
    ours = seasonal_mann_kendall(records, "degC")
    ordered = [r.value for r in sorted(records, key=lambda r: (r.year, r.month))]
    ref = mk.seasonal_test(np.array(ordered), period=12)
    assert ours.mk_s == ref.s
    assert ours.var_s == pytest.approx(ref.var_s)
    assert ours.z == pytest.approx(ref.z)
    assert ours.p_value == pytest.approx(ref.p)


def test_seasonal_with_missing_months_keeps_seasons_aligned():
    # Removing some Januaries and a whole 1990 July must not shift seasons.
    records = [
        r
        for r in seasonal_series(0.03, seed=2)
        if not (r.month == 1 and r.year % 4 == 0) and not (r.month == 7 and r.year == 1990)
    ]
    r = seasonal_mann_kendall(records, "degC")
    assert r.status == "ok"
    assert r.observations_per_month[7] == 44
    assert r.observations_per_month[1] < 45
    assert r.sen_slope_per_year == pytest.approx(0.03, abs=0.006)


def test_seasonal_uses_actual_years_for_slope():
    # Keep only every other year: slope must still be per calendar year.
    records = [r for r in seasonal_series(0.04, noise=0.05) if r.year % 2 == 1]
    r = seasonal_mann_kendall(records, "degC")
    assert r.sen_slope_per_year == pytest.approx(0.04, abs=0.005)


def test_seasonal_insufficient_data():
    records = [r for r in seasonal_series(0.03) if r.year < 1981 + MIN_OBSERVATIONS - 1]
    r = seasonal_mann_kendall(records, "degC")
    assert r.status == "insufficient_data"
    assert r.significant is None and r.p_value is None
    assert seasonal_mann_kendall([], "degC").status == "insufficient_data"


def test_seasonal_one_short_month_makes_whole_test_insufficient():
    records = [r for r in seasonal_series(0.03) if not (r.month == 3 and r.year > 1985)]
    r = seasonal_mann_kendall(records, "degC")
    assert r.status == "insufficient_data"
    assert "[3]" in r.interpretation


# ---- Month-wise trends -----------------------------------------------------


def test_month_wise_marks_exploratory_and_adjusts_for_multiple_tests():
    rng = np.random.default_rng(21)
    noise = rng.normal(0, 0.5, (46, 12))
    records = make_records(
        lambda y, m: float(10 + (0.1 * (y - 1981) if m == 7 else 0) + noise[y - 1981, m - 1])
    )
    result = month_wise_trends(records, "degC")
    assert result.exploratory is True
    assert "Holm" in result.correction
    assert len(result.months) == 12
    july = result.months[6]
    assert july.trend.significant and july.significant_after_holm
    assert july.trend.sen_slope_per_year == pytest.approx(0.1, abs=0.02)
    for m in result.months:
        assert m.p_value_hamed_rao_holm >= m.trend.p_value_hamed_rao - 1e-12
    others = [m for m in result.months if m.month != 7]
    assert sum(bool(m.significant_after_holm) for m in others) == 0


def test_month_wise_insufficient_months_have_no_holm_values():
    records = make_records(lambda y, m: float(y), 1981, 1985)
    result = month_wise_trends(records, "degC")
    assert all(m.trend.status == "insufficient_data" for m in result.months)
    assert all(m.p_value_hamed_rao_holm is None for m in result.months)


def test_holm_adjust():
    assert holm_adjust([0.01, 0.04, 0.03]) == pytest.approx([0.03, 0.06, 0.06])
    assert holm_adjust([0.5]) == [0.5]
    assert holm_adjust([0.9, 0.8]) == pytest.approx([1.0, 1.0])
    assert holm_adjust([]) == []


# ---- Baseline and anomalies ------------------------------------------------


def test_standard_baseline_normals_and_anomalies():
    records = seasonal_series(0.03)
    result = compute_anomalies(records, "degC")
    assert result.status == "ok"
    b = result.baseline
    assert b.kind == "standard_1991_2020"
    assert (b.start_year, b.end_year) == STANDARD_BASELINE
    assert b.is_standard_reference_period is True
    assert b.min_observations_per_month_required == 24
    assert all(count == 30 for count in b.observations_per_month.values())
    assert "not an official station-based WMO normal" in b.note

    by_key = {(r.year, r.month): r.value for r in records}
    for normal in result.normals:
        expected = np.mean([by_key[(y, normal.month)] for y in range(1991, 2021)])
        assert normal.normal == pytest.approx(expected)
        assert normal.n_observations == 30
    for a in result.anomalies:
        assert a.anomaly == pytest.approx(a.value - result.normals[a.month - 1].normal)
        assert a.anomaly_accumulated_mm is None
    assert len(result.anomalies) == 540
    # anomalies of the baseline period average to zero for every month
    for month in range(1, 13):
        base = [a.anomaly for a in result.anomalies if a.month == month and 1991 <= a.year <= 2020]
        assert np.mean(base) == pytest.approx(0.0, abs=1e-9)


def test_anomalies_are_per_calendar_month_not_overall_mean():
    # Constant seasonal cycle: every anomaly must be exactly zero.
    records = make_records(lambda y, m: float(m * 2))
    result = compute_anomalies(records, "degC")
    assert all(a.anomaly == pytest.approx(0.0) for a in result.anomalies)


def test_custom_reference_when_standard_unavailable():
    records = seasonal_series(0.0, noise=0.2)
    short = [r for r in records if r.year >= 2000]  # only 21 years in 1991-2020
    result = compute_anomalies(short, "degC")
    assert result.status == "ok"
    b = result.baseline
    assert b.kind == "custom_reference"
    assert b.is_standard_reference_period is False
    assert (b.start_year, b.end_year) == (2000, 2025)
    assert "NOT" in b.note and "WMO standard normal" in b.note
    assert b.min_observations_per_month_required == MIN_OBSERVATIONS


def test_standard_needs_24_observations_per_month():
    records = [r for r in seasonal_series() if not (r.month == 4 and 1991 <= r.year <= 1998)]
    # April has 22 observations in 1991-2020 -> falls back to custom
    result = compute_anomalies(records, "degC")
    assert result.baseline.kind == "custom_reference"
    # Exactly 24 remaining is accepted as standard
    records = [r for r in seasonal_series() if not (r.month == 4 and 1991 <= r.year <= 1996)]
    assert compute_anomalies(records, "degC").baseline.kind == "standard_1991_2020"


def test_explicit_custom_baseline_is_labelled_custom():
    result = compute_anomalies(seasonal_series(), "degC", baseline=(2001, 2010))
    b = result.baseline
    assert result.status == "ok"
    assert b.kind == "custom_reference" and not b.is_standard_reference_period
    assert (b.start_year, b.end_year) == (2001, 2010)
    assert all(n == 10 for n in b.observations_per_month.values())


def test_explicit_standard_baseline_does_not_fall_back():
    short = [r for r in seasonal_series() if r.year >= 2005]
    result = compute_anomalies(short, "degC", baseline=STANDARD_BASELINE)
    assert result.status == "insufficient_data"
    assert result.anomalies == []


def test_anomalies_insufficient_data():
    result = compute_anomalies(make_records(lambda y, m: 1.0, 2000, 2004), "degC")
    assert result.status == "insufficient_data"
    assert result.normals == [] and result.anomalies == []
    assert compute_anomalies([], "degC").status == "insufficient_data"


def test_precipitation_rate_and_accumulated_anomalies():
    # Rate 2 mm/day normally, 3 mm/day in 2005 -> anomaly 1 mm/day
    records = make_records(lambda y, m: 3.0 if y == 2005 else 2.0)
    result = analyze_precipitation(records, 1981, 2025).anomalies
    assert result.anomaly_units == "mm/day"
    feb_2004 = next(a for a in result.anomalies if (a.year, a.month) == (2004, 2))
    feb_2005 = next(a for a in result.anomalies if (a.year, a.month) == (2005, 2))
    assert feb_2005.anomaly == pytest.approx(1.0 - 1.0 / 30)  # 2005 is in baseline
    base_normal = next(n for n in result.normals if n.month == 2).normal
    assert base_normal == pytest.approx(2 + 1 / 30)
    assert feb_2004.anomaly == pytest.approx(2 - base_normal)
    assert feb_2004.anomaly_accumulated_mm == pytest.approx(
        feb_2004.anomaly * days_in_month(2004, 2)
    )
    assert feb_2005.anomaly_accumulated_mm == pytest.approx(
        feb_2005.anomaly * 28
    )


# ---- End-to-end on the sample fixture (structure only) ---------------------


def test_orchestrator_on_sample_fixture(sample):
    parsed = parse_monthly_response(sample, 7.3, 81.8, 1981, 2025)
    result = analyze_monthly_climate(parsed)

    assert result.methodology.hamed_rao_lag == 3
    assert result.methodology.min_observations == 10
    t, p = result.temperature, result.precipitation
    assert t.annual_trend.status == "ok" and t.annual_trend.n_observations == 45
    assert t.annual_trend.slope_units_per_decade == "degC/decade"
    assert p.annual_total_trend.slope_units_per_decade == "mm/decade"
    assert p.annual_total_trend.value_units == "mm/year"
    assert t.seasonal_trend.n_observations == 540
    assert t.anomalies.baseline.kind == "standard_1991_2020"
    assert p.anomalies.anomalies[0].anomaly_accumulated_mm is not None
    assert len(t.month_wise_trends.months) == 12
    assert t.month_wise_trends.exploratory

    # the whole result must be JSON serialisable for the API
    assert result.model_dump_json()


def test_temperature_analysis_with_gap_years():
    records = [r for r in seasonal_series(0.03) if r.year not in (1985, 1990, 2010)]
    result = analyze_temperature(records, 1981, 2025)
    assert {e.year for e in result.annual.excluded_years} == {1985, 1990, 2010}
    assert result.annual_trend.n_observations == 42
    assert result.annual_trend.sen_slope_per_year == pytest.approx(0.03, abs=0.01)
