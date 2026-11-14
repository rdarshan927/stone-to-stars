import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/app/theme.dart';
import 'package:mobile/screens/dashboard_screen.dart';
import 'package:mobile/services/climate_api_service.dart';
import 'package:mobile/widgets/annual_chart.dart';
import 'package:mobile/widgets/climate_trend_card.dart';
import 'package:mobile/widgets/excluded_years_panel.dart';
import 'package:mobile/widgets/seasonal_trend_card.dart';

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

// Exercise long climate series, gaps, and a fully missing year in both tabs.
ClimateApiService service() {
  final data = jsonDecode(_kFakeResponse) as Map<String, dynamic>;
  for (final name in ['temperature', 'precipitation']) {
    final annual = data[name]['annual'] as Map<String, dynamic>;
    annual['series'] = [
      for (var year = 1981; year <= 2025; year++)
        if (year != 1990 && year != 2024)
          {
            'year': year,
            if (name == 'temperature')
              'mean_temperature_c': 25 + (year - 1981) * 0.03,
            if (name == 'precipitation') ...{
              'total_mm_per_year': 1800 + (year % 5) * 100.0,
              'mean_rate_mm_per_day': 5.0,
            },
          },
    ];
    annual['excluded_years'] = [
      {'year': 1990, 'valid_months': 0},
      {'year': 2024, 'valid_months': 11},
    ];
  }
  return ClimateApiService(
    client: MockClient(
      (_) async => http.Response.bytes(utf8.encode(jsonEncode(data)), 200),
    ),
  );
}

void setWidth(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
}

Future<void> openTab(WidgetTester tester, IconData icon) async {
  await tester.tap(find.byIcon(icon).first);
  await tester.pumpAndSettle();
}

void expectLayout(
  WidgetTester tester, {
  required bool twoColumns,
  required double viewportWidth,
}) {
  final chart = tester.getRect(find.byType(AnnualChart));
  final annual = tester.getRect(find.byType(ClimateTrendCard));
  final seasonal = tester.getRect(find.byType(SeasonalTrendCard));
  final excluded = tester.getRect(find.byType(ExcludedYearsPanel));
  expect(chart.width, greaterThanOrEqualTo(328));
  expect(
    tester.getSize(find.byType(LineChart)).height,
    greaterThanOrEqualTo(200),
  );
  expect(annual.left, chart.left);
  if (twoColumns) {
    expect(seasonal.top, annual.top);
    expect(seasonal.left - annual.right, closeTo(AppSpacing.lg, 0.01));
    expect(seasonal.width, annual.width);
    expect(seasonal.right, closeTo(chart.right, 0.01));
  } else {
    expect(seasonal.top - annual.bottom, closeTo(AppSpacing.lg, 0.01));
    expect(seasonal.left, annual.left);
    expect(annual.width, chart.width);
  }
  expect(excluded.width, chart.width);
  expect(
    excluded.top -
        (twoColumns
            ? (annual.bottom > seasonal.bottom
                  ? annual.bottom
                  : seasonal.bottom)
            : seasonal.bottom),
    closeTo(AppSpacing.lg, 0.01),
  );
  for (final rect in [chart, annual, seasonal, excluded]) {
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(viewportWidth));
  }
  expect(find.text('1990 · 0/12 valid months'), findsOneWidget);
  expect(find.text('2024 · 11/12 valid months'), findsOneWidget);
  expect(tester.takeException(), isNull);
}

void main() {
  for (final width in [360.0, 600.0, 768.0, 1024.0, 1280.0]) {
    for (final icon in [Icons.thermostat_outlined, Icons.water_drop_outlined]) {
      testWidgets('climate tab $icon fits $width, including expanded details', (
        tester,
      ) async {
        setWidth(tester, width);
        addTearDown(tester.view.reset);
        final api = service();
        addTearDown(api.close);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(),
            home: DashboardScreen(service: api),
          ),
        );
        await tester.pumpAndSettle();
        await openTab(tester, icon);
        expectLayout(tester, twoColumns: width >= 1000, viewportWidth: width);
        expect(find.text('95% CI / decade'), findsNothing);
        final toggle = find.byKey(
          const ValueKey('climate_trend_details_toggle'),
        );
        await tester.ensureVisible(toggle);
        await tester.pumpAndSettle();
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(find.text('95% CI / decade'), findsOneWidget);
        expectLayout(tester, twoColumns: width >= 1000, viewportWidth: width);
        await tester.ensureVisible(find.byType(ExcludedYearsPanel));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'expanded details and selected tab survive desktop/tablet resizing',
    (tester) async {
      setWidth(tester, 1280);
      addTearDown(tester.view.reset);
      final api = service();
      addTearDown(api.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: DashboardScreen(service: api),
        ),
      );
      await tester.pumpAndSettle();
      await openTab(tester, Icons.water_drop_outlined);
      final toggle = find.byKey(const ValueKey('climate_trend_details_toggle'));
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      for (final width in [1024.0, 768.0, 600.0, 1280.0]) {
        setWidth(tester, width);
        await tester.pumpAndSettle();
        expect(find.text('Annual Precipitation Trend'), findsOneWidget);
        expect(find.text('95% CI / decade'), findsOneWidget);
        expectLayout(tester, twoColumns: width >= 1000, viewportWidth: width);
      }
    },
  );
}
