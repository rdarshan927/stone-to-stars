import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/main.dart';
import 'package:mobile/models/climate_analysis.dart';
import 'package:mobile/screens/dashboard_screen.dart';
import 'package:mobile/services/climate_api_service.dart';

/// A minimal valid JSON payload that mirrors the backend response schema.
const _kFakeResponse = '''
{
  "location": {
    "latitude": 7.3,
    "longitude": 81.8,
    "elevation_m": 50.0,
    "requested_latitude": 7.3,
    "requested_longitude": 81.8
  },
  "dataset": {
    "provider": "NASA POWER",
    "title": "Prediction of Worldwide Energy Resources",
    "sources": ["MERRA2"],
    "time_standard": "LST",
    "community": "AG"
  },
  "period": {"start_year": 1981, "end_year": 2025},
  "methodology": {
    "alpha": 0.05,
    "min_observations": 10,
    "hamed_rao_lag": 1,
    "annual_completeness": "12 months required",
    "significance_basis": "Hamed-Rao corrected p-value",
    "confidence_interval": "95% CI via Theil-Sen bootstrap",
    "seasonal": "Seasonal Mann-Kendall across 12 monthly sub-series",
    "month_wise": "Exploratory per-month MK test, not corrected for multiplicity",
    "baseline": "1991-2020 WMO climatological normal",
    "limitations": ["NASA POWER is model-derived, not station-observed."]
  },
  "temperature": {
    "annual": {
      "series": [
        {"year": 2000, "mean_temperature_c": 27.5},
        {"year": 2001, "mean_temperature_c": 27.8}
      ],
      "method": "day-weighted mean",
      "excluded_years": []
    },
    "annual_trend": {
      "status": "ok",
      "n_observations": 2,
      "min_observations_required": 10,
      "value_units": "°C",
      "alpha": 0.05,
      "direction": "increasing",
      "significant": false,
      "significant_original": false,
      "kendall_tau": 0.5,
      "mk_s": 1,
      "z_original": 0.8,
      "p_value_original": 0.42,
      "z_hamed_rao": 0.75,
      "p_value_hamed_rao": 0.45,
      "hamed_rao_lag": 1,
      "sen_slope_per_year": 0.03,
      "sen_slope_per_decade": 0.3,
      "slope_units_per_decade": "°C/decade",
      "ci95_low_per_decade": -0.1,
      "ci95_high_per_decade": 0.7,
      "ci95_note": "Bootstrap 95% CI",
      "interpretation": "No significant trend detected."
    },
    "seasonal_trend": {
      "status": "ok",
      "significant": false,
      "p_value": 0.5,
      "sen_slope_per_decade": 0.2,
      "slope_units_per_decade": "°C/decade",
      "direction": "increasing"
    },
    "month_wise_trends": [],
    "anomalies": {
      "baseline_start": 1991,
      "baseline_end": 2020,
      "baseline_mean": 27.4,
      "records": []
    }
  },
  "precipitation": {
    "annual": {
      "series": [
        {"year": 2000, "total_mm_per_year": 1800.0, "mean_rate_mm_per_day": 4.9},
        {"year": 2001, "total_mm_per_year": 1750.0, "mean_rate_mm_per_day": 4.8}
      ],
      "method": "monthly rate × days",
      "excluded_years": []
    },
    "annual_total_trend": {
      "status": "ok",
      "n_observations": 2,
      "min_observations_required": 10,
      "value_units": "mm/year",
      "alpha": 0.05,
      "direction": "decreasing",
      "significant": false,
      "significant_original": false,
      "kendall_tau": -0.5,
      "mk_s": -1,
      "z_original": -0.8,
      "p_value_original": 0.42,
      "z_hamed_rao": -0.75,
      "p_value_hamed_rao": 0.45,
      "hamed_rao_lag": 1,
      "sen_slope_per_year": -5.0,
      "sen_slope_per_decade": -50.0,
      "slope_units_per_decade": "mm/year per decade",
      "ci95_low_per_decade": -150.0,
      "ci95_high_per_decade": 50.0,
      "ci95_note": "Bootstrap 95% CI",
      "interpretation": "No significant trend detected."
    },
    "seasonal_trend": {
      "status": "ok",
      "significant": false,
      "p_value": 0.6,
      "sen_slope_per_decade": -40.0,
      "slope_units_per_decade": "mm/year per decade",
      "direction": "decreasing"
    },
    "month_wise_trends": [],
    "anomalies": {
      "baseline_start": 1991,
      "baseline_end": 2020,
      "baseline_mean": 1780.0,
      "records": []
    }
  }
}
''';

/// Creates a [ClimateApiService] backed by a mock HTTP client that always
/// returns [_kFakeResponse].
ClimateApiService _mockService() {
  final mockClient = MockClient(
    (_) async => http.Response(_kFakeResponse, 200),
  );
  return ClimateApiService(client: mockClient);
}

