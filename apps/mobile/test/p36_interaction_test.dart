import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme.dart';
import 'package:mobile/models/climate_analysis.dart';
import 'package:mobile/widgets/app_shell.dart';
import 'package:mobile/widgets/location_form.dart';
import 'package:mobile/widgets/climate_trend_card.dart';

TrendResult _trend({
  bool? significant = true,
  double? slopePerDecade = 0.25,
  String status = 'ok',
  String direction = 'increasing',
  String units = '°C',
  String? slopeUnitsPerDecade,
  int nObservations = 10,
  double? pOriginal,
  double? pHamedRao,
  int hamedRaoLag = 1,
  double? kendallTau = 0.45,
  double? ciLow,
  double? ciHigh,
  String ci95Note = '95% CI',
  String? interpretation,
}) => TrendResult(
  status: status,
  nObservations: nObservations,
  minObservationsRequired: 10,
  valueUnits: units,
  alpha: 0.05,
  direction: direction,
  significant: status == 'ok' ? significant : null,
  pValueOriginal: status == 'ok'
      ? (pOriginal ?? (significant == true ? 0.004 : 0.42))
      : null,
  pValueHamedRao: status == 'ok'
      ? (pHamedRao ?? (significant == true ? 0.008 : 0.48))
      : null,
  hamedRaoLag: hamedRaoLag,
  kendallTau: status == 'ok' ? kendallTau : null,
  senSlopePerDecade: status == 'ok' ? slopePerDecade : null,
  slopeUnitsPerDecade: slopeUnitsPerDecade ?? '$units/decade',
  ci95LowPerDecade: status == 'ok' && slopePerDecade != null
      ? (ciLow ?? slopePerDecade - 0.1)
      : null,
  ci95HighPerDecade: status == 'ok' && slopePerDecade != null
      ? (ciHigh ?? slopePerDecade + 0.1)
      : null,
  ci95Note: ci95Note,
  interpretation:
      interpretation ??
      (significant == true ? 'Significant trend.' : 'No significant trend.'),
);

Future<void> pumpForm(
  WidgetTester tester, {
  double width = 599,
  double height = 900,
  double scale = 1,
  void Function(double, double, int, int)? onAnalyze,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: AppShell(
        selectedIndex: 0,
        onDestinationSelected: (_) {},
        child: LocationForm(
          compactMode: true,
          onAnalyze: onAnalyze ?? (a, b, c, d) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> edit(WidgetTester tester) async {
  if (find.text('Edit').evaluate().isNotEmpty) {
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
  }
}

void main() {
  for (final widths in [
    [599.0, 600.0, 599.0],
    [600.0, 599.0, 600.0],
    [999.0, 1000.0, 999.0],
  ]) {
    testWidgets('form controller and drafts survive $widths', (tester) async {
      var submitted = false;
      await pumpForm(
        tester,
        width: widths.first,
        onAnalyze: (a, b, c, d) => submitted = true,
      );
      await edit(tester);
      final fields = find.byType(TextFormField);
      final controllers = tester
          .widgetList<TextFormField>(fields)
          .map((f) => f.controller)
          .toList();
      for (final (index, value) in ['8.25', '80.75', '1990', '2020'].indexed) {
        await tester.enterText(fields.at(index), value);
      }
      for (final width in widths.skip(1)) {
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpAndSettle();
        await edit(tester);
        expect(
          tester
              .widgetList<TextFormField>(fields)
              .map((f) => f.controller)
              .toList(),
          controllers,
        );
        expect(
          tester
              .widgetList<TextFormField>(fields)
              .map((f) => f.controller!.text)
              .toList(),
          ['8.25', '80.75', '1990', '2020'],
        );
        expect(submitted, isFalse);
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('short landscape shell keeps navigation and form reachable', (
    tester,
  ) async {
    await pumpForm(tester, width: 768, height: 320);
    expect(find.byType(NavigationRail), findsOneWidget);
    await tester.ensureVisible(find.text('Analyze'));
    await tester.pumpAndSettle();
    expect(find.text('Analyze').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Edit and Collapse have practical bounds and keyboard activation',
    (tester) async {
      var submissions = 0;
      await pumpForm(
        tester,
        width: 360,
        onAnalyze: (a, b, c, d) => submissions++,
      );
      for (final label in ['Edit', 'Collapse']) {
        final button = find.ancestor(
          of: find.text(label),
          matching: find.byType(TextButton),
        );
        final size = tester.getSize(button);
        expect(size.width, greaterThanOrEqualTo(kMinInteractiveDimension));
        expect(size.height, greaterThanOrEqualTo(kMinInteractiveDimension));
        Focus.of(tester.element(find.text(label))).requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
      }
      expect(find.text('Edit'), findsOneWidget);
      expect(submissions, 0);
    },
  );

  testWidgets(
    'details expose collapsed and expanded semantics and support keyboard',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ClimateTrendCard(
                title: 'Annual trend',
                trend: _trend(),
                accentColor: AppColors.cyan,
              ),
            ),
          ),
        ),
      );
      final toggle = find.byKey(const ValueKey('climate_trend_details_toggle'));
      expect(
        tester.getSize(toggle).height,
        greaterThanOrEqualTo(kMinInteractiveDimension),
      );
      expect(
        tester.getSize(toggle).width,
        greaterThanOrEqualTo(kMinInteractiveDimension),
      );
      expect(
        tester.getSemantics(toggle).flagsCollection.isExpanded,
        Tristate.isFalse,
      );
      Focus.of(tester.element(find.text('Statistical details'))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(toggle).flagsCollection.isExpanded,
        Tristate.isTrue,
      );
      expect(find.text('95% CI / decade'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(toggle).flagsCollection.isExpanded,
        Tristate.isFalse,
      );
      expect(find.text('95% CI / decade'), findsNothing);
    },
  );

  for (final width in [360.0, 600.0, 768.0, 1024.0]) {
    testWidgets('enlarged form wraps and validates at $width', (tester) async {
      var calls = 0;
      await pumpForm(
        tester,
        width: width,
        scale: 2,
        onAnalyze: (a, b, c, d) => calls++,
      );
      await edit(tester);
      final fields = find.byType(TextFormField);
      expect(
        tester.getTopLeft(fields.at(2)).dy,
        greaterThan(tester.getTopLeft(fields.first).dy),
      );
      await tester.enterText(fields.first, '100');
      await tester.ensureVisible(find.text('Analyze'));
      await tester.tap(find.text('Analyze'));
      await tester.pumpAndSettle();
      expect(
        tester.state<FormFieldState<String>>(fields.first).errorText,
        '−90 to 90',
      );
      expect(calls, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('resizing preserves valid draft parameters for submission', (
    tester,
  ) async {
    Object? submitted;
    await pumpForm(
      tester,
      width: 599,
      onAnalyze: (a, b, c, d) => submitted = (a, b, c, d),
    );
    await edit(tester);
    for (final (i, value) in ['-8.25', '80.75', '1990', '2020'].indexed) {
      await tester.enterText(find.byType(TextFormField).at(i), value);
    }
    tester.view.physicalSize = const Size(600, 900);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Analyze'));
    await tester.tap(find.text('Analyze'));
    await tester.pumpAndSettle();
    expect(submitted, (-8.25, 80.75, 1990, 2020));
    expect(tester.takeException(), isNull);
  });
}
