"""Climate trend analysis for NASA POWER monthly data.

Pure functions (no I/O) so each step can be tested on its own:

1. Annual aggregation  - day-weighted, complete years only.
2. Trend analysis      - Mann-Kendall, Hamed-Rao, Theil-Sen.
3. Seasonal analysis   - Hirsch-Slack seasonal Mann-Kendall, month-wise trends.
4. Anomalies           - monthly anomalies against a labelled reference period.

See ``backend/README.md`` for the methodology and its limitations.
"""

import calendar
import math
from collections import defaultdict
from collections.abc import Sequence
from typing import Literal

import numpy as np
import pymannkendall as mk
from pydantic import BaseModel
from scipy import stats

from app.schemas import MonthlyClimateResponse, MonthlyRecord

# --------------------------------------------------------------------------
# Settings (documented in the README and echoed in every response)
# --------------------------------------------------------------------------

ALPHA = 0.05
MIN_OBSERVATIONS = 10
# Hamed-Rao autocorrelation lags considered. Annual and single-month series
# have at most ~45 points; lags 1-3 cover interannual persistence (e.g. ENSO)
# without fitting noise at long lags. Lags beyond this are ignored.
HAMED_RAO_LAG = 3
STANDARD_BASELINE = (1991, 2020)
MIN_BASELINE_OBS_STANDARD = 24  # 80% of 30 years per calendar month
MIN_BASELINE_OBS_CUSTOM = MIN_OBSERVATIONS

CI_NOTE = (
    "Conventional 95% Theil-Sen confidence interval (Sen 1968, as implemented "
    "in scipy.stats.theilslopes). It is NOT adjusted for autocorrelation and "
    "may be too narrow for serially correlated data."
)
NON_SIGNIFICANT_NOTE = (
    "No statistically significant monotonic trend detected at alpha=0.05. "
    "This does not show that the climate is stable: the test may lack power "
    "against natural year-to-year variability."
)

Status = Literal["ok", "insufficient_data"]


# --------------------------------------------------------------------------
# Result models
# --------------------------------------------------------------------------


class ExcludedYear(BaseModel):
    year: int
    valid_months: int
    missing_months: list[int]


class AnnualTemperature(BaseModel):
    year: int
    mean_temperature_c: float


class AnnualTemperatureResult(BaseModel):
    method: str
    series: list[AnnualTemperature]
    excluded_years: list[ExcludedYear]


class MonthlyPrecipitation(BaseModel):
    year: int
    month: int
    days_in_month: int
    rate_mm_per_day: float
    accumulated_mm: float


class AnnualPrecipitation(BaseModel):
    year: int
    total_mm_per_year: float
    mean_rate_mm_per_day: float


class AnnualPrecipitationResult(BaseModel):
    method: str
    monthly_accumulated: list[MonthlyPrecipitation]
    series: list[AnnualPrecipitation]
    excluded_years: list[ExcludedYear]


class TrendResult(BaseModel):
    """Mann-Kendall / Hamed-Rao / Theil-Sen result for one series.

    ``significant`` and ``direction`` use the Hamed-Rao corrected p-value.
    """

    status: Status
    n_observations: int
    min_observations_required: int
    value_units: str
    alpha: float = ALPHA
    direction: Literal["increasing", "decreasing", "none"] | None = None
    significant: bool | None = None
    significant_original: bool | None = None
    kendall_tau: float | None = None
    mk_s: float | None = None
    z_original: float | None = None
    p_value_original: float | None = None
    z_hamed_rao: float | None = None
    p_value_hamed_rao: float | None = None
    hamed_rao_lag: int = HAMED_RAO_LAG
    sen_slope_per_year: float | None = None
    sen_slope_per_decade: float | None = None
    slope_units_per_year: str
    slope_units_per_decade: str
    ci95_low_per_decade: float | None = None
    ci95_high_per_decade: float | None = None
    ci95_low_per_year: float | None = None
    ci95_high_per_year: float | None = None
    ci95_note: str = CI_NOTE
    interpretation: str


