# Stone to Stars – Backend

FastAPI backend. See the root [README](../README.md) for setup.

```bash
cd backend
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload
pytest            # offline; uses data/samples/nasa_power_monthly_sample.json
```

## Layout

| File | Purpose |
|------|---------|
| `app/main.py` | App entry point, `/` and `/health` |
| `app/climate.py` | `GET /api/v1/climate/monthly` route, input validation |
| `app/nasa_power.py` | NASA POWER async client and response parser |
| `app/schemas.py` | Response models |
| `app/analysis.py` | Trend analysis (aggregation, Mann-Kendall, Sen, anomalies) |
| `app/analysis_api.py` | `GET /api/v1/analysis/climate` route |
| `tests/` | Offline tests (mocked HTTP transport, synthetic data, sample fixture) |

## `GET /api/v1/climate/monthly`

Fetches monthly data from the NASA POWER Monthly Point API
(`T2M`, `PRECTOTCORR`, community `AG`).

| Query param | Required | Rules |
|-------------|----------|-------|
| `latitude` | yes | -90 to 90 |
| `longitude` | yes | -180 to 180 |
| `start_year` | no (1981) | >= 1981, <= `end_year` |
| `end_year` | no (last complete year) | <= previous calendar year |

```bash
curl "http://127.0.0.1:8000/api/v1/climate/monthly?latitude=7.3&longitude=81.8&start_year=1981&end_year=2025"
```

### Response shape

```json
{
  "location": {"latitude": 7.3, "longitude": 81.8, "elevation_m": 16.12,
               "requested_latitude": 7.3, "requested_longitude": 81.8},
  "dataset": {"provider": "NASA POWER", "endpoint": "...", "community": "AG",
              "title": "...", "api_version": "...", "sources": ["MERRA2"],
              "time_standard": "LST", "fill_value": -999.0},
  "period": {"start_year": 1981, "end_year": 2025},
  "parameters": {
    "T2M": {
      "code": "T2M", "long_name": "Temperature at 2 Meters", "units": "C",
      "description": "...",
      "monthly": [{"year": 1981, "month": 1, "value": 25.37}],
      "annual": [{"year": 1981, "value": 26.9}],
      "missing_monthly_count": 0, "missing_annual_count": 0
    },
    "PRECTOTCORR": {"...": "units mm/day"}
  }
}
```

(Values above are illustrative of the shape; `location` is the NASA grid cell
returned, which may differ from the requested coordinates.)

### Semantics

- `monthly` holds `YYYYMM` records (months 1–12). `annual` holds the NASA
  `YYYY13` annual summaries, which are **not** a 13th month.
- Values equal to `dataset.fill_value` (read from the NASA response) or `null`
  are dropped and counted in `missing_*_count`.
- `PRECTOTCORR` is a monthly mean **daily rate** (mm/day), not a monthly total.
- `dataset.sources` and `time_standard` are passed through from NASA.

### Errors

| Status | Cause |
|--------|-------|
| 422 | Invalid parameters (including `end_year` after the last complete year) |
| 502 | NASA unreachable, non-200 reply, invalid JSON or unexpected structure |
| 504 | NASA request timed out (30 s read, 10 s connect) |


## Climate trend analysis (`app/analysis.py`)

Pure functions with typed (pydantic) results; no I/O. Entry points:
`analyze_monthly_climate(MonthlyClimateResponse)`, or per parameter
`analyze_temperature(records, start_year, end_year, baseline)` and
`analyze_precipitation(...)`. The building blocks (`aggregate_annual_*`,
`analyze_trend`, `seasonal_mann_kendall`, `month_wise_trends`,
`compute_anomalies`) are independently usable. The analysis is exposed at
`GET /api/v1/analysis/climate` (below). Units are explicit in every result
(`degC`, `mm/day`, `mm/year`, `degC/decade`, ...).

### Annual aggregation

- **Temperature:** day-weighted mean of the 12 monthly means,
  `sum(days_m * T_m) / days_in_year` (leap years respected).
- **Precipitation:** monthly total (mm) = mean daily rate (mm/day) x days in
  month. Annual total (mm/year) = sum of monthly totals. Annual mean rate
  (mm/day) = annual total / days in year. Rates are never summed directly.
- **Completeness:** a year needs all 12 valid months, otherwise it is excluded
  and listed in `excluded_years` (with `valid_months` and `missing_months`;
  years with no data at all are listed when the requested period is given).
  NASA's `YYYY13` value is never used, not even as a substitute.

### Trend analysis (annual series, or one calendar month across years)

- Original Mann-Kendall (tie-corrected variance, continuity-corrected Z),
  reported as `p_value_original`.
