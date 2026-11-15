import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/app/theme.dart';
import 'package:mobile/screens/dashboard_screen.dart';
import 'package:mobile/services/climate_api_service.dart';
import 'package:mobile/widgets/location_form.dart';

Map<String, dynamic> _fakeResponse({
  double lat = 7.3,
  double lon = 81.8,
  int startYear = 1981,
  int endYear = 2025,
}) => {
  'location': {
    'latitude': lat,
    'longitude': lon,
    'elevation_m': 50.0,
    'requested_latitude': lat,
    'requested_longitude': lon,
  },
  'dataset': {
    'provider': 'NASA POWER',
    'title': 'Test',
    'sources': ['MERRA2'],
    'time_standard': 'LST',
    'community': 'AG',
  },
  'period': {'start_year': startYear, 'end_year': endYear},
  'methodology': {
    'alpha': 0.05,
    'min_observations': 10,
    'hamed_rao_lag': 1,
    'annual_completeness': '12 months required',
    'significance_basis': 'Hamed-Rao',
    'confidence_interval': '95%',
    'seasonal': 'Seasonal MK',
    'month_wise': 'Per-month MK',
    'baseline': '1991–2020',
    'limitations': ['Model-derived.'],
  },
  'temperature': {
    'annual': {
      'series': [
        {'year': 2000, 'mean_temperature_c': 27.5},
        {'year': 2001, 'mean_temperature_c': 27.8},
      ],
      'method': 'day-weighted mean',
      'excluded_years': [],
    },
    'annual_trend': {
      'status': 'ok',
      'n_observations': 45,
      'min_observations_required': 10,
      'value_units': '°C',
      'alpha': 0.05,
      'direction': 'increasing',
      'significant': true,
      'p_value_original': 0.01,
      'p_value_hamed_rao': 0.01,
      'hamed_rao_lag': 1,
      'kendall_tau': 0.5,
      'sen_slope_per_decade': 0.3,
      'slope_units_per_decade': '°C/decade',
      'ci95_low_per_decade': 0.1,
      'ci95_high_per_decade': 0.5,
      'ci95_note': 'Bootstrap 95% CI',
      'interpretation': 'Significant trend.',
    },
    'seasonal_trend': {
      'status': 'ok',
      'significant': false,
      'p_value': 0.5,
      'sen_slope_per_decade': 0.2,
      'slope_units_per_decade': '°C/decade',
      'direction': 'increasing',
    },
  },
  'precipitation': {
    'annual': {
      'series': [
        {'year': 2000, 'total_mm_per_year': 1400.0},
        {'year': 2001, 'total_mm_per_year': 1500.0},
      ],
      'method': 'monthly rate x days',
      'excluded_years': [],
    },
    'annual_total_trend': {
      'status': 'ok',
      'n_observations': 45,
      'min_observations_required': 10,
      'value_units': 'mm/year',
      'alpha': 0.05,
      'direction': 'decreasing',
      'significant': false,
      'p_value_original': 0.4,
      'p_value_hamed_rao': 0.45,
      'hamed_rao_lag': 1,
      'kendall_tau': -0.2,
      'sen_slope_per_decade': -12.0,
      'slope_units_per_decade': 'mm/year per decade',
      'ci95_low_per_decade': -40.0,
      'ci95_high_per_decade': 15.0,
      'ci95_note': 'Bootstrap 95% CI',
      'interpretation': 'No significant trend.',
    },
    'seasonal_trend': {
      'status': 'ok',
      'significant': false,
      'p_value': 0.6,
      'sen_slope_per_decade': -10.0,
      'slope_units_per_decade': 'mm/year per decade',
      'direction': 'decreasing',
    },
  },
};

