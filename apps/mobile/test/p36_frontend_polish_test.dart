import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme.dart';
import 'package:mobile/models/climate_analysis.dart';
import 'package:mobile/screens/dashboard_screen.dart';
import 'package:mobile/services/climate_api_service.dart';
import 'package:mobile/widgets/annual_chart.dart';
import 'package:mobile/widgets/climate_trend_card.dart';
import 'package:mobile/widgets/seasonal_trend_card.dart';
import 'package:mobile/widgets/status_pill.dart';
import 'package:mobile/widgets/methodology_panel.dart';
import 'package:mobile/widgets/location_form.dart';

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

final _captureKey = GlobalKey();

class ReviewService extends ClimateApiService {
  final response = Completer<ClimateAnalysis>();
  @override
  Future<ClimateAnalysis> fetchAnalysis({
    required double latitude,
    required double longitude,
    required int startYear,
    required int endYear,
  }) => response.future;
}

ClimateAnalysis fixture({bool empty = false}) {
  final data = jsonDecode(_kFakeResponse) as Map<String, dynamic>;
  data['location']['latitude'] = -89.123456789;
  data['location']['longitude'] = 179.987654321;
  for (final name in ['temperature', 'precipitation']) {
    final variable = data[name];
    variable['annual']['series'] = empty
        ? []
        : [
            for (final year in [
              1981,
              1982,
              1985,
              1990,
              2000,
              2005,
              2010,
              2015,
              2020,
              2025,
            ])
              {
                'year': year,
                if (name == 'temperature')
                  'mean_temperature_c': -12.123456789 + year % 5,
                if (name == 'precipitation') ...{
                  'total_mm_per_year': 123456.789 + year % 10,
                  'mean_rate_mm_per_day': 5.0,
                },
              },
          ];
    variable['annual']['excluded_years'] = [
      {'year': 1983, 'valid_months': 0},
      {'year': 2024, 'valid_months': 11},
    ];
    final trend =
        variable[name == 'temperature' ? 'annual_trend' : 'annual_total_trend'];
    trend['interpretation'] = List.filled(
      8,
      'Backend interpretation preserved with additional explanatory context.',
    ).join(' ');
    trend['significant'] = name == 'temperature';
    trend['n_observations'] = empty ? 0 : 10;
    if (empty) {
      trend['status'] = 'insufficient_data';
      for (final key in [
        'significant',
        'direction',
        'sen_slope_per_decade',
        'p_value_original',
        'p_value_hamed_rao',
        'kendall_tau',
        'ci95_low_per_decade',
        'ci95_high_per_decade',
      ]) {
        trend[key] = null;
      }
      variable['seasonal_trend']['status'] = 'insufficient_data';
      for (final key in [
        'significant',
        'direction',
        'p_value',
        'sen_slope_per_decade',
      ]) {
        variable['seasonal_trend'][key] = null;
      }
    }
  }
  data['methodology']['limitations'] = [
    List.filled(10, 'Backend limitation preserved verbatim.').join(' '),
  ];
  return ClimateAnalysis.fromJson(data);
}

