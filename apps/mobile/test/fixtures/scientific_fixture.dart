import 'dart:convert';
import 'dart:io';

/// Current backend-generated scientific sections for older presentation fixtures.
/// Existing display-specific annual values and seasonal summary overrides remain
/// deliberate UI scenarios; newly parsed sections use the backend contract.
Map<String, dynamic> withScientificSections(Map<String, dynamic> response) {
  final result = Map<String, dynamic>.from(response);
  final standard = jsonDecode(
    File('test/fixtures/p37_imagery_analysis.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final empty = scientificCase('empty');
  for (final name in ['temperature', 'precipitation']) {
    final variable = Map<String, dynamic>.from(result[name] as Map);
    final summary = variable['seasonal_trend'] as Map<String, dynamic>;
    final source = summary['status'] == 'insufficient_data'
        ? empty[name]
        : standard[name];
    variable['seasonal_trend'] = <String, dynamic>{
      ...source['seasonal_trend'],
      ...summary,
    };
    variable['month_wise_trends'] = source['month_wise_trends'];
    variable['anomalies'] = source['anomalies'];
    result[name] = variable;
  }
  return result;
}

Map<String, dynamic> scientificCase(String name) =>
    (jsonDecode(
          File('test/fixtures/p38_scientific_cases.json').readAsStringSync(),
        ) as Map<String, dynamic>)[name]
        as Map<String, dynamic>;