class MonthTrend(BaseModel):
    month: int
    trend: TrendResult
    p_value_hamed_rao_holm: float | None = None
    significant_after_holm: bool | None = None


class MonthWiseTrends(BaseModel):
    exploratory: bool = True
    note: str
    correction: str
    months: list[MonthTrend]


class SeasonalTrendResult(BaseModel):
    """Hirsch-Slack seasonal Mann-Kendall (period = 12) with seasonal Sen slope."""

    status: Status
    method: str
    n_observations: int
    observations_per_month: dict[int, int]
    min_observations_per_month_required: int
    value_units: str
    alpha: float = ALPHA
    direction: Literal["increasing", "decreasing", "none"] | None = None
    significant: bool | None = None
    mk_s: float | None = None
    var_s: float | None = None
    z: float | None = None
    p_value: float | None = None
    sen_slope_per_year: float | None = None
    sen_slope_per_decade: float | None = None
    slope_units_per_year: str
    slope_units_per_decade: str
    autocorrelation_adjusted: bool = False
    interpretation: str


class BaselineInfo(BaseModel):
    kind: Literal["standard_1991_2020", "custom_reference"]
    start_year: int | None
    end_year: int | None
    is_standard_reference_period: bool
    min_observations_per_month_required: int
    observations_per_month: dict[int, int]
    note: str


class MonthlyNormal(BaseModel):
    month: int
    normal: float
    n_observations: int


class AnomalyRecord(BaseModel):
    year: int
    month: int
    value: float
    normal: float
    anomaly: float
    anomaly_accumulated_mm: float | None = None


class AnomalyResult(BaseModel):
    status: Status
    value_units: str
    anomaly_units: str
    baseline: BaselineInfo | None
    normals: list[MonthlyNormal]
    anomalies: list[AnomalyRecord]
    note: str


class TemperatureAnalysis(BaseModel):
    annual: AnnualTemperatureResult
    annual_trend: TrendResult
    seasonal_trend: SeasonalTrendResult
    month_wise_trends: MonthWiseTrends
    anomalies: AnomalyResult


class PrecipitationAnalysis(BaseModel):
    annual: AnnualPrecipitationResult
    annual_total_trend: TrendResult
    seasonal_trend: SeasonalTrendResult
    month_wise_trends: MonthWiseTrends
    anomalies: AnomalyResult


class Methodology(BaseModel):
    alpha: float
    min_observations: int
    hamed_rao_lag: int
    annual_completeness: str
    significance_basis: str
    confidence_interval: str
    seasonal: str
    month_wise: str
    baseline: str
    limitations: list[str]


class ClimateAnalysis(BaseModel):
    methodology: Methodology
    temperature: TemperatureAnalysis
    precipitation: PrecipitationAnalysis


# --------------------------------------------------------------------------
# 1. Annual aggregation
# --------------------------------------------------------------------------


def days_in_month(year: int, month: int) -> int:
    """Number of days in a calendar month (leap years handled)."""
    return calendar.monthrange(year, month)[1]


def _group_by_year(records: Sequence[MonthlyRecord]) -> dict[int, dict[int, float]]:
    """Group records as {year: {month: value}}. Non-finite values are skipped."""
    grouped: dict[int, dict[int, float]] = defaultdict(dict)
    seen: set[tuple[int, int]] = set()
    for r in records:
        if not 1 <= r.month <= 12:
            raise ValueError(f"Invalid month {r.month} for year {r.year}.")
        if (r.year, r.month) in seen:
            raise ValueError(f"Duplicate record for {r.year}-{r.month:02d}.")
        seen.add((r.year, r.month))
        if math.isfinite(r.value):
            grouped[r.year][r.month] = float(r.value)
    return grouped