Future<void> pumpReview(
  WidgetTester tester,
  ReviewService service,
  double width,
  double scale, {
  double height = 900,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(service.close);
  await tester.pumpWidget(
    MaterialApp(
      theme: const bool.fromEnvironment('P36_CAPTURE')
          ? buildTheme().copyWith(
              textTheme: buildTheme().textTheme.apply(fontFamily: 'Roboto'),
            )
          : buildTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: RepaintBoundary(
        key: _captureKey,
        child: DashboardScreen(service: service),
      ),
    ),
  );
  await tester.pump();
}

void checkHorizontalBounds(WidgetTester tester, double width) {
  for (final element in find.byType(RichText).evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    final rect = MatrixUtils.transformRect(
      paragraph.getTransformTo(null),
      Offset.zero & paragraph.size,
    );
    expect(
      rect.left,
      greaterThanOrEqualTo(-0.01),
      reason: '${paragraph.text.toPlainText()} ${paragraph.debugCreator}',
    );
    expect(
      rect.right,
      lessThanOrEqualTo(width + 0.01),
      reason: '${paragraph.text.toPlainText()} ${paragraph.debugCreator}',
    );
  }
  // Scientific statuses and excluded-year counts must be fully readable.
  for (final element
      in find
          .descendant(
            of: find.byType(StatusPill),
            matching: find.byType(RichText),
          )
          .evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    expect(
      paragraph.didExceedMaxLines,
      isFalse,
      reason: '${paragraph.text.toPlainText()} ${paragraph.debugCreator}',
    );
  }
  expect(tester.takeException(), isNull);
}

Future<void> captureReview(
  WidgetTester tester,
  double width,
  double scale,
  bool empty,
  String destination,
) async {
  if (!const bool.fromEnvironment('P36_CAPTURE') ||
      empty ||
      scale != 1 ||
      (width != 390 && width != 1280)) {
    return;
  }
  await tester.ensureVisible(find.byType(LocationForm));
  await tester.pumpAndSettle();
  final boundary =
      _captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('/tmp/p36-review-${width.toInt()}-$destination.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  if (const bool.fromEnvironment('P36_CAPTURE')) {
    setUpAll(() async {
      final fonts = Platform.environment['P36_FONT_ROOT']!;
      for (final (family, files) in [
        (
          'Roboto',
          ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf'],
        ),
        ('MaterialIcons', ['MaterialIcons-Regular.otf']),
      ]) {
        final loader = FontLoader(family);
        for (final file in files) {
          loader.addFont(
            File('$fonts/$file')
                .readAsBytes()
                .then((bytes) => ByteData.sublistView(bytes)),
          );
        }
        await loader.load();
      }
    });
  }
  for (final width in [320.0, 390.0, 599.0, 600.0, 999.0, 1000.0, 1280.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final empty in [false, true]) {
        testWidgets('four destinations at $width scale $scale empty=$empty', (
          tester,
        ) async {
          final service = ReviewService();
          await pumpReview(tester, service, width, scale);
          final data = fixture(empty: empty);
          service.response.complete(data);
          await tester.pumpAndSettle();
          checkHorizontalBounds(tester, width);
          await captureReview(tester, width, scale, empty, 'overview');
          for (final icon in [
            Icons.thermostat_outlined,
            Icons.water_drop_outlined,
            Icons.science_outlined,
          ]) {
            await tester.tap(find.byIcon(icon).first);
            await tester.pumpAndSettle();
            checkHorizontalBounds(tester, width);
            await captureReview(
              tester,
              width,
              scale,
              empty,
              icon == Icons.thermostat_outlined
                  ? 'temperature'
                  : icon == Icons.water_drop_outlined
                  ? 'precipitation'
                  : 'methodology',
            );
            if (icon == Icons.science_outlined) {
              expect(find.byType(MethodologyPanel), findsOneWidget);
              expect(
                find.text(data.methodology.limitations.single),
                findsOneWidget,
              );
            } else {
              expect(find.byType(AnnualChart), findsOneWidget);
              if (!empty) {
                final chart = tester.widget<LineChart>(find.byType(LineChart));
                expect(chart.data.clipData, const FlClipData.vertical());
                expect(
                  chart.data.titlesData.leftTitles.sideTitles.minIncluded,
                  isFalse,
                );
                expect(
                  chart.data.titlesData.leftTitles.sideTitles.maxIncluded,
                  isFalse,
                );
                final trendBar = chart.data.lineBarsData.last;
                expect(trendBar.spots.first.x, 1981);
                expect(trendBar.spots.last.x, 2025);
              }

              expect(find.text('1983 · 0/12 valid months'), findsOneWidget);
              expect(find.text('2024 · 11/12 valid months'), findsOneWidget);
              if (!empty) {
                final card = tester.widget<ClimateTrendCard>(
                  find.byType(ClimateTrendCard),
                );
                expect(
                  card.accentColor,
                  icon == Icons.thermostat_outlined
                      ? AppColors.cyan
                      : AppColors.amber,
                );
                expect(
                  tester
                      .widget<SeasonalTrendCard>(find.byType(SeasonalTrendCard))
                      .accentColor,
                  card.accentColor,
                );
                final toggle = find.byKey(
                  const ValueKey('climate_trend_details_toggle'),
                );
                await tester.ensureVisible(toggle);
                await tester.pumpAndSettle();
                if (find.text('95% CI / decade').evaluate().isEmpty) {
                  await tester.tap(toggle);
                }
                await tester.pumpAndSettle();
                expect(find.text('95% CI / decade'), findsOneWidget);
                checkHorizontalBounds(tester, width);
              } else {
                expect(
                  find.text('0 annual observations available.'),
                  findsOneWidget,
                );
                expect(find.text('Insufficient data'), findsNWidgets(2));
              }
            }
          }
        });
      }
      testWidgets('loading and long error at $width scale $scale', (
        tester,
      ) async {
        final service = ReviewService();
        await pumpReview(tester, service, width, scale);
        expect(
          find.text('Fetching climate data from NASA POWER…'),
          findsOneWidget,
        );
        checkHorizontalBounds(tester, width);
        service.response.completeError(
          ApiException(
            ApiErrorKind.http,
            List.filled(20, 'Long service failure details.').join(' '),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Retry'), findsOneWidget);
        checkHorizontalBounds(tester, width);
      });
    }
  }
  for (final width in [599.0, 600.0, 1000.0]) {
    testWidgets('all destinations in short landscape $width', (tester) async {
      final service = ReviewService();
      await pumpReview(tester, service, width, 1, height: 320);
      service.response.complete(fixture());
      await tester.pumpAndSettle();
      for (final icon in [
        Icons.thermostat_outlined,
        Icons.water_drop_outlined,
        Icons.science_outlined,
      ]) {
        final target = find.byIcon(icon).first;
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pumpAndSettle();
        checkHorizontalBounds(tester, width);
      }
    });
  }
}