- Hamed-Rao (1998) modified Mann-Kendall via `pymannkendall`, reported as
  `p_value_hamed_rao`. **Lag setting: the first 3 autocorrelation lags
  (`HAMED_RAO_LAG = 3`)**, enough for interannual persistence in series of
  at most ~45 values.
- **`significant` and `direction` are based on the Hamed-Rao p-value at
  alpha = 0.05**; direction is the sign of Sen's slope.
- Theil-Sen slope with the **actual years** as x coordinates, per year and per
  decade, plus Kendall's tau (tau-b, `scipy.stats.kendalltau`).
- The 95% interval is the **conventional** Theil-Sen interval
  (`scipy.stats.theilslopes`). It is **not adjusted for autocorrelation** and
  can be too narrow.
- Fewer than 10 observations returns `status: "insufficient_data"`.
- A non-significant result means no trend was detected given this sample size
  and variability. It does not show that the climate is stable.

### Seasonal analysis

- **Seasonal Mann-Kendall** (Hirsch, Slack & Smith 1982), period 12: S and
  Var(S) per calendar month, summed; seasonal Sen's slope = median of all
  within-month pairwise slopes (actual years). Missing values are skipped per
  calendar month so seasons never shift. Every calendar month needs >= 10
  values. It is **not autocorrelation-adjusted** and ignores correlation
  between months. Hamed-Rao is never applied to raw monthly data.
- **Month-wise trends** (12 separate series) are flagged `exploratory`.
  Holm-adjusted p-values (`p_value_hamed_rao_holm`, `significant_after_holm`)
  are provided; prefer these to the unadjusted per-month results.
- Precipitation: the annual trend uses annual totals (mm/year); seasonal and
  month-wise trends use the monthly rate (mm/day), so month lengths do not
  enter the comparison.

### Anomalies

- Normal = mean of the same calendar month over the reference period;
  anomaly = value - normal. Precipitation also returns
  `anomaly_accumulated_mm` = rate anomaly x days in that month.
- Default reference period 1991-2020, used when each calendar month has >= 24
  valid observations in it (`baseline.kind = "standard_1991_2020"`). Normals
  come from NASA POWER (MERRA-2) grid data, so they are not official
  station-based WMO normals.
- Otherwise a `custom_reference` period (all supplied years, or an explicit
  `baseline=(start, end)`) with >= 10 observations per calendar month is used.
  It is labelled custom and never described as a WMO standard normal. An
  explicit `baseline=(1991, 2020)` that lacks data returns
  `insufficient_data` instead of falling back.
- `baseline` reports the actual period and per-month observation counts.

### Limitations

- Reanalysis grid-cell values (~50 km), not station observations; results
  describe the cell, not a point.
- Mann-Kendall tests for a monotonic trend only; it can't detect other
  patterns or establish causes.
- Hamed-Rao treats retained values as consecutive, so excluded years (gaps)
  weaken its autocorrelation correction. Sen's slope is unaffected.
- The seasonal test and all confidence intervals are not autocorrelation
  adjusted.
- Many tests are run per location (annual, seasonal, 12 months, two
  variables); p-values near 0.05 should not be over-interpreted.
- Validated against `pymannkendall` and synthetic series with known trends;
  no climate conclusions are drawn from the sample fixture.

## `GET /api/v1/analysis/climate`

Fetches monthly NASA POWER data (one upstream request, same client and
validation as `/api/v1/climate/monthly`) and runs the analysis above.

| Query param | Required | Rules |
|-------------|----------|-------|
| `latitude` | yes | -90 to 90 |
| `longitude` | yes | -180 to 180 |
| `start_year` | no (1981) | >= 1981, <= `end_year` |
| `end_year` | no (last complete year) | <= previous calendar year |

```bash
curl "http://127.0.0.1:8000/api/v1/analysis/climate?latitude=7.3&longitude=81.8&start_year=1981&end_year=2025"
```

Response fields:

| Field | Content |
|-------|---------|
| `location`, `dataset`, `period` | Same models as the monthly endpoint (grid cell, elevation, sources, time standard, fill value) |
| `methodology` | Settings (alpha, minimum observations, Hamed-Rao lag) and limitations |
| `temperature`, `precipitation` | Each has `annual` (series + `excluded_years`), an annual trend (`annual_trend` / `annual_total_trend`), `seasonal_trend`, `month_wise_trends` (exploratory), and `anomalies` (with `baseline`, normals and anomalies) |

Notes:

- Insufficient data is not an error: the affected results return
  `status: "insufficient_data"` (for example a period shorter than 10 years).
- The analysis uses only the years requested. The 1991-2020 reference period
  therefore needs the requested period to cover it (at least 24 valid values
  per calendar month inside 1991-2020); otherwise `baseline.kind` is
  `custom_reference` and says so.
- Errors are the same as the monthly endpoint: 422 invalid input, 502 NASA
  failure or unexpected response, 504 timeout.
