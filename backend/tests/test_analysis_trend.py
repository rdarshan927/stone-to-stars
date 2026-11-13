import numpy as np
import pymannkendall as mk
import pytest

from app.analysis import (
    HAMED_RAO_LAG,
    MIN_OBSERVATIONS,
    analyze_trend,
    mann_kendall_hamed_rao,
    mann_kendall_original,
)

YEARS = np.arange(1981, 2026)


def linear(slope, intercept=20.0):
    return intercept + slope * (YEARS - 1981)


def ar1(phi, n=45, seed=1):
    rng = np.random.default_rng(seed)
    x = np.zeros(n)
    for t in range(1, n):
        x[t] = phi * x[t - 1] + rng.normal()
    return x


def test_positive_linear_trend():
    r = analyze_trend(YEARS, linear(0.05), "degC")
    assert r.status == "ok"
    assert r.direction == "increasing"
    assert r.significant and r.significant_original
    assert r.kendall_tau == pytest.approx(1.0)
    assert r.sen_slope_per_year == pytest.approx(0.05)
    assert r.sen_slope_per_decade == pytest.approx(0.5)
    assert r.ci95_low_per_decade <= 0.5 <= r.ci95_high_per_decade
    assert r.n_observations == 45
    assert r.slope_units_per_decade == "degC/decade"
    assert "not adjusted for autocorrelation" in r.ci95_note.lower()
    assert "conventional" in r.ci95_note.lower()
    assert r.hamed_rao_lag == HAMED_RAO_LAG


def test_negative_linear_trend():
    r = analyze_trend(YEARS, linear(-0.2, 100.0), "mm/year", "mm")
    assert r.direction == "decreasing"
    assert r.significant
    assert r.sen_slope_per_decade == pytest.approx(-2.0)
    assert r.slope_units_per_decade == "mm/decade"
    assert r.kendall_tau == pytest.approx(-1.0)


def test_slope_uses_actual_year_coordinates_with_gaps():
    years = np.array([1981, 1982, 1983, 1990, 2000, 2001, 2002, 2010, 2015, 2020, 2025])
    values = 5.0 + 0.1 * (years - 1981)
    r = analyze_trend(years, values, "degC")
    assert r.sen_slope_per_year == pytest.approx(0.1)
    assert r.n_observations == 11


def test_trendless_random_data_is_not_significant():
    rng = np.random.default_rng(42)
    r = analyze_trend(YEARS, 20 + rng.normal(0, 1, 45), "degC")
    assert r.significant is False
    assert r.p_value_original > 0.05
    assert r.p_value_hamed_rao > 0.05
    assert "does not show that the climate is stable" in r.interpretation


def test_constant_series_gives_no_trend():
    r = analyze_trend(YEARS, np.full(45, 3.0), "degC")
    assert r.status == "ok"
    assert r.significant is False
    assert r.direction == "none"
    assert r.p_value_original == 1.0
    assert r.p_value_hamed_rao == 1.0
    assert r.sen_slope_per_year == 0.0


def test_sen_slope_is_robust_to_outliers():
    values = linear(0.05)
    values[10] += 50
    values[30] -= 50
    r = analyze_trend(YEARS, values, "degC")
    assert r.sen_slope_per_decade == pytest.approx(0.5, abs=0.02)
    ols_per_decade = np.polyfit(YEARS, values, 1)[0] * 10
    assert abs(ols_per_decade - 0.5) > abs(r.sen_slope_per_decade - 0.5)


def test_original_mk_matches_pymannkendall():
    rng = np.random.default_rng(7)
    x = np.round(rng.normal(0, 1, 45) + 0.02 * np.arange(45), 1)  # ties included
    ours = mann_kendall_original(x)
    ref = mk.original_test(x)
    assert ours["s"] == ref.s
    assert ours["var_s"] == pytest.approx(ref.var_s)
    assert ours["z"] == pytest.approx(ref.z)
    assert ours["p"] == pytest.approx(ref.p)


def test_hamed_rao_matches_pymannkendall_with_lag():
    x = ar1(0.7) + 0.03 * np.arange(45)
    ref = mk.hamed_rao_modification_test(x, lag=HAMED_RAO_LAG)
    ours = mann_kendall_hamed_rao(x)
    assert ours["z"] == pytest.approx(ref.z)
    assert ours["p"] == pytest.approx(ref.p)


def test_autocorrelation_correction_is_more_conservative():
    # Trendless but strongly persistent series: the original test is
    # over-confident, the Hamed-Rao correction inflates the variance.
    x = ar1(0.85, seed=3)
    orig = mann_kendall_original(x)
    hr = mann_kendall_hamed_rao(x)
    assert abs(hr["z"]) < abs(orig["z"])
    assert hr["p"] > orig["p"]
    r = analyze_trend(YEARS, x, "degC")
    assert r.p_value_hamed_rao > r.p_value_original


def test_autocorrelation_correction_negligible_for_white_noise():
    rng = np.random.default_rng(11)
    x = rng.normal(size=45)
    orig = mann_kendall_original(x)
    hr = mann_kendall_hamed_rao(x)
    assert hr["p"] == pytest.approx(orig["p"], abs=0.15)


def test_false_positive_rate_lower_with_correction():
    # Over many trendless AR(1) series the corrected test must reject
    # less often than the original test.
    rejects_orig = rejects_hr = 0
    for seed in range(200):
        x = ar1(0.7, seed=seed)
        rejects_orig += mann_kendall_original(x)["p"] < 0.05
        rejects_hr += mann_kendall_hamed_rao(x)["p"] < 0.05
    assert rejects_hr < rejects_orig


def test_insufficient_data():
    n = MIN_OBSERVATIONS - 1
    r = analyze_trend(YEARS[:n], linear(0.05)[:n], "degC")
    assert r.status == "insufficient_data"
    assert r.n_observations == n
    assert r.significant is None and r.direction is None
    assert r.sen_slope_per_decade is None and r.p_value_hamed_rao is None
    assert "Insufficient data" in r.interpretation
    assert analyze_trend([], [], "degC").status == "insufficient_data"


def test_exactly_minimum_observations_is_analysed():
    r = analyze_trend(YEARS[:MIN_OBSERVATIONS], linear(0.05)[:MIN_OBSERVATIONS], "degC")
    assert r.status == "ok"


def test_invalid_inputs_rejected():
    with pytest.raises(ValueError):
        analyze_trend([1, 2, 3], [1, 2], "degC")
    with pytest.raises(ValueError):
        analyze_trend([2000, 1999] + list(range(2001, 2012)), list(range(13)), "degC")
    with pytest.raises(ValueError):
        analyze_trend(list(range(2000, 2012)), [float("nan")] * 12, "degC")
