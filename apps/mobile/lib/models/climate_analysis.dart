/// Dart models for `GET /api/v1/analysis/climate`.
///
/// Field names mirror the backend Pydantic models (`app/analysis_api.py`,
/// `app/analysis.py`, `app/schemas.py`). A missing or mistyped required field
/// throws a [FormatException]. Scientific nulls are never replaced with zero.
library;

T _field<T>(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is T) return value;
  throw FormatException(
    'Unexpected response: "$key" should be $T but was '
    '${value == null ? 'missing' : value.runtimeType}.',
  );
}

T? _optional<T>(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is T) return value;
  throw FormatException('Unexpected response: "$key" has the wrong type.');
}

double? _optionalDouble(Map<String, dynamic> json, String key) =>
    _optional<num>(json, key)?.toDouble();

double _double(Map<String, dynamic> json, String key) =>
    _field<num>(json, key).toDouble();

Map<String, dynamic> _map(Map<String, dynamic> json, String key) =>
    _field<Map<String, dynamic>>(json, key);

List<Map<String, dynamic>> _list(Map<String, dynamic> json, String key) => [
  for (final value in _field<List<dynamic>>(json, key))
    if (value is Map<String, dynamic>)
      value
    else
      throw FormatException(
        'Unexpected response: "$key" contains a non-object.',
      ),
];

String _status(Map<String, dynamic> json) {
  final status = _field<String>(json, 'status');
  if (status != 'ok' && status != 'insufficient_data') {
    throw FormatException('Unexpected scientific status: $status.');
  }
  return status;
}

int _month(Map<String, dynamic> json) {
  final month = _field<int>(json, 'month');
  if (month < 1 || month > 12) {
    throw const FormatException('Invalid calendar month.');
  }
  return month;
}

Map<int, int> _monthCounts(Map<String, dynamic> json) {
  final data = _map(json, 'observations_per_month');
  final counts = <int, int>{};
  for (final entry in data.entries) {
    final month = int.tryParse(entry.key);
    if (month == null ||
        month < 1 ||
        month > 12 ||
        entry.key != '$month' ||
        entry.value is! int ||
        (entry.value as int) < 0) {
      throw const FormatException('Invalid monthly observation counts.');
    }
    counts[month] = entry.value as int;
  }
  return Map.unmodifiable(counts);
}

class Location {
  const Location({
    required this.latitude,
    required this.longitude,
    required this.elevationM,
    required this.requestedLatitude,
    required this.requestedLongitude,
  });

  factory Location.fromJson(Map<String, dynamic> json) => Location(
    latitude: _double(json, 'latitude'),
    longitude: _double(json, 'longitude'),
    elevationM: _optionalDouble(json, 'elevation_m'),
    requestedLatitude: _double(json, 'requested_latitude'),
    requestedLongitude: _double(json, 'requested_longitude'),
  );

  /// Point coordinates returned in NASA POWER geometry metadata; these do not
  /// establish a source-grid cell center or boundary.
  final double latitude;
  final double longitude;
  final double? elevationM;
  final double requestedLatitude;
  final double requestedLongitude;
}

class Dataset {
  const Dataset({
    required this.provider,
    required this.title,
    required this.sources,
    required this.timeStandard,
    required this.community,
  });

  factory Dataset.fromJson(Map<String, dynamic> json) => Dataset(
    provider: _field<String>(json, 'provider'),
    title: _optional<String>(json, 'title'),
    sources: _field<List<dynamic>>(json, 'sources').cast<String>(),
    timeStandard: _optional<String>(json, 'time_standard'),
    community: _field<String>(json, 'community'),
  );

  final String provider;
  final String? title;
  final List<String> sources;
  final String? timeStandard;
  final String community;
}

class Period {
  const Period({required this.startYear, required this.endYear});

  factory Period.fromJson(Map<String, dynamic> json) => Period(
    startYear: _field<int>(json, 'start_year'),
    endYear: _field<int>(json, 'end_year'),
  );

  final int startYear;
  final int endYear;
}