def _split_complete_years(
    records: Sequence[MonthlyRecord],
    start_year: int | None,
    end_year: int | None,
) -> tuple[dict[int, dict[int, float]], list[ExcludedYear]]:
    """Return years with all 12 valid months, and the excluded years.

    NASA's YYYY13 annual value is deliberately never consulted: it is not a
    substitute for missing monthly observations.
    """
    grouped = _group_by_year(records)
    years = set(grouped)
    if start_year is not None and end_year is not None:
        years |= set(range(start_year, end_year + 1))
    complete: dict[int, dict[int, float]] = {}
    excluded: list[ExcludedYear] = []
    for year in sorted(years):
        months = grouped.get(year, {})
        if len(months) == 12:
            complete[year] = months
        else:
            excluded.append(
                ExcludedYear(
                    year=year,
                    valid_months=len(months),
                    missing_months=[m for m in range(1, 13) if m not in months],
                )
            )
    return complete, excluded


def aggregate_annual_temperature(
    records: Sequence[MonthlyRecord],
    start_year: int | None = None,
    end_year: int | None = None,
) -> AnnualTemperatureResult:
    """Day-weighted annual mean temperature (deg C) from monthly means.

    mean_y = sum(days_m * T_m) / sum(days_m), so leap years (366 days) and
    unequal month lengths are respected. Years without all 12 valid months are
    excluded and reported. If ``start_year``/``end_year`` are given, years in
    that range with no data at all are reported as excluded too.
    """
    complete, excluded = _split_complete_years(records, start_year, end_year)
    series = []
    for year, months in complete.items():
        days = [days_in_month(year, m) for m in range(1, 13)]
        weighted = sum(d * months[m] for d, m in zip(days, range(1, 13)))
        series.append(
            AnnualTemperature(year=year, mean_temperature_c=weighted / sum(days))
        )
    return AnnualTemperatureResult(
        method="Day-weighted mean of 12 monthly mean temperatures (leap years "
        "respected); years with fewer than 12 valid months are excluded.",
        series=series,
        excluded_years=excluded,
    )


def monthly_accumulated_precipitation(
    records: Sequence[MonthlyRecord],
) -> list[MonthlyPrecipitation]:
    """Convert monthly mean daily rate (mm/day) to monthly total (mm)."""
    grouped = _group_by_year(records)
    out = []
    for year in sorted(grouped):
        for month in sorted(grouped[year]):
            rate = grouped[year][month]
            days = days_in_month(year, month)
            out.append(
                MonthlyPrecipitation(
                    year=year,
                    month=month,
                    days_in_month=days,
                    rate_mm_per_day=rate,
                    accumulated_mm=rate * days,
                )
            )
    return out


def aggregate_annual_precipitation(
    records: Sequence[MonthlyRecord],
    start_year: int | None = None,
    end_year: int | None = None,
) -> AnnualPrecipitationResult:
    """Annual precipitation from monthly mean daily rates (mm/day).

    total_y (mm/year)   = sum(days_m * rate_m)
    mean_rate_y (mm/day) = total_y / days_in_year
    Rates are never summed directly. Incomplete years are excluded.
    """
    complete, excluded = _split_complete_years(records, start_year, end_year)
    series = []
    for year, months in complete.items():
        total = sum(days_in_month(year, m) * months[m] for m in range(1, 13))
        days_year = 366 if calendar.isleap(year) else 365
        series.append(
            AnnualPrecipitation(
                year=year,
                total_mm_per_year=total,
                mean_rate_mm_per_day=total / days_year,
            )
        )
    return AnnualPrecipitationResult(
        method="Monthly total (mm) = mean daily rate (mm/day) x days in month; "
        "annual total (mm/year) = sum of monthly totals; annual mean rate "
        "(mm/day) = annual total / days in year. Years with fewer than 12 "
        "valid months are excluded.",
        monthly_accumulated=monthly_accumulated_precipitation(records),
        series=series,
        excluded_years=excluded,
    )


# --------------------------------------------------------------------------
# 2. Trend analysis
# --------------------------------------------------------------------------