void main() {
  testWidgets('App renders MaterialApp without crashing', (tester) async {
    await tester.pumpWidget(const StoneToStarsApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('DashboardScreen shows loading indicator then data', (
    tester,
  ) async {
    final service = _mockService();
    await tester.pumpWidget(
      MaterialApp(home: DashboardScreen(service: service)),
    );

    // Loading indicator should be visible before the future resolves.
    expect(find.byType(CircularProgressIndicator), findsAtLeastNWidgets(1));

    // Resolve the future.
    await tester.pumpAndSettle();

    // After data loads, the loading indicator is gone.
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('DashboardScreen shows error state on API failure', (
    tester,
  ) async {
    final failClient = MockClient((_) async => http.Response('error', 500));
    final service = ClimateApiService(client: failClient);

    await tester.pumpWidget(
      MaterialApp(home: DashboardScreen(service: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Failed to load data'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('ClimateAnalysis.fromJson parses fake response without error', (
    tester,
  ) async {
    // Pure unit-style test: no widgets needed.
    addTearDown(() {});
    final json = {
      'location': {
        'latitude': 7.3,
        'longitude': 81.8,
        'elevation_m': 50.0,
        'requested_latitude': 7.3,
        'requested_longitude': 81.8,
      },
      'dataset': {
        'provider': 'NASA POWER',
        'title': 'Test',
        'sources': ['MERRA2'],
        'time_standard': 'LST',
        'community': 'AG',
      },
      'period': {'start_year': 1981, 'end_year': 2025},
      'methodology': {
        'alpha': 0.05,
        'min_observations': 10,
        'hamed_rao_lag': 1,
        'annual_completeness': '12 months',
        'significance_basis': 'Hamed-Rao',
        'confidence_interval': '95%',
        'seasonal': 'Seasonal MK',
        'month_wise': 'Exploratory',
        'baseline': '1991-2020',
        'limitations': ['Model-derived'],
      },
      'temperature': {
        'annual': {
          'series': [
            {'year': 2000, 'mean_temperature_c': 27.5},
          ],
          'method': 'day-weighted',
          'excluded_years': [],
        },
        'annual_trend': {
          'status': 'insufficient_data',
          'n_observations': 1,
          'min_observations_required': 10,
          'value_units': '°C',
          'alpha': 0.05,
          'direction': null,
          'significant': null,
          'significant_original': null,
          'kendall_tau': null,
          'mk_s': null,
          'z_original': null,
          'p_value_original': null,
          'z_hamed_rao': null,
          'p_value_hamed_rao': null,
          'hamed_rao_lag': 1,
          'sen_slope_per_year': null,
          'sen_slope_per_decade': null,
          'slope_units_per_decade': '°C/decade',
          'ci95_low_per_decade': null,
          'ci95_high_per_decade': null,
          'ci95_note': '',
          'interpretation': 'Insufficient data.',
        },
        'seasonal_trend': {
          'status': 'insufficient_data',
          'significant': null,
          'p_value': null,
          'sen_slope_per_decade': null,
          'slope_units_per_decade': '°C/decade',
          'direction': null,
        },
        'month_wise_trends': [],
        'anomalies': {
          'baseline_start': 1991,
          'baseline_end': 2020,
          'baseline_mean': 27.0,
          'records': [],
        },
      },
      'precipitation': {
        'annual': {
          'series': [
            {
              'year': 2000,
              'total_mm_per_year': 1800.0,
              'mean_rate_mm_per_day': 4.9,
            },
          ],
          'method': 'rate × days',
          'excluded_years': [],
        },
        'annual_total_trend': {
          'status': 'insufficient_data',
          'n_observations': 1,
          'min_observations_required': 10,
          'value_units': 'mm/year',
          'alpha': 0.05,
          'direction': null,
          'significant': null,
          'significant_original': null,
          'kendall_tau': null,
          'mk_s': null,
          'z_original': null,
          'p_value_original': null,
          'z_hamed_rao': null,
          'p_value_hamed_rao': null,
          'hamed_rao_lag': 1,
          'sen_slope_per_year': null,
          'sen_slope_per_decade': null,
          'slope_units_per_decade': 'mm/year per decade',
          'ci95_low_per_decade': null,
          'ci95_high_per_decade': null,
          'ci95_note': '',
          'interpretation': 'Insufficient data.',
        },
        'seasonal_trend': {
          'status': 'insufficient_data',
          'significant': null,
          'p_value': null,
          'sen_slope_per_decade': null,
          'slope_units_per_decade': 'mm/year per decade',
          'direction': null,
        },
        'month_wise_trends': [],
        'anomalies': {
          'baseline_start': 1991,
          'baseline_end': 2020,
          'baseline_mean': 1780.0,
          'records': [],
        },
      },
    };

    final analysis = ClimateAnalysis.fromJson(json);
    expect(analysis.location.latitude, 7.3);
    expect(analysis.temperature.series.length, 1);
    expect(analysis.precipitation.series.first.value, 1800.0);
  });
}
