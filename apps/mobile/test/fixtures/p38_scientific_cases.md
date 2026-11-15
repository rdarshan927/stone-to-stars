These are synthetic, offline scientific response fixtures, generated with the
repository's existing Python `analyze_temperature` and `analyze_precipitation`
functions and serialized with Pydantic `model_dump(mode='json')`. They are not
NASA observations. No production calculation or API contract was changed.

Inputs for `p38_scientific_cases.json`:

- `custom`: all months of 1981–1992. Temperature = 20 + month × 0.25 +
  (year − 1981) × 0.03 degC; precipitation = 4 + month × 0.25 +
  (year − 1981) × 0.005 mm/day.
- `insufficient`: the same formulas with year origin 2001, for 2001–2002.
- `missing`: 1981–1992 with no year term; omit January 1981–1983 and
  February 1981. January's nine observations invalidate the baseline and
  seasonal test, while the other month-wise tests remain estimable.
- `zero_missing`: the same constant calendar-month values, omitting only
  February 1981. A valid custom baseline gives genuine zero anomalies;
  the omitted month has no anomaly record.
- `empty`: no monthly records. Baseline years and trend statistics are null.

The existing `p37_imagery_analysis.json` retains its annual and seasonal evidence.
Its previously omitted anomaly and month-wise sections were restored from the
same synthetic monthly inputs: temperature = 26 + 0.02 × (year − 1981) +
0.08 × (year modulo 5); precipitation rate = [2100 − 4 × (year − 1981) +
35 × ((year − 1981) modulo 7)] / days-in-year. December is omitted in 1983,
2009 and 2024. The reconstructed annual and seasonal values were checked against
the existing fixture (floating-point tolerance 1e-9). The full response also
restores the omitted monthly precipitation accumulations and required dataset
metadata (API version is null for this synthetic response). The full standard
response and all ten generated variable analyses validate against the existing
backend Pydantic models.

Contract notes: `*.anomalies.baseline` is a nullable object, not scalar baseline
fields. Anomaly `value`, `normal` and `anomaly` are required numbers; missing
months are omitted, never filled with zero. Only `anomaly_accumulated_mm` is
nullable on anomaly records. `month_wise_trends` is an object containing a
`months` array and correction guidance. Seasonal caveats are carried in `method`,
`autocorrelation_adjusted` and `interpretation`, not a separate limitations array.
An explicit custom reference is supported by Python but is not a query option on
the current climate-analysis endpoint; its automatic fallback is covered here.
