import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/models/climate_analysis.dart';
import 'package:mobile/services/climate_api_service.dart';

import 'fixtures/scientific_fixture.dart';

Map<String, dynamic> standardResponse() => jsonDecode(
  File('test/fixtures/p37_imagery_analysis.json').readAsStringSync(),
) as Map<String, dynamic>;

void main() {
  test(
    'complete standard response retains reference period, means and counts',
    () {
      final raw = standardResponse();
      final analysis = ClimateAnalysis.fromJson(raw);
      for (final variable in [analysis.temperature, analysis.precipitation]) {
        final anomalies = variable.anomalies!;
        final baseline = anomalies.baseline!;
        expect(anomalies.hasResult, isTrue);
        expect(baseline.kind, 'standard_1991_2020');
        expect(baseline.startYear, 1991);
        expect(baseline.endYear, 2020);
        expect(baseline.isStandardReferencePeriod, isTrue);
        expect(baseline.minObservationsPerMonthRequired, 24);
        expect(baseline.observationsPerMonth[1], 30);
        expect(baseline.observationsPerMonth[12], 29);
        expect(
          anomalies.normals.map((n) => n.month),
          orderedEquals(List.generate(12, (i) => i + 1)),
        );
        expect(anomalies.normals.last.nObservations, 29);
        expect(anomalies.anomalies, hasLength(537));
      }
      final source = raw['temperature']['anomalies'];
      final parsed = analysis.temperature.anomalies!;
      expect(parsed.normals.first.normal, source['normals'][0]['normal']);
      expect(parsed.baseline!.note, source['baseline']['note']);
      expect(parsed.note, source['note']);
      final keys = parsed.anomalies.map((a) => a.year * 100 + a.month).toList();
      expect(keys, orderedEquals([...keys]..sort()));
      expect(keys, isNot(contains(198312)));
    },
  );

  test(
    'custom baseline uses actual years rather than standard-period defaults',
    () {
      for (final parse in [
        VariableAnalysis.temperature,
        VariableAnalysis.precipitation,
      ]) {
        final name = parse == VariableAnalysis.temperature
            ? 'temperature'
            : 'precipitation';
        final variable = parse(scientificCase('custom')[name]);
        final baseline = variable.anomalies!.baseline!;
        expect(baseline.kind, 'custom_reference');
        expect(baseline.startYear, 1981);
        expect(baseline.endYear, 1992);
        expect(baseline.isStandardReferencePeriod, isFalse);
        expect(baseline.minObservationsPerMonthRequired, 10);
        expect(baseline.observationsPerMonth.values, everyElement(12));
        expect(variable.anomalies!.normals.first.nObservations, 12);
        expect(variable.anomalies!.anomalies, hasLength(144));
        expect(
          variable.anomalies!.baseline!.note,
          contains('NOT the 1991-2020'),
        );
      }
    },
  );

  test(
    'insufficient baseline preserves available years and counts, no anomalies',
    () {
      final variable = VariableAnalysis.temperature(
        scientificCase('insufficient')['temperature'],
      );
      final a = variable.anomalies!;
      expect(a.status, 'insufficient_data');
      expect(a.hasResult, isFalse);
      expect(a.baseline!.startYear, 2001);
      expect(a.baseline!.endYear, 2002);
      expect(a.baseline!.observationsPerMonth.values, everyElement(2));
      expect(a.normals, isEmpty);
      expect(a.anomalies, isEmpty);
      expect(a.note, contains('No anomalies computed'));
      expect(variable.seasonal.nObservations, 24);
      expect(variable.seasonal.pValue, isNull);
    },
  );

  test('empty observations preserve null baseline years and unavailable statistics', () {
    final variable = VariableAnalysis.temperature(
      scientificCase('empty')['temperature'],
    );
    expect(variable.anomalies!.baseline!.startYear, isNull);
    expect(variable.anomalies!.baseline!.endYear, isNull);
    expect(
      variable.anomalies!.baseline!.observationsPerMonth.values,
      everyElement(0),
    );
    expect(variable.anomalies!.normals, isEmpty);
    expect(variable.anomalies!.anomalies, isEmpty);
    expect(variable.seasonal.nObservations, 0);
    expect(variable.seasonal.senSlopePerYear, isNull);
    for (final month in variable.monthWiseTrends!.months) {
      expect(month.trend.hasResult, isFalse);
      expect(month.trend.significant, isNull);
      expect(month.trend.significantOriginal, isNull);
      expect(month.pValueHamedRaoHolm, isNull);
      expect(month.significantAfterHolm, isNull);
    }
  });

  test('optional nullable baseline, adjusted significance and accumulation remain unavailable', () {
    final raw =
        scientificCase('zero_missing')['temperature'] as Map<String, dynamic>;
    final anomaly = raw['anomalies'] as Map<String, dynamic>;
    anomaly['baseline'] = null;
    expect(AnomalyResult.fromJson(anomaly).baseline, isNull);
    anomaly.remove('baseline');
    expect(AnomalyResult.fromJson(anomaly).baseline, isNull);
    final record = anomaly['anomalies'][0] as Map<String, dynamic>;
    record.remove('anomaly_accumulated_mm');
    expect(AnomalyRecord.fromJson(record).anomalyAccumulatedMm, isNull);
    final month = raw['month_wise_trends']['months'][0] as Map<String, dynamic>;
    month.remove('p_value_hamed_rao_holm');
    month['significant_after_holm'] = null;
    expect(MonthTrend.fromJson(month).pValueHamedRaoHolm, isNull);
    expect(MonthTrend.fromJson(month).significantAfterHolm, isNull);
  });

  test('real zero anomalies survive while missing months remain absent', () {
    final variable = VariableAnalysis.temperature(
      scientificCase('zero_missing')['temperature'],
    );
    final a = variable.anomalies!;
    expect(a.hasResult, isTrue);
    expect(a.anomalies, hasLength(143));
    expect(a.anomalies.every((r) => r.anomaly == 0), isTrue);
    expect(a.anomalies.every((r) => r.anomalyAccumulatedMm == null), isTrue);
    expect(a.anomalies.any((r) => r.year == 1981 && r.month == 2), isFalse);
    expect(a.baseline!.observationsPerMonth[2], 11);
    expect(a.normals.singleWhere((n) => n.month == 2).nObservations, 11);
    expect(a.anomalies.first.value, 20.25);
    expect(a.anomalies.first.normal, 20.25);
  });

  test('temperature uses degC, precipitation uses rate and accumulated mm', () {
    final json = scientificCase('custom');
    final t = VariableAnalysis.temperature(json['temperature']).anomalies!;
    final p = VariableAnalysis.precipitation(json['precipitation']).anomalies!;
    expect(t.valueUnits, 'degC');
    expect(t.anomalyUnits, 'degC');
    expect(p.valueUnits, 'mm/day');
    expect(p.anomalyUnits, 'mm/day');
    final feb = p.anomalies.singleWhere((a) => a.year == 1984 && a.month == 2);
    expect(feb.anomaly, closeTo(-0.0125, 1e-10));
    expect(feb.anomalyAccumulatedMm, closeTo(feb.anomaly * 29, 1e-10));
    expect(feb.normal, closeTo(4.5275, 1e-10));
    final zero = VariableAnalysis.precipitation(
      scientificCase('zero_missing')['precipitation'],
    ).anomalies!;
    expect(zero.anomalies.first.anomalyAccumulatedMm, 0);
  });

  test('twelve month-wise tests retain original, corrected and Holm results separately', () {
    final raw = scientificCase('custom')['temperature'] as Map<String, dynamic>;
    final months = VariableAnalysis.temperature(raw).monthWiseTrends!;
    expect(months.exploratory, isTrue);
    expect(months.note, raw['month_wise_trends']['note']);
    expect(months.correction, contains('Holm-Bonferroni'));
    expect(
      months.months.map((m) => m.month),
      orderedEquals(List.generate(12, (i) => i + 1)),
    );
    final january = months.months.first;
    expect(
      january.trend.pValueHamedRao,
      closeTo(0.00037918891186072834, 1e-12),
    );
    expect(january.pValueHamedRaoHolm, closeTo(0.00455026694232874, 1e-12));
    expect(january.trend.significantOriginal, isTrue);
    expect(january.trend.significant, isTrue);
    expect(january.significantAfterHolm, isTrue);
    // Twelve equal raw p-values of .04 have Holm-adjusted p-values of .48.
    // This isolates parsing of differing significance flags, without recomputing
    // or treating an adjusted result as the original test result.
    for (final month in raw['month_wise_trends']['months']) {
      month['trend']['p_value_original'] = 0.02;
      month['trend']['p_value_hamed_rao'] = 0.04;
      month['p_value_hamed_rao_holm'] = 0.48;
      month['significant_after_holm'] = false;
    }
    final corrected =
        raw['month_wise_trends']['months'][0] as Map<String, dynamic>;
    final parsed = MonthTrend.fromJson(corrected);
    expect(parsed.trend.pValueOriginal, 0.02);
    expect(parsed.trend.pValueHamedRao, 0.04);
    expect(parsed.trend.significant, isTrue);
    expect(parsed.pValueHamedRaoHolm, 0.48);
    expect(parsed.significantAfterHolm, isFalse);
  });

  test(
    'seasonal metadata, incomplete counts and caveats are retained verbatim',
    () {
      final raw =
          scientificCase('missing')['temperature'] as Map<String, dynamic>;
      final variable = VariableAnalysis.temperature(raw);
      final s = variable.seasonal;
      expect(s.hasResult, isFalse);
      expect(s.nObservations, 140);
      expect(s.observationsPerMonth![1], 9);
      expect(s.observationsPerMonth![2], 11);
      expect(s.observationsPerMonth![12], 12);
      expect(s.minObservationsPerMonthRequired, 10);
      expect(s.method, raw['seasonal_trend']['method']);
      expect(s.valueUnits, 'degC');
      expect(s.alpha, 0.05);
      expect(s.autocorrelationAdjusted, isFalse);
      expect(s.interpretation, raw['seasonal_trend']['interpretation']);
      expect(s.interpretation, contains('Insufficient'));
      expect(s.mkS, isNull);
      expect(s.varS, isNull);
      expect(s.z, isNull);
      expect(s.significant, isNull);
      final january = variable.monthWiseTrends!.months.first;
      expect(january.trend.nObservations, 9);
      expect(january.pValueHamedRaoHolm, isNull);
      expect(january.significantAfterHolm, isNull);
      expect(variable.monthWiseTrends!.months[1].trend.hasResult, isTrue);
      final completeRaw = scientificCase('custom')['temperature'];
      final complete = SeasonalTrend.fromJson(completeRaw['seasonal_trend']);
      expect(complete.mkS, completeRaw['seasonal_trend']['mk_s']);
      expect(complete.varS, completeRaw['seasonal_trend']['var_s']);
      expect(complete.z, completeRaw['seasonal_trend']['z']);
      expect(complete.senSlopePerYear, closeTo(.03, 1e-10));
      expect(complete.slopeUnitsPerYear, 'degC/year');
      expect(
        complete.interpretation,
        completeRaw['seasonal_trend']['interpretation'],
      );
    },
  );

  test(
    'annual trend parsing and previously unexposed fields remain compatible',
    () {
      final raw = standardResponse();
      final variable = VariableAnalysis.temperature(raw['temperature']);
      final trend = variable.trend;
      final json = raw['temperature']['annual_trend'];
      expect(variable.series.first.year, 1981);
      expect(variable.series.first.value, 26.08);
      expect(variable.excludedYears.map((e) => e.year), [1983, 2009, 2024]);
      expect(trend.nObservations, 42);
      expect(trend.significant, isTrue);
      expect(trend.senSlopePerDecade, closeTo(.2, 1e-10));
      expect(trend.pValueOriginal, json['p_value_original']);
      expect(trend.pValueHamedRao, json['p_value_hamed_rao']);
      expect(trend.significantOriginal, json['significant_original']);
      expect(trend.mkS, json['mk_s']);
      expect(trend.zOriginal, json['z_original']);
      expect(trend.zHamedRao, json['z_hamed_rao']);
      expect(trend.senSlopePerYear, json['sen_slope_per_year']);
      expect(trend.slopeUnitsPerYear, json['slope_units_per_year']);
      expect(trend.ci95LowPerYear, json['ci95_low_per_year']);
      expect(trend.ci95HighPerYear, json['ci95_high_per_year']);
      expect(trend.ci95Note, json['ci95_note']);
      expect(trend.interpretation, json['interpretation']);
    },
  );

  final corruptions = <String, void Function(Map<String, dynamic>)>{
    'obsolete month-wise array': (v) => v['month_wise_trends'] = [],
    'obsolete scalar baseline': (v) => v['anomalies']['baseline'] = 27,
    'null anomaly value': (v) =>
        v['anomalies']['anomalies'][0]['anomaly'] = null,
    'null reference mean': (v) => v['anomalies']['normals'][0]['normal'] = null,
    'wrong accumulated type': (v) =>
        v['anomalies']['anomalies'][0]['anomaly_accumulated_mm'] = '0',
    'non-object record': (v) => v['anomalies']['anomalies'][0] = 0,
    'missing scientific section': (v) => v.remove('anomalies'),
    'missing normals array': (v) => v['anomalies'].remove('normals'),
    'invalid status': (v) => v['anomalies']['status'] = 'unavailable',
    'invalid baseline kind': (v) => v['anomalies']['baseline']['kind'] = 'WMO',
    'invalid calendar month': (v) =>
        v['month_wise_trends']['months'][0]['month'] = 13,
    'wrong adjusted flag type': (v) =>
        v['month_wise_trends']['months'][0]['significant_after_holm'] = 'false',
    'invalid monthly count': (v) =>
        v['seasonal_trend']['observations_per_month']['1'] = 1.5,
    'invalid month count key': (v) =>
        v['seasonal_trend']['observations_per_month']['13'] = 1,
    'missing seasonal method': (v) => v['seasonal_trend'].remove('method'),
  };
  for (final entry in corruptions.entries) {
    test('rejects malformed scientific structure: ${entry.key}', () {
      final variable =
          scientificCase('custom')['temperature'] as Map<String, dynamic>;
      entry.value(variable);
      expect(
        () => VariableAnalysis.temperature(variable),
        throwsFormatException,
      );
    });
  }

  for (final invalid in [false, true]) {
    test(
      'API ${invalid ? 'rejects malformed' : 'parses full'} scientific response',
      () async {
        final raw = standardResponse();
        if (invalid) raw['temperature']['month_wise_trends'] = [];
        final service = ClimateApiService(
          client: MockClient(
            (_) async => http.Response.bytes(
              utf8.encode(jsonEncode(raw)),
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );
        addTearDown(service.close);
        final future = service.fetchAnalysis(
          latitude: 7.3,
          longitude: 81.8,
          startYear: 1981,
          endYear: 2025,
        );
        if (invalid) {
          await expectLater(
            future,
            throwsA(
              isA<ApiException>().having(
                (e) => e.kind,
                'kind',
                ApiErrorKind.invalidResponse,
              ),
            ),
          );
        } else {
          final analysis = await future;
          expect(
            analysis.temperature.anomalies!.baseline!.kind,
            'standard_1991_2020',
          );
          expect(analysis.precipitation.monthWiseTrends!.months, hasLength(12));
        }
      },
    );
  }
}
