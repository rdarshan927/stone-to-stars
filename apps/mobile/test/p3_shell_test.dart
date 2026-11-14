import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/app/theme.dart';
import 'package:mobile/screens/dashboard_screen.dart';
import 'package:mobile/services/climate_api_service.dart';
import 'package:mobile/widgets/app_shell.dart';
import 'package:mobile/widgets/brand_mark.dart';

/// Backend always fails: the shell must still render around the error state.
ClimateApiService _failingService() => ClimateApiService(
  client: MockClient((_) async => http.Response('error', 500)),
);

Future<void> _pump(
  WidgetTester tester,
  double width, [
  double height = 800,
]) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: DashboardScreen(service: _failingService()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('P3.2 shellSizeFor breakpoints', () {
    test('maps widths to size classes', () {
      expect(shellSizeFor(320), ShellSize.compact);
      expect(shellSizeFor(599), ShellSize.compact);
      expect(shellSizeFor(600), ShellSize.medium);
      expect(shellSizeFor(999), ShellSize.medium);
      expect(shellSizeFor(1000), ShellSize.expanded);
      expect(shellSizeFor(1920), ShellSize.expanded);
    });

    test('exposes exactly the four destinations in order', () {
      expect(kShellDestinations.map((d) => d.label).toList(), [
        'Overview',
        'Temperature',
        'Precipitation',
        'Methodology',
      ]);
    });
  });

  group('P3.2 compact (phone)', () {
    for (final w in [320.0, 360.0, 400.0, 599.0]) {
      testWidgets(
        'width $w: bottom NavigationBar, brand header, no rail, no overflow',
        (tester) async {
          await _pump(tester, w);
          expect(find.byType(NavigationBar), findsOneWidget);
          expect(find.byType(NavigationRail), findsNothing);
          expect(find.byType(BrandMark), findsOneWidget);
          expect(find.text('Stone to Stars'), findsOneWidget);
          for (final label in [
            'Overview',
            'Temperature',
            'Precipitation',
            'Methodology',
          ]) {
            expect(find.text(label), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  group('P3.2 medium (tablet)', () {
    for (final w in [600.0, 768.0, 999.0]) {
      testWidgets('width $w: slim rail with mark, no bottom bar, no overflow', (
        tester,
      ) async {
        await _pump(tester, w);
        expect(find.byType(NavigationBar), findsNothing);
        final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
        expect(rail.extended, isFalse);
        expect(rail.labelType, NavigationRailLabelType.all);
        expect(rail.destinations.length, 4);
        expect(find.byType(BrandMark), findsOneWidget);
        // Wordmark is reserved for the extended rail / phone header.
        expect(find.text('Stone to Stars'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('P3.2 expanded (desktop)', () {
    for (final w in [1000.0, 1280.0, 1920.0]) {
      testWidgets('width $w: extended rail with wordmark, no overflow', (
        tester,
      ) async {
        await _pump(tester, w, 900);
        expect(find.byType(NavigationBar), findsNothing);
        final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
        expect(rail.extended, isTrue);
        expect(find.byType(BrandMark), findsOneWidget);
        expect(find.text('Stone to Stars'), findsOneWidget);
        expect(find.text('CLIMATE TRENDS'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('content column is capped at the max content width', (
      tester,
    ) async {
      await _pump(tester, 1920, 900);
      final card = tester.getSize(
        find
            .ancestor(
              of: find.text('Location & Period'),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(card.width, lessThanOrEqualTo(AppBreakpoints.contentMaxWidth));
      // ...and it actually uses the cap on a very wide screen.
      expect(card.width, AppBreakpoints.contentMaxWidth);
    });
  });

  group('P3.2 navigation behaviour preserved', () {
    testWidgets('compact: tapping a destination updates selectedIndex', (
      tester,
    ) async {
      await _pump(tester, 400);
      NavigationBar bar() =>
          tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar().selectedIndex, 0);
      await tester.tap(find.byIcon(Icons.thermostat_outlined));
      await tester.pumpAndSettle();
      expect(bar().selectedIndex, 1);
      await tester.tap(find.byIcon(Icons.water_drop_outlined));
      await tester.pumpAndSettle();
      expect(bar().selectedIndex, 2);
      await tester.tap(find.byIcon(Icons.science_outlined));
      await tester.pumpAndSettle();
      expect(bar().selectedIndex, 3);
      await tester.tap(find.byIcon(Icons.dashboard_outlined));
      await tester.pumpAndSettle();
      expect(bar().selectedIndex, 0);
    });

    for (final w in [768.0, 1280.0]) {
      testWidgets('width $w: rail selection updates and survives resize', (
        tester,
      ) async {
        await _pump(tester, w, 900);
        NavigationRail rail() =>
            tester.widget<NavigationRail>(find.byType(NavigationRail));
        expect(rail().selectedIndex, 0);
        await tester.tap(find.byIcon(Icons.science_outlined));
        await tester.pumpAndSettle();
        expect(rail().selectedIndex, 3);

        // Resize to phone width: same tab must stay selected.
        tester.view.physicalSize = const Size(400, 800);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          3,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('location form stays visible on every size class', (
      tester,
    ) async {
      for (final w in [400.0, 768.0, 1280.0]) {
        await _pump(tester, w, 900);
        expect(find.text('Location & Period'), findsOneWidget);
        expect(find.text('Analyze'), findsOneWidget);
      }
    });
  });
}