def _mk_s_and_var(values: np.ndarray) -> tuple[float, float]:
    """Mann-Kendall S statistic and its tie-corrected variance."""
    n = len(values)
    if n < 2:
        return 0.0, 0.0
    diffs = values[None, :] - values[:, None]
    s = float(np.sign(diffs[np.triu_indices(n, k=1)]).sum())
    _, counts = np.unique(values, return_counts=True)
    ties = float(sum(t * (t - 1) * (2 * t + 5) for t in counts if t > 1))
    var_s = (n * (n - 1) * (2 * n + 5) - ties) / 18.0
    return s, var_s


def _mk_z(s: float, var_s: float) -> float:
    """Standardised statistic with continuity correction."""
    if var_s <= 0 or s == 0:
        return 0.0
    return (s - 1) / math.sqrt(var_s) if s > 0 else (s + 1) / math.sqrt(var_s)


def _two_sided_p(z: float) -> float:
    return float(2 * stats.norm.sf(abs(z)))


def mann_kendall_original(values: Sequence[float]) -> dict[str, float]:
    """Original Mann-Kendall test (assumes independent observations).

    Returns ``s``, ``var_s``, ``z`` and two-sided ``p``.
    """
    arr = np.asarray(values, dtype=float)
    s, var_s = _mk_s_and_var(arr)
    z = _mk_z(s, var_s)
    return {"s": s, "var_s": var_s, "z": z, "p": _two_sided_p(z)}


def mann_kendall_hamed_rao(
    values: Sequence[float], lag: int = HAMED_RAO_LAG
) -> dict[str, float]:
    """Hamed & Rao (1998) autocorrelation-corrected Mann-Kendall test.

    Uses ``pymannkendall.hamed_rao_modification_test`` with a limited lag.
    Only for single series without a seasonal cycle (annual values, one
    calendar month across years, or deseasonalised data), never raw monthly
    data. Returns ``z`` and two-sided ``p``.
    """
    arr = np.asarray(values, dtype=float)
    s, var_s = _mk_s_and_var(arr)
    if var_s <= 0 or np.all(arr == arr[0]):
        return {"z": 0.0, "p": 1.0}
    result = mk.hamed_rao_modification_test(arr, alpha=ALPHA, lag=lag)
    z, p = float(result.z), float(result.p)
    if not (math.isfinite(z) and math.isfinite(p)):
        # Strong negative autocorrelation can drive the corrected variance
        # non-positive; fall back to the uncorrected result rather than NaN.
        original = mann_kendall_original(arr)
        return {"z": original["z"], "p": original["p"]}
    return {"z": z, "p": p}


def _empty_trend(n: int, value_units: str, slope_units: str) -> TrendResult:
    return TrendResult(
        status="insufficient_data",
        n_observations=n,
        min_observations_required=MIN_OBSERVATIONS,
        value_units=value_units,
        slope_units_per_year=f"{slope_units}/year",
        slope_units_per_decade=f"{slope_units}/decade",
        interpretation=(
            f"Insufficient data: {n} observations, at least "
            f"{MIN_OBSERVATIONS} are required."
        ),
    )