ClimateApiService _mockService() {
  final bytes = utf8.encode(jsonEncode(_fakeResponse()));
  return ClimateApiService(
    client: MockClient(
      (_) async => http.Response.bytes(
        bytes,
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    ),
  );
}

Future<void> _pumpForm(
  WidgetTester tester, {
  required double width,
  required bool compactMode,
  double initialLat = 7.3,
  double initialLon = 81.8,
  int initialStartYear = 1981,
  int initialEndYear = 2025,
  bool loading = false,
  void Function(double, double, int, int)? onAnalyze,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: LocationForm(
            onAnalyze: onAnalyze ?? (a, b, c, d) {},
            initialLat: initialLat,
            initialLon: initialLon,
            initialStartYear: initialStartYear,
            initialEndYear: initialEndYear,
            loading: loading,
            compactMode: compactMode,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('P3.3R LocationForm – Phone compact mode (< 600 px)', () {
    for (final width in [320.0, 360.0, 400.0, 599.0]) {
      testWidgets(
        'at ${width.toInt()} px shows collapsed summary with coordinates, period, and Edit button',
        (tester) async {
          await _pumpForm(
            tester,
            width: width,
            compactMode: true,
            initialLat: -33.45,
            initialLon: -70.67,
            initialStartYear: 1990,
            initialEndYear: 2024,
          );

          expect(tester.takeException(), isNull);
          expect(find.text('Location & Period'), findsOneWidget);
          expect(
            find.textContaining('33.45°S, 70.67°W  ·  1990–2024'),
            findsOneWidget,
          );
          expect(find.text('Edit'), findsOneWidget);
          expect(find.byType(TextFormField), findsNothing);
          expect(find.text('Analyze'), findsNothing);
        },
      );
    }

    testWidgets(
      'tapping Edit expands the form fields, validates input, and collapses on valid submit',
      (tester) async {
        double? submittedLat;
        double? submittedLon;
        int? submittedStart;
        int? submittedEnd;

        await _pumpForm(
          tester,
          width: 400,
          compactMode: true,
          onAnalyze: (lat, lon, start, end) {
            submittedLat = lat;
            submittedLon = lon;
            submittedStart = start;
            submittedEnd = end;
          },
        );

        // Initially collapsed.
        expect(find.byType(TextFormField), findsNothing);
        expect(find.text('Edit'), findsOneWidget);

        // Tap Edit to expand.
        await tester.tap(find.text('Edit'));
        await tester.pump();

        expect(find.byType(TextFormField), findsNWidgets(4));
        expect(find.text('Analyze'), findsOneWidget);
        expect(find.text('Collapse'), findsOneWidget);

        // Enter an invalid latitude (> 90) and try to submit -> stays expanded.
        await tester.enterText(find.byType(TextFormField).at(0), '95');
        await tester.tap(find.text('Analyze'));
        await tester.pump();

        expect(submittedLat, isNull);
        expect(find.byType(TextFormField), findsNWidgets(4));
        expect(find.text('−90 to 90'), findsAtLeastNWidgets(2));

        // Enter valid coordinates and period, then submit -> calls onAnalyze and collapses.
        await tester.enterText(find.byType(TextFormField).at(0), '12.5');
        await tester.enterText(find.byType(TextFormField).at(1), '77.6');
        await tester.enterText(find.byType(TextFormField).at(2), '1985');
        await tester.enterText(find.byType(TextFormField).at(3), '2022');
        await tester.tap(find.text('Analyze'));
        await tester.pump();

        expect(submittedLat, 12.5);
        expect(submittedLon, 77.6);
        expect(submittedStart, 1985);
        expect(submittedEnd, 2022);
        expect(find.byType(TextFormField), findsNothing);
        expect(find.text('Edit'), findsOneWidget);
      },
    );

    testWidgets('tapping Collapse hides fields without submitting', (
      tester,
    ) async {
      var submitted = false;
      await _pumpForm(
        tester,
        width: 360,
        compactMode: true,
        onAnalyze: (a, b, c, d) => submitted = true,
      );

      await tester.tap(find.text('Edit'));
      await tester.pump();
      expect(find.byType(TextFormField), findsNWidgets(4));

      await tester.tap(find.text('Collapse'));
      await tester.pump();

      expect(submitted, isFalse);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('Edit'), findsOneWidget);
    });
  });

  group('P3.3R LocationForm – Tablet & Desktop compact horizontal mode (>= 600 px)', () {
    for (final width in [600.0, 768.0, 1024.0, 1280.0]) {
      testWidgets(
        'at ${width.toInt()} px renders all four fields and Analyze button in a single horizontal row without overflow',
        (tester) async {
          await _pumpForm(tester, width: width, compactMode: true);

          expect(tester.takeException(), isNull);
          expect(find.byType(TextFormField), findsNWidgets(4));
          expect(find.text('Analyze'), findsOneWidget);
          expect(find.text('Edit'), findsNothing);

          // All four fields share the same top Y coordinate in the horizontal row.
          final y0 = tester.getTopLeft(find.byType(TextFormField).at(0)).dy;
          final y1 = tester.getTopLeft(find.byType(TextFormField).at(1)).dy;
          final y2 = tester.getTopLeft(find.byType(TextFormField).at(2)).dy;
          final y3 = tester.getTopLeft(find.byType(TextFormField).at(3)).dy;
          expect(y1, equals(y0));
          expect(y2, equals(y0));
          expect(y3, equals(y0));
        },
      );
    }

    testWidgets(
      'horizontal mode preserves validation and submission without overflow when error text appears',
      (tester) async {
        double? submittedLat;
        await _pumpForm(
          tester,
          width: 768,
          compactMode: true,
          onAnalyze: (lat, lon, start, end) => submittedLat = lat,
        );

        await tester.enterText(find.byType(TextFormField).at(3), '2030');
        await tester.tap(find.text('Analyze'));
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(submittedLat, isNull);
        expect(find.text('≤ 2025'), findsAtLeastNWidgets(2));

        await tester.enterText(find.byType(TextFormField).at(3), '2024');
        await tester.tap(find.text('Analyze'));
        await tester.pump();

        expect(submittedLat, 7.3);
      },
    );
  });

  group('P3.3R DashboardScreen tab-specific LocationForm modes', () {
    testWidgets(
      'on phone (400 px), all exploration destinations use compact summaries and expose the full editor',
      (tester) async {
        tester.view.physicalSize = const Size(400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(),
            home: DashboardScreen(service: _mockService()),
          ),
        );
        await tester.pumpAndSettle();

        // Tab 0 (Overview): collapsed phone summary with Edit button.
        expect(find.text('Edit location'), findsOneWidget);
        expect(find.byType(TextFormField), findsNothing);

        // Temperature starts compact and exposes the same full editor on demand.
        await tester.tap(find.byIcon(Icons.thermostat_outlined));
        await tester.pumpAndSettle();

        expect(find.text('Edit location'), findsOneWidget);
        expect(find.byType(TextFormField), findsNothing);
        await tester.tap(find.text('Edit location'));
        await tester.pumpAndSettle();
        expect(find.byType(TextFormField), findsNWidgets(4));
        expect(find.text('Analyze'), findsOneWidget);
        final tempLatY = tester.getTopLeft(find.byType(TextFormField).at(0)).dy;
        final tempStartY = tester
            .getTopLeft(find.byType(TextFormField).at(2))
            .dy;
        expect(tempStartY, greaterThan(tempLatY));

        await tester.ensureVisible(find.text('Collapse'));
        await tester.tap(find.text('Collapse'));
        await tester.pumpAndSettle();

        // Precipitation also starts compact and exposes all four editor fields.
        await tester.tap(find.byIcon(Icons.water_drop_outlined));
        await tester.pumpAndSettle();
        expect(find.text('Edit location'), findsOneWidget);
        expect(find.byType(TextFormField), findsNothing);
        await tester.tap(find.text('Edit location'));
        await tester.pumpAndSettle();
        expect(find.byType(TextFormField), findsNWidgets(4));
        expect(find.text('Analyze'), findsOneWidget);
        await tester.ensureVisible(find.text('Collapse'));
        await tester.tap(find.text('Collapse'));
        await tester.pumpAndSettle();

        // Switch back to Tab 0 (Overview): collapsed phone summary again.
        await tester.tap(find.byIcon(Icons.dashboard_outlined));
        await tester.pumpAndSettle();

        expect(find.text('Edit location'), findsOneWidget);
        expect(find.byType(TextFormField), findsNothing);
      },
    );
  });
}
