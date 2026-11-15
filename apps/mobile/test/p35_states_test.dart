import 'dart:async';
import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/config.dart';
import 'package:mobile/app/theme.dart';
import 'package:mobile/models/climate_analysis.dart';
import 'package:mobile/screens/dashboard_screen.dart';
import 'package:mobile/services/climate_api_service.dart';
import 'package:mobile/widgets/annual_chart.dart';
import 'package:mobile/widgets/climate_trend_card.dart';
import 'package:mobile/widgets/excluded_years_panel.dart';
import 'package:mobile/widgets/location_form.dart';
import 'package:mobile/widgets/seasonal_trend_card.dart';

import 'fixtures/scientific_fixture.dart';

final _kFakeResponse = jsonEncode(
  withScientificSections(
    jsonDecode('''
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
    "month_wise": "Exploratory per-month MK with Holm-Bonferroni correction",
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
    }
  }
}
''') as Map<String, dynamic>,
  ),
);

class ControlledService extends ClimateApiService {
  final requests = <({double lat, double lon, int start, int end})>[];
  final responses = <Completer<ClimateAnalysis>>[];

  @override
  Future<ClimateAnalysis> fetchAnalysis({
    required double latitude,
    required double longitude,
    required int startYear,
    required int endYear,
  }) {
    requests.add((
      lat: latitude,
      lon: longitude,
      start: startYear,
      end: endYear,
    ));
    final pending = Completer<ClimateAnalysis>();
    responses.add(pending);
    return pending.future;
  }
}

ClimateAnalysis result({bool insufficient = false, bool empty = false}) {
  final data = jsonDecode(_kFakeResponse) as Map<String, dynamic>;
  if (insufficient || empty) {
    final temperature = data['temperature'];
    temperature['annual_trend']['status'] = 'insufficient_data';
    temperature['annual_trend']['n_observations'] = empty ? 0 : 2;
    temperature['annual']['excluded_years'] = [
      {'year': 2002, 'valid_months': 11},
    ];
    // Leave valid seasonal results available despite insufficient annual data.
    if (empty) temperature['annual']['series'] = [];
  }
  return ClimateAnalysis.fromJson(data);
}

Future<void> pumpDashboard(
  WidgetTester tester,
  ControlledService service,
  double width,
) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(service.close);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: DashboardScreen(service: service),
    ),
  );
  await tester.pump();
}

Future<void> selectTab(WidgetTester tester, IconData icon) async {
  await tester.tap(find.byIcon(icon).first);
  await tester.pump();
}

void expectNoOverflow(WidgetTester tester, double width) {
  for (final element in find.byType(RichText).evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    final rect = paragraph.localToGlobal(Offset.zero) & paragraph.size;
    expect(rect.left, greaterThanOrEqualTo(-0.01));
    expect(rect.right, lessThanOrEqualTo(width + 0.01));
  }
  expect(tester.takeException(), isNull);
}