def analyze_trend(
    years: Sequence[float],
    values: Sequence[float],
    value_units: str,
    slope_units: str | None = None,
) -> TrendResult:
    """Trend analysis of one non-seasonal series (annual, or one calendar month).

    * Direction: sign of the Theil-Sen slope; ``none`` if the slope is 0.
    * Significance: Hamed-Rao corrected p-value < alpha (primary).
    * Original Mann-Kendall p-value is reported alongside for transparency.
    * Sen's slope and its conventional 95% CI use the actual ``years`` as the
      x coordinate, so gaps from excluded years are handled correctly.
      (Hamed-Rao autocorrelation still treats consecutive retained values as
      adjacent, so large gaps weaken that correction.)

    Returns ``status="insufficient_data"`` below ``MIN_OBSERVATIONS``.
    """
    slope_units = slope_units or value_units
    x = np.asarray(years, dtype=float)
    y = np.asarray(values, dtype=float)
    if x.shape != y.shape or x.ndim != 1:
        raise ValueError("years and values must be 1-D and the same length.")
    if not (np.all(np.isfinite(x)) and np.all(np.isfinite(y))):
        raise ValueError("years and values must be finite.")
    if len(x) > 1 and np.any(np.diff(x) <= 0):
        raise ValueError("years must be strictly increasing.")

    n = len(y)
    if n < MIN_OBSERVATIONS:
        return _empty_trend(n, value_units, slope_units)

    orig = mann_kendall_original(y)
    hr = mann_kendall_hamed_rao(y)
    tau = 0.0 if np.all(y == y[0]) else float(stats.kendalltau(x, y).statistic)
    slope, _, lo, hi = stats.theilslopes(y, x, alpha=0.95)

    significant = hr["p"] < ALPHA
    direction = "increasing" if slope > 0 else "decreasing" if slope < 0 else "none"
    if significant:
        interpretation = (
            f"Statistically significant {direction} monotonic trend at "
            f"alpha={ALPHA} (Hamed-Rao corrected p={hr['p']:.4g}); Sen's slope "
            f"{slope * 10:+.3g} {slope_units}/decade."
        )
    else:
        interpretation = NON_SIGNIFICANT_NOTE

    return TrendResult(
        status="ok",
        n_observations=n,
        min_observations_required=MIN_OBSERVATIONS,
        value_units=value_units,
        direction=direction,
        significant=bool(significant),
        significant_original=bool(orig["p"] < ALPHA),
        kendall_tau=tau,
        mk_s=orig["s"],
        z_original=orig["z"],
        p_value_original=orig["p"],
        z_hamed_rao=hr["z"],
        p_value_hamed_rao=hr["p"],
        sen_slope_per_year=float(slope),
        sen_slope_per_decade=float(slope * 10),
        slope_units_per_year=f"{slope_units}/year",
        slope_units_per_decade=f"{slope_units}/decade",
        ci95_low_per_year=float(lo),
        ci95_high_per_year=float(hi),
        ci95_low_per_decade=float(lo * 10),
        ci95_high_per_decade=float(hi * 10),
        interpretation=interpretation,
    )


# --------------------------------------------------------------------------
# 3. Seasonal analysis
# --------------------------------------------------------------------------


def _by_month(
    records: Sequence[MonthlyRecord],
) -> dict[int, tuple[np.ndarray, np.ndarray]]:
    """{month: (years, values)} sorted by year, finite values only."""
    grouped = _group_by_year(records)
    out = {}
    for month in range(1, 13):
        pairs = sorted(
            (year, months[month]) for year, months in grouped.items() if month in months
        )
        out[month] = (
            np.array([p[0] for p in pairs], dtype=float),
            np.array([p[1] for p in pairs], dtype=float),
        )
    return out


