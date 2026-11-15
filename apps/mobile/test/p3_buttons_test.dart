import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/app/theme.dart';
import 'package:mobile/screens/dashboard_screen.dart';
import 'package:mobile/services/climate_api_service.dart';
import 'package:mobile/widgets/location_form.dart';

/// Rendered fill colour of the ElevatedButton that contains [label].
Color? _buttonFill(WidgetTester tester, String label) {
  final button = find.ancestor(
    of: find.text(label),
    matching: find.bySubtype<ElevatedButton>(),
  );
  expect(button, findsOneWidget);
  final material = find.descendant(of: button, matching: find.byType(Material));
  return tester.widget<Material>(material.first).color;
}

void main() {
  testWidgets('Analyze button uses the cyan accent, not blue', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(body: LocationForm(onAnalyze: (a, b, c, d) {})),
      ),
    );
    final fill = _buttonFill(tester, 'Analyze');
    expect(fill, AppColors.cyan);
    expect(fill, isNot(AppColors.blue));
  });

  testWidgets('Retry button uses the cyan accent, not blue', (tester) async {
    final service = ClimateApiService(
      client: MockClient((_) async => http.Response('error', 500)),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: DashboardScreen(service: service),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    final fill = _buttonFill(tester, 'Retry');
    expect(fill, AppColors.cyan);
    expect(fill, isNot(AppColors.blue));
  });
}