void main() {
  test('request timeout remains 45 seconds', () {
    expect(requestTimeout, const Duration(seconds: 45));
  });

  for (final width in [360.0, 600.0, 768.0, 1024.0, 1280.0]) {
    testWidgets('loading to success at $width', (tester) async {
      final service = ControlledService();
      await pumpDashboard(tester, service, width);
      expect(
        find.text('Fetching climate data from NASA POWER…'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('overview_findings')), findsNothing);
      expect(service.requests, hasLength(1));
      expectNoOverflow(tester, width);
      service.responses.single.complete(result());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('overview_findings')), findsOneWidget);
      expect(find.text('Fetching climate data from NASA POWER…'), findsNothing);
      expectNoOverflow(tester, width);
    });

    for (final kind in ApiErrorKind.values) {
      testWidgets('loading to $kind with long details at $width', (
        tester,
      ) async {
        final service = ControlledService();
        await pumpDashboard(tester, service, width);
        final message = List.filled(
          12,
          'Service details preserved for this failed request.',
        ).join(' ');
        service.responses.single.completeError(ApiException(kind, message));
        await tester.pumpAndSettle();
        expect(find.text('Failed to load data'), findsOneWidget);
        expect(find.text(message), findsOneWidget);
        final label = switch (kind) {
          ApiErrorKind.connection => 'Connection unavailable',
          ApiErrorKind.timeout => 'Request timed out',
          ApiErrorKind.http => 'Service error',
          ApiErrorKind.invalidResponse => 'Unexpected response',
        };
        expect(find.text(label), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
        expect(find.byKey(const ValueKey('overview_findings')), findsNothing);
        await tester.pump(const Duration(seconds: 1));
        expect(service.requests, hasLength(1)); // No automatic retry.
        expectNoOverflow(tester, width);
      });
    }

    testWidgets(
      'mixed and empty annual results preserve seasonal data at $width',
      (tester) async {
        final service = ControlledService();
        await pumpDashboard(tester, service, width);
        service.responses.single.complete(
          result(insufficient: true, empty: true),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('0 of 10 years'), findsOneWidget);
        await selectTab(tester, Icons.thermostat_outlined);
        await tester.pumpAndSettle();
        expect(find.text('Annual Mean Temperature'), findsOneWidget);
        expect(find.text('°C'), findsOneWidget);
        expect(find.text('0 annual observations available.'), findsOneWidget);
        expect(find.byType(LineChart), findsNothing);
        expect(
          find.textContaining('0 / 10 observations required'),
          findsOneWidget,
        );
        expect(find.text('2002 · 11/12 valid months'), findsOneWidget);
        final annualCard = find.byType(ClimateTrendCard);
        expect(
          find.descendant(of: annualCard, matching: find.text("SEN'S SLOPE")),
          findsNothing,
        );
        expect(
          find.descendant(
            of: annualCard,
            matching: find.text('Statistical details'),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byType(SeasonalTrendCard),
            matching: find.text('p-value'),
          ),
          findsOneWidget,
        );
        expect(find.text('Retry'), findsNothing);
        expectNoOverflow(tester, width);
        await selectTab(tester, Icons.water_drop_outlined);
        await tester.pumpAndSettle();
        expect(find.byType(LineChart), findsOneWidget);
        expect(find.text("SEN'S SLOPE"), findsOneWidget);
        expectNoOverflow(tester, width);
      },
    );
  }

  testWidgets(
    'insufficient annual analysis retains observed chart and exclusions',
    (tester) async {
      final service = ControlledService();
      await pumpDashboard(tester, service, 768);
      service.responses.single.complete(result(insufficient: true));
      await tester.pumpAndSettle();
      await selectTab(tester, Icons.thermostat_outlined);
      await tester.pumpAndSettle();
      expect(find.byType(AnnualChart), findsOneWidget);
      expect(find.byType(LineChart), findsOneWidget);
      expect(find.byType(ExcludedYearsPanel), findsOneWidget);
      expect(
        find.textContaining('2 / 10 observations required'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsNothing);
    },
  );

  testWidgets(
    'new query and retry preserve submitted parameters, tab and unsent edits',
    (tester) async {
      final service = ControlledService();
      await pumpDashboard(tester, service, 1280);
      service.responses.single.complete(result());
      await tester.pumpAndSettle();
      await selectTab(tester, Icons.water_drop_outlined);
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      for (final (i, value) in ['8.5', '80.25', '1995', '2020'].indexed) {
        await tester.enterText(fields.at(i), value);
      }
      await tester.tap(find.text('Analyze'));
      await tester.pump();
      expect(find.byType(AnnualChart), findsNothing); // Old results are hidden.
      expect(service.requests.last, (
        lat: 8.5,
        lon: 80.25,
        start: 1995,
        end: 2020,
      ));
      expect(
        tester.widget<LocationForm>(find.byType(LocationForm)).loading,
        isTrue,
      );
      service.responses.last.completeError(
        const ApiException(ApiErrorKind.connection, 'Connection interrupted.'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AnnualChart), findsNothing);
      // Unsubmitted edits must survive retry; retry still uses submitted values.
      await tester.enterText(fields.first, '9.25');
      await tester.ensureVisible(find.text('Retry'));
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(find.text('Failed to load data'), findsNothing);
      expect(
        find.text('Fetching climate data from NASA POWER…'),
        findsOneWidget,
      );
      expect(service.requests, hasLength(3));
      expect(service.requests.last, service.requests[1]);
      service.responses.last.complete(result());
      await tester.pumpAndSettle();
      expect(find.text('Annual Precipitation Total'), findsOneWidget);
      final contents = tester
          .widgetList<TextFormField>(fields)
          .map((f) => f.controller!.text)
          .toList();
      expect(contents, ['9.25', '80.25', '1995', '2020']);
      expect(service.requests, hasLength(3));
    },
  );
}