/// Mann-Kendall / Hamed-Rao / Theil-Sen result. `status` is `ok` or
/// `insufficient_data`; statistics are null when insufficient.
class TrendResult {
  const TrendResult({
    required this.status,
    required this.nObservations,
    required this.minObservationsRequired,
    required this.valueUnits,
    required this.alpha,
    required this.direction,
    required this.significant,
    required this.pValueOriginal,
    required this.pValueHamedRao,
    required this.hamedRaoLag,
    required this.kendallTau,
    required this.senSlopePerDecade,
    required this.slopeUnitsPerDecade,
    required this.ci95LowPerDecade,
    required this.ci95HighPerDecade,
    required this.ci95Note,
    required this.interpretation,
    this.significantOriginal,
    this.mkS,
    this.zOriginal,
    this.zHamedRao,
    this.senSlopePerYear,
    this.slopeUnitsPerYear,
    this.ci95LowPerYear,
    this.ci95HighPerYear,
  });

  factory TrendResult.fromJson(Map<String, dynamic> json) => TrendResult(
    status: _field<String>(json, 'status'),
    nObservations: _field<int>(json, 'n_observations'),
    minObservationsRequired: _field<int>(json, 'min_observations_required'),
    valueUnits: _field<String>(json, 'value_units'),
    alpha: _double(json, 'alpha'),
    direction: _optional<String>(json, 'direction'),
    significant: _optional<bool>(json, 'significant'),
    pValueOriginal: _optionalDouble(json, 'p_value_original'),
    pValueHamedRao: _optionalDouble(json, 'p_value_hamed_rao'),
    hamedRaoLag: _field<int>(json, 'hamed_rao_lag'),
    kendallTau: _optionalDouble(json, 'kendall_tau'),
    senSlopePerDecade: _optionalDouble(json, 'sen_slope_per_decade'),
    slopeUnitsPerDecade: _field<String>(json, 'slope_units_per_decade'),
    ci95LowPerDecade: _optionalDouble(json, 'ci95_low_per_decade'),
    ci95HighPerDecade: _optionalDouble(json, 'ci95_high_per_decade'),
    ci95Note: _field<String>(json, 'ci95_note'),
    interpretation: _field<String>(json, 'interpretation'),
    significantOriginal: _optional<bool>(json, 'significant_original'),
    mkS: _optionalDouble(json, 'mk_s'),
    zOriginal: _optionalDouble(json, 'z_original'),
    zHamedRao: _optionalDouble(json, 'z_hamed_rao'),
    senSlopePerYear: _optionalDouble(json, 'sen_slope_per_year'),
    slopeUnitsPerYear: _optional<String>(json, 'slope_units_per_year'),
    ci95LowPerYear: _optionalDouble(json, 'ci95_low_per_year'),
    ci95HighPerYear: _optionalDouble(json, 'ci95_high_per_year'),
  );

  final String status;
  final int nObservations;
  final int minObservationsRequired;
  final String valueUnits;
  final double alpha;
  final String? direction;

  /// Based on the Hamed-Rao corrected p-value.
  final bool? significant;
  final double? pValueOriginal;
  final double? pValueHamedRao;
  final int hamedRaoLag;
  final double? kendallTau;
  final double? senSlopePerDecade;
  final String slopeUnitsPerDecade;
  final double? ci95LowPerDecade;
  final double? ci95HighPerDecade;
  final String ci95Note;
  final String interpretation;
  final bool? significantOriginal;
  final double? mkS;
  final double? zOriginal;
  final double? zHamedRao;
  final double? senSlopePerYear;
  final String? slopeUnitsPerYear;
  final double? ci95LowPerYear;
  final double? ci95HighPerYear;

  bool get hasResult => status == 'ok';
}

class SeasonalTrend {
  const SeasonalTrend({
    required this.status,
    required this.significant,
    required this.pValue,
    required this.senSlopePerDecade,
    required this.slopeUnitsPerDecade,
    required this.direction,
    this.method,
    this.nObservations,
    this.observationsPerMonth,
    this.minObservationsPerMonthRequired,
    this.valueUnits,
    this.alpha,
    this.mkS,
    this.varS,
    this.z,
    this.senSlopePerYear,
    this.slopeUnitsPerYear,
    this.autocorrelationAdjusted,
    this.interpretation,
  });