def seasonal_mann_kendall(
    records: Sequence[MonthlyRecord], value_units: str
) -> SeasonalTrendResult:
    """Seasonal Mann-Kendall (Hirsch, Slack & Smith 1982), period = 12.

    S and Var(S) are computed within each calendar month (January against
    January etc.) and summed. The seasonal Sen's slope is the median of all
    within-month pairwise slopes, using actual years. Missing values are
    skipped per calendar month, so seasons never shift. Every calendar month
    needs at least ``MIN_OBSERVATIONS`` values, otherwise
    ``insufficient_data``.

    Not autocorrelation-adjusted, and months are treated as independent of
    each other; Hamed-Rao is deliberately not applied to the raw monthly data.
    """
    months = _by_month(records)
    counts = {m: len(months[m][1]) for m in range(1, 13)}
    base = dict(
        method="Hirsch-Slack seasonal Mann-Kendall, period=12 (within-month "
        "comparisons only)",
        n_observations=sum(counts.values()),
        observations_per_month=counts,
        min_observations_per_month_required=MIN_OBSERVATIONS,
        value_units=value_units,
        slope_units_per_year=f"{value_units}/year",
        slope_units_per_decade=f"{value_units}/decade",
    )
    short = [m for m, c in counts.items() if c < MIN_OBSERVATIONS]
    if short:
        return SeasonalTrendResult(
            status="insufficient_data",
            interpretation=(
                f"Insufficient data: calendar months {short} have fewer than "
                f"{MIN_OBSERVATIONS} valid observations."
            ),
            **base,
        )

    total_s = total_var = 0.0
    slopes: list[np.ndarray] = []
    for years, values in months.values():
        s, var_s = _mk_s_and_var(values)
        total_s += s
        total_var += var_s
        i, j = np.triu_indices(len(values), k=1)
        slopes.append((values[j] - values[i]) / (years[j] - years[i]))
    z = _mk_z(total_s, total_var)
    p = _two_sided_p(z)
    slope = float(np.median(np.concatenate(slopes)))
    significant = p < ALPHA
    direction = "increasing" if slope > 0 else "decreasing" if slope < 0 else "none"
    if significant:
        interpretation = (
            f"Statistically significant {direction} seasonal trend at "
            f"alpha={ALPHA} (p={p:.4g}; not corrected for autocorrelation); "
            f"seasonal Sen's slope {slope * 10:+.3g} {value_units}/decade."
        )
    else:
        interpretation = NON_SIGNIFICANT_NOTE
    return SeasonalTrendResult(
        status="ok",
        direction=direction,
        significant=bool(significant),
        mk_s=total_s,
        var_s=total_var,
        z=z,
        p_value=p,
        sen_slope_per_year=slope,
        sen_slope_per_decade=slope * 10,
        interpretation=interpretation,
        **base,
    )


def holm_adjust(p_values: Sequence[float]) -> list[float]:
    """Holm-Bonferroni adjusted p-values, in the original order."""
    m = len(p_values)
    order = sorted(range(m), key=lambda i: p_values[i])
    adjusted = [0.0] * m
    running = 0.0
    for rank, idx in enumerate(order):
        running = max(running, min(1.0, (m - rank) * p_values[idx]))
        adjusted[idx] = running
    return adjusted


def month_wise_trends(
    records: Sequence[MonthlyRecord], value_units: str, slope_units: str | None = None
) -> MonthWiseTrends:
    """Trend for each calendar month across years (exploratory).

    Each month's series has one value per year and no seasonal cycle, so
    Hamed-Rao is appropriate. Twelve tests are run, so Holm-Bonferroni
    adjusted p-values are provided; unadjusted per-month results are
    exploratory only.
    """
    months = _by_month(records)
    results = [
        MonthTrend(
            month=m,
            trend=analyze_trend(months[m][0], months[m][1], value_units, slope_units),
        )
        for m in range(1, 13)
    ]
    valid = [r for r in results if r.trend.status == "ok"]
    adjusted = holm_adjust([r.trend.p_value_hamed_rao for r in valid])
    for r, p_adj in zip(valid, adjusted):
        r.p_value_hamed_rao_holm = p_adj
        r.significant_after_holm = bool(p_adj < ALPHA)
    return MonthWiseTrends(
        note="Exploratory: twelve separate tests. Prefer the Holm-adjusted "
        "p-values; unadjusted per-month significance is likely to include "
        "false positives.",
        correction="Holm-Bonferroni across the 12 calendar months, applied to "
        "Hamed-Rao p-values",
        months=results,
    )


# --------------------------------------------------------------------------
# 4. Climatological anomalies
# --------------------------------------------------------------------------


