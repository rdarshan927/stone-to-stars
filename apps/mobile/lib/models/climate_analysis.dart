/// Dart models for `GET /api/v1/analysis/climate`.
///
/// Field names mirror the backend Pydantic models (`app/analysis_api.py`,
/// `app/analysis.py`, `app/schemas.py`). Only fields the dashboard uses are
/// parsed. A missing or mistyped required field throws a [FormatException].
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

List<Map<String, dynamic>> _list(Map<String, dynamic> json, String key) =>
    _field<List<dynamic>>(json, key).cast<Map<String, dynamic>>();

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

  /// Coordinates of the NASA grid cell actually returned.
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
  });

  factory SeasonalTrend.fromJson(Map<String, dynamic> json) => SeasonalTrend(
    status: _field<String>(json, 'status'),
    significant: _optional<bool>(json, 'significant'),
    pValue: _optionalDouble(json, 'p_value'),
    senSlopePerDecade: _optionalDouble(json, 'sen_slope_per_decade'),
    slopeUnitsPerDecade: _field<String>(json, 'slope_units_per_decade'),
    direction: _optional<String>(json, 'direction'),
  );

  final String status;
  final bool? significant;
  final double? pValue;
  final double? senSlopePerDecade;
  final String slopeUnitsPerDecade;
  final String? direction;

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
    );
  }

  final List<AnnualPoint> series;
  final String seriesUnits;
  final String method;
  final List<ExcludedYear> excludedYears;
  final TrendResult trend;
  final SeasonalTrend seasonal;
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