  factory SeasonalTrend.fromJson(Map<String, dynamic> json) => SeasonalTrend(
    status: _status(json),
    significant: _optional<bool>(json, 'significant'),
    pValue: _optionalDouble(json, 'p_value'),
    senSlopePerDecade: _optionalDouble(json, 'sen_slope_per_decade'),
    slopeUnitsPerDecade: _field<String>(json, 'slope_units_per_decade'),
    direction: _optional<String>(json, 'direction'),
    method: _field<String>(json, 'method'),
    nObservations: _field<int>(json, 'n_observations'),
    observationsPerMonth: _monthCounts(json),
    minObservationsPerMonthRequired: _field<int>(
      json,
      'min_observations_per_month_required',
    ),
    valueUnits: _field<String>(json, 'value_units'),
    alpha: _double(json, 'alpha'),
    mkS: _optionalDouble(json, 'mk_s'),
    varS: _optionalDouble(json, 'var_s'),
    z: _optionalDouble(json, 'z'),
    senSlopePerYear: _optionalDouble(json, 'sen_slope_per_year'),
    slopeUnitsPerYear: _field<String>(json, 'slope_units_per_year'),
    autocorrelationAdjusted: _field<bool>(json, 'autocorrelation_adjusted'),
    interpretation: _field<String>(json, 'interpretation'),
  );

  final String status;
  final bool? significant;
  final double? pValue;
  final double? senSlopePerDecade;
  final String slopeUnitsPerDecade;
  final String? direction;

  // Nullable for existing manually constructed summaries; the API factory
  // requires non-null metadata where the Python response requires it.
  final String? method;
  final int? nObservations;
  final Map<int, int>? observationsPerMonth;
  final int? minObservationsPerMonthRequired;
  final String? valueUnits;
  final double? alpha;
  final double? mkS;
  final double? varS;
  final double? z;
  final double? senSlopePerYear;
  final String? slopeUnitsPerYear;
  final bool? autocorrelationAdjusted;
  final String? interpretation;

  bool get hasResult => status == 'ok';
}

class ExcludedYear {
  const ExcludedYear({required this.year, required this.validMonths});

  factory ExcludedYear.fromJson(Map<String, dynamic> json) => ExcludedYear(
    year: _field<int>(json, 'year'),
    validMonths: _field<int>(json, 'valid_months'),
  );

  final int year;
  final int validMonths;
}

/// One annual value (year, value).
class AnnualPoint {
  const AnnualPoint(this.year, this.value);

  final int year;
  final double value;
}

/// Annual series, trends and exclusions for temperature or precipitation.
class VariableAnalysis {
  const VariableAnalysis({
    required this.series,
    required this.seriesUnits,
    required this.method,
    required this.excludedYears,
    required this.trend,
    required this.seasonal,
    this.anomalies,
    this.monthWiseTrends,
  });

  /// Temperature: `temperature` section of the response.
  factory VariableAnalysis.temperature(Map<String, dynamic> json) {
    final annual = _map(json, 'annual');
    return VariableAnalysis(
      series: [
        for (final p in _list(annual, 'series'))
          AnnualPoint(_field<int>(p, 'year'), _double(p, 'mean_temperature_c')),
      ],
      seriesUnits: '°C',
      method: _field<String>(annual, 'method'),
      excludedYears: [
        for (final e in _list(annual, 'excluded_years'))
          ExcludedYear.fromJson(e),
      ],
      trend: TrendResult.fromJson(_map(json, 'annual_trend')),
      seasonal: SeasonalTrend.fromJson(_map(json, 'seasonal_trend')),
      anomalies: AnomalyResult.fromJson(_map(json, 'anomalies')),
      monthWiseTrends: MonthWiseTrends.fromJson(
        _map(json, 'month_wise_trends'),
      ),
    );
  }