def compute_anomalies(
    records: Sequence[MonthlyRecord],
    value_units: str,
    baseline: tuple[int, int] | None = None,
    accumulate_precipitation: bool = False,
) -> AnomalyResult:
    """Monthly anomalies = value - normal for the same calendar month.

    Reference period:
    * ``baseline=None``: try 1991-2020, which needs >= 24 valid observations
      in every calendar month. Otherwise fall back to a custom reference
      period covering all supplied records (>= 10 per calendar month).
    * explicit ``baseline=(start, end)``: used as given. Only (1991, 2020) is
      labelled standard (>= 24 per month); anything else is a custom
      reference period (>= 10 per month). No fallback.

    The normals are computed from NASA POWER (MERRA-2) grid values, not from
    station records, so they are reference averages rather than official WMO
    station normals even for 1991-2020.

    ``accumulate_precipitation=True`` (for mm/day input) adds
    ``anomaly_accumulated_mm`` = rate anomaly x days in that month.
    """
    grouped = _group_by_year(records)
    all_years = sorted(grouped)

    def month_values(start: int, end: int) -> dict[int, list[float]]:
        out: dict[int, list[float]] = {m: [] for m in range(1, 13)}
        for year in all_years:
            if start <= year <= end:
                for month, value in grouped[year].items():
                    out[month].append(value)
        return out

    def counts(values: dict[int, list[float]]) -> dict[int, int]:
        return {m: len(v) for m, v in values.items()}

    def enough(values: dict[int, list[float]], minimum: int) -> bool:
        return all(len(v) >= minimum for v in values.values())

    chosen: tuple[int, int] | None = None
    kind: Literal["standard_1991_2020", "custom_reference"] = "custom_reference"
    minimum = MIN_BASELINE_OBS_CUSTOM
    values: dict[int, list[float]] = {m: [] for m in range(1, 13)}

    if baseline is None or tuple(baseline) == STANDARD_BASELINE:
        std_vals = month_values(*STANDARD_BASELINE)
        if enough(std_vals, MIN_BASELINE_OBS_STANDARD):
            chosen, kind = STANDARD_BASELINE, "standard_1991_2020"
            minimum, values = MIN_BASELINE_OBS_STANDARD, std_vals
        elif baseline is not None:
            minimum, values = MIN_BASELINE_OBS_STANDARD, std_vals
            kind = "standard_1991_2020"
            chosen = None
        elif all_years:
            chosen = (all_years[0], all_years[-1])
            values = month_values(*chosen)
    else:
        chosen = (int(baseline[0]), int(baseline[1]))
        values = month_values(*chosen)

    obs = counts(values)
    ok = chosen is not None and enough(values, minimum)
    standard = kind == "standard_1991_2020"
    if standard and ok:
        note = (
            "Reference period 1991-2020 (the current standard WMO reference "
            "period), computed from NASA POWER MERRA-2 grid data; not an "
            "official station-based WMO normal."
        )
    else:
        note = (
            "Custom reference period; this is NOT the 1991-2020 standard "
            "reference period and must not be called a WMO standard normal."
        )

    anomaly_units = value_units
    if not ok:
        reason = (
            f"Insufficient data for a reference period: every calendar month "
            f"needs at least {minimum} valid observations (found "
            f"{obs}). No anomalies computed."
        )
        return AnomalyResult(
            status="insufficient_data",
            value_units=value_units,
            anomaly_units=anomaly_units,
            baseline=BaselineInfo(
                kind=kind,
                start_year=chosen[0] if chosen else None,
                end_year=chosen[1] if chosen else None,
                is_standard_reference_period=False,
                min_observations_per_month_required=minimum,
                observations_per_month=obs,
                note=reason,
            ),
            normals=[],
            anomalies=[],
            note=reason,
        )

    normals = {m: float(np.mean(values[m])) for m in range(1, 13)}
    anomalies = []
    for year in all_years:
        for month in sorted(grouped[year]):
            value = grouped[year][month]
            anomaly = value - normals[month]
            anomalies.append(
                AnomalyRecord(
                    year=year,
                    month=month,
                    value=value,
                    normal=normals[month],
                    anomaly=anomaly,
                    anomaly_accumulated_mm=(
                        anomaly * days_in_month(year, month)
                        if accumulate_precipitation
                        else None
                    ),
                )
            )
    assert chosen is not None
    return AnomalyResult(
        status="ok",
        value_units=value_units,
        anomaly_units=anomaly_units,
        baseline=BaselineInfo(
            kind=kind,
            start_year=chosen[0],
            end_year=chosen[1],
            is_standard_reference_period=standard,
            min_observations_per_month_required=minimum,
            observations_per_month=obs,
            note=note,
        ),
        normals=[
            MonthlyNormal(month=m, normal=normals[m], n_observations=obs[m])
            for m in range(1, 13)
        ],
        anomalies=anomalies,
        note="Anomaly = monthly value minus the normal of the same calendar "
        "month over the reference period.",
    )