  /// Precipitation: `precipitation` section; the series is the annual total.
  factory VariableAnalysis.precipitation(Map<String, dynamic> json) {
    final annual = _map(json, 'annual');
    return VariableAnalysis(
      series: [
        for (final p in _list(annual, 'series'))
          AnnualPoint(_field<int>(p, 'year'), _double(p, 'total_mm_per_year')),
      ],
      seriesUnits: 'mm/year',
      method: _field<String>(annual, 'method'),
      excludedYears: [
        for (final e in _list(annual, 'excluded_years'))
          ExcludedYear.fromJson(e),
      ],
      trend: TrendResult.fromJson(_map(json, 'annual_total_trend')),
      seasonal: SeasonalTrend.fromJson(_map(json, 'seasonal_trend')),
      anomalies: AnomalyResult.fromJson(_map(json, 'anomalies')),
      monthWiseTrends: MonthWiseTrends.fromJson(
        _map(json, 'month_wise_trends'),
      ),
    );
  }

  final List<AnnualPoint> series;
  final String seriesUnits;
  final String method;
  final List<ExcludedYear> excludedYears;
  final TrendResult trend;
  final SeasonalTrend seasonal;
  final AnomalyResult? anomalies;
  final MonthWiseTrends? monthWiseTrends;
}

/// The reference period actually selected by the backend, including coverage.
/// Null years mean no reference period could be selected.
class BaselineInfo {
  const BaselineInfo({
    required this.kind,
    required this.startYear,
    required this.endYear,
    required this.isStandardReferencePeriod,
    required this.minObservationsPerMonthRequired,
    required this.observationsPerMonth,
    required this.note,
  });

  factory BaselineInfo.fromJson(Map<String, dynamic> json) {
    final kind = _field<String>(json, 'kind');
    if (kind != 'standard_1991_2020' && kind != 'custom_reference') {
      throw FormatException('Unexpected baseline kind: $kind.');
    }
    return BaselineInfo(
      kind: kind,
      startYear: _optional<int>(json, 'start_year'),
      endYear: _optional<int>(json, 'end_year'),
      isStandardReferencePeriod: _field<bool>(
        json,
        'is_standard_reference_period',
      ),
      minObservationsPerMonthRequired: _field<int>(
        json,
        'min_observations_per_month_required',
      ),
      observationsPerMonth: _monthCounts(json),
      note: _field<String>(json, 'note'),
    );
  }
  final String kind;
  final int? startYear;
  final int? endYear;
  final bool isStandardReferencePeriod;
  final int minObservationsPerMonthRequired;
  final Map<int, int> observationsPerMonth;
  final String note;
}

/// Calendar-month reference mean in the enclosing anomaly result's units.
class MonthlyNormal {
  const MonthlyNormal({
    required this.month,
    required this.normal,
    required this.nObservations,
  });
  factory MonthlyNormal.fromJson(Map<String, dynamic> json) => MonthlyNormal(
    month: _month(json),
    normal: _double(json, 'normal'),
    nObservations: _field<int>(json, 'n_observations'),
  );
  final int month;
  final double normal;
  final int nObservations;
}

/// One available monthly observation and its departure from its reference mean.
/// Missing observations have no record; a zero anomaly is a genuine zero.
class AnomalyRecord {
  const AnomalyRecord({
    required this.year,
    required this.month,
    required this.value,
    required this.normal,
    required this.anomaly,
    this.anomalyAccumulatedMm,
  });
  factory AnomalyRecord.fromJson(Map<String, dynamic> json) => AnomalyRecord(
    year: _field<int>(json, 'year'),
    month: _month(json),
    value: _double(json, 'value'),
    normal: _double(json, 'normal'),
    anomaly: _double(json, 'anomaly'),
    anomalyAccumulatedMm: _optionalDouble(json, 'anomaly_accumulated_mm'),
  );
  final int year;
  final int month;
  final double value;
  final double normal;
  final double anomaly;

  /// Optional precipitation rate anomaly multiplied by days in this month (mm).
  final double? anomalyAccumulatedMm;
}

class AnomalyResult {
  const AnomalyResult({
    required this.status,
    required this.valueUnits,
    required this.anomalyUnits,
    required this.baseline,
    required this.normals,
    required this.anomalies,
    required this.note,
  });
  factory AnomalyResult.fromJson(Map<String, dynamic> json) => AnomalyResult(
    status: _status(json),
    valueUnits: _field<String>(json, 'value_units'),
    anomalyUnits: _field<String>(json, 'anomaly_units'),
    baseline: json['baseline'] == null
        ? null
        : BaselineInfo.fromJson(_map(json, 'baseline')),
    normals: [
      for (final normal in _list(json, 'normals'))
        MonthlyNormal.fromJson(normal),
    ],
    anomalies: [
      for (final record in _list(json, 'anomalies'))
        AnomalyRecord.fromJson(record),
    ],
    note: _field<String>(json, 'note'),
  );
  final String status;
  final String valueUnits;
  final String anomalyUnits;
  final BaselineInfo? baseline;
  final List<MonthlyNormal> normals;
  final List<AnomalyRecord> anomalies;
  final String note;
  bool get hasResult => status == 'ok';
}

/// A calendar-month trend, with Holm-adjusted fields separate from the raw test.
class MonthTrend {
  const MonthTrend({
    required this.month,
    required this.trend,
    this.pValueHamedRaoHolm,
    this.significantAfterHolm,
  });
  factory MonthTrend.fromJson(Map<String, dynamic> json) => MonthTrend(
    month: _month(json),
    trend: TrendResult.fromJson(_map(json, 'trend')),
    pValueHamedRaoHolm: _optionalDouble(json, 'p_value_hamed_rao_holm'),
    significantAfterHolm: _optional<bool>(json, 'significant_after_holm'),
  );
  final int month;
  final TrendResult trend;
  final double? pValueHamedRaoHolm;
  final bool? significantAfterHolm;
}

class MonthWiseTrends {
  const MonthWiseTrends({
    required this.exploratory,
    required this.note,
    required this.correction,
    required this.months,
  });
  factory MonthWiseTrends.fromJson(Map<String, dynamic> json) =>
      MonthWiseTrends(
        exploratory: _field<bool>(json, 'exploratory'),
        note: _field<String>(json, 'note'),
        correction: _field<String>(json, 'correction'),
        months: [
          for (final month in _list(json, 'months')) MonthTrend.fromJson(month),
        ],
      );
  final bool exploratory;
  final String note;
  final String correction;
  final List<MonthTrend> months;
}

class Methodology {
  const Methodology({
    required this.alpha,
    required this.minObservations,
    required this.hamedRaoLag,
    required this.annualCompleteness,
    required this.significanceBasis,
    required this.confidenceInterval,
    required this.seasonal,
    required this.monthWise,
    required this.baseline,
    required this.limitations,
  });

  factory Methodology.fromJson(Map<String, dynamic> json) => Methodology(
    alpha: _double(json, 'alpha'),
    minObservations: _field<int>(json, 'min_observations'),
    hamedRaoLag: _field<int>(json, 'hamed_rao_lag'),
    annualCompleteness: _field<String>(json, 'annual_completeness'),
    significanceBasis: _field<String>(json, 'significance_basis'),
    confidenceInterval: _field<String>(json, 'confidence_interval'),
    seasonal: _field<String>(json, 'seasonal'),
    monthWise: _field<String>(json, 'month_wise'),
    baseline: _field<String>(json, 'baseline'),
    limitations: _field<List<dynamic>>(json, 'limitations').cast<String>(),
  );

  final double alpha;
  final int minObservations;
  final int hamedRaoLag;
  final String annualCompleteness;
  final String significanceBasis;
  final String confidenceInterval;
  final String seasonal;
  final String monthWise;
  final String baseline;
  final List<String> limitations;
}

class ClimateAnalysis {
  const ClimateAnalysis({
    required this.location,
    required this.dataset,
    required this.period,
    required this.methodology,
    required this.temperature,
    required this.precipitation,
  });

  factory ClimateAnalysis.fromJson(Map<String, dynamic> json) =>
      ClimateAnalysis(
        location: Location.fromJson(_map(json, 'location')),
        dataset: Dataset.fromJson(_map(json, 'dataset')),
        period: Period.fromJson(_map(json, 'period')),
        methodology: Methodology.fromJson(_map(json, 'methodology')),
        temperature: VariableAnalysis.temperature(_map(json, 'temperature')),
        precipitation: VariableAnalysis.precipitation(
          _map(json, 'precipitation'),
        ),
      );

  final Location location;
  final Dataset dataset;
  final Period period;
  final Methodology methodology;
  final VariableAnalysis temperature;
  final VariableAnalysis precipitation;
}