# --------------------------------------------------------------------------
# Orchestration
# --------------------------------------------------------------------------


def analyze_temperature(
    records: Sequence[MonthlyRecord],
    start_year: int | None = None,
    end_year: int | None = None,
    baseline: tuple[int, int] | None = None,
) -> TemperatureAnalysis:
    annual = aggregate_annual_temperature(records, start_year, end_year)
    return TemperatureAnalysis(
        annual=annual,
        annual_trend=analyze_trend(
            [r.year for r in annual.series],
            [r.mean_temperature_c for r in annual.series],
            value_units="degC",
        ),
        seasonal_trend=seasonal_mann_kendall(records, "degC"),
        month_wise_trends=month_wise_trends(records, "degC"),
        anomalies=compute_anomalies(records, "degC", baseline),
    )


def analyze_precipitation(
    records: Sequence[MonthlyRecord],
    start_year: int | None = None,
    end_year: int | None = None,
    baseline: tuple[int, int] | None = None,
) -> PrecipitationAnalysis:
    """Precipitation analysis from monthly mean daily rates (mm/day).

    The annual trend is on the annual total (mm/year); seasonal and
    month-wise trends use the monthly rate (mm/day) so unequal month lengths
    do not enter the comparison.
    """
    annual = aggregate_annual_precipitation(records, start_year, end_year)
    return PrecipitationAnalysis(
        annual=annual,
        annual_total_trend=analyze_trend(
            [r.year for r in annual.series],
            [r.total_mm_per_year for r in annual.series],
            value_units="mm/year",
            slope_units="mm",
        ),
        seasonal_trend=seasonal_mann_kendall(records, "mm/day"),
        month_wise_trends=month_wise_trends(records, "mm/day"),
        anomalies=compute_anomalies(
            records, "mm/day", baseline, accumulate_precipitation=True
        ),
    )


def describe_methodology() -> Methodology:
    return Methodology(
        alpha=ALPHA,
        min_observations=MIN_OBSERVATIONS,
        hamed_rao_lag=HAMED_RAO_LAG,
        annual_completeness="Annual values require all 12 valid monthly "
        "observations; NASA's YYYY13 value is never used.",
        significance_basis="Hamed-Rao corrected p-value (lag limited to "
        f"{HAMED_RAO_LAG}); the original Mann-Kendall p-value is reported "
        "alongside.",
        confidence_interval=CI_NOTE,
        seasonal="Hirsch-Slack seasonal Mann-Kendall with period 12; not "
        "autocorrelation-adjusted.",
        month_wise="Exploratory; Holm-Bonferroni adjusted p-values provided.",
        baseline="1991-2020 when each calendar month has >= 24 valid "
        "observations, otherwise a labelled custom reference period.",
        limitations=[
            "Reanalysis grid-cell data (~50 km), not station observations.",
            "Mann-Kendall detects monotonic trends; non-significance does not "
            "prove stability.",
            "Hamed-Rao treats retained values as consecutive; excluded years "
            "create gaps.",
            "Confidence intervals are not autocorrelation-adjusted.",
            "Seasonal test ignores correlation between calendar months.",
        ],
    )


def analyze_monthly_climate(response: MonthlyClimateResponse) -> ClimateAnalysis:
    """Run the full analysis on a parsed NASA POWER monthly response."""
    t2m = response.parameters["T2M"].monthly
    prec = response.parameters["PRECTOTCORR"].monthly
    start, end = response.period.start_year, response.period.end_year
    return ClimateAnalysis(
        methodology=describe_methodology(),
        temperature=analyze_temperature(t2m, start, end),
        precipitation=analyze_precipitation(prec, start, end),
    )
