import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme.dart';
import 'package:mobile/models/climate_analysis.dart';
import 'package:mobile/widgets/excluded_years_panel.dart';
import 'package:mobile/widgets/seasonal_trend_card.dart';
import 'package:mobile/widgets/status_pill.dart';

SeasonalTrend seasonal({
  String status = 'ok',
  bool? significant = true,
  String? direction = 'increasing',
  double? slope = 0.25,
  double? pValue = 0.00001,
}) => SeasonalTrend(
  status: status,
  significant: significant,
  pValue: pValue,
  senSlopePerDecade: slope,
  slopeUnitsPerDecade: 'mm/year per decade',
  direction: direction,
);

Widget wrap(Widget child) => MaterialApp(
  theme: buildTheme(),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  for (final accent in [AppColors.cyan, AppColors.amber]) {
    for (final direction in ['increasing', 'decreasing']) {
      testWidgets('significant $direction uses variable accent $accent', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrap(
            SeasonalTrendCard(
              title: 'Seasonal trend',
              trend: seasonal(direction: direction),
              accentColor: accent,
            ),
          ),
        );
        final pills = tester.widgetList<StatusPill>(find.byType(StatusPill));
        expect(pills.first.color, accent);
        expect(
          pills.first.label,
          direction == 'increasing' ? 'Increasing' : 'Decreasing',
        );
        expect(find.text('Significant'), findsOneWidget);
        expect(find.text('+0.250 mm/year per decade'), findsOneWidget);
        expect(find.text('< 0.0001'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('non-significant result is muted and explicitly inconclusive', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        SeasonalTrendCard(
          title: 'Seasonal precipitation',
          trend: seasonal(
            significant: false,
            slope: -45.2,
            direction: 'decreasing',
          ),
          accentColor: AppColors.amber,
        ),
      ),
    );
    for (final pill in tester.widgetList<StatusPill>(find.byType(StatusPill))) {
      expect(pill.color, AppColors.textSecondary);
    }
    expect(find.text('Not significant'), findsOneWidget);
    expect(
      find.textContaining('inconclusive and does not imply no change'),
      findsOneWidget,
    );
    expect(find.text('−45.2 mm/year per decade'), findsOneWidget);
  });

  for (final direction in <String?>['none', null]) {
    testWidgets(
      'direction $direction and missing statistics handled without invention',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            SeasonalTrendCard(
              title: 'Seasonal trend',
              trend: seasonal(
                direction: direction,
                significant: null,
                slope: null,
                pValue: null,
              ),
              accentColor: AppColors.cyan,
            ),
          ),
        );
        expect(find.text('Increasing'), findsNothing);
        expect(find.text('Decreasing'), findsNothing);
        expect(find.text('Significance unavailable'), findsOneWidget);
        expect(find.text('p-value'), findsNothing);
        expect(find.text("Sen's slope"), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('insufficient data hides statistical results', (tester) async {
    await tester.pumpWidget(
      wrap(
        SeasonalTrendCard(
          title: 'Seasonal trend',
          trend: seasonal(status: 'insufficient_data'),
          accentColor: AppColors.cyan,
        ),
      ),
    );
    expect(
      find.text('Insufficient data for seasonal trend analysis.'),
      findsOneWidget,
    );
    expect(find.byType(StatusPill), findsNothing);
    expect(find.text('p-value'), findsNothing);
  });

  testWidgets('all exclusions and available valid-month counts are retained', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const ExcludedYearsPanel(
          excludedYears: [
            ExcludedYear(year: 1981, validMonths: 0),
            ExcludedYear(year: 2025, validMonths: 11),
          ],
        ),
      ),
    );
    expect(find.text('1981 · 0/12 valid months'), findsOneWidget);
    expect(find.text('2025 · 11/12 valid months'), findsOneWidget);
    expect(find.textContaining('requires 12 valid months'), findsOneWidget);
    expect(
      tester
          .widgetList<StatusPill>(find.byType(StatusPill))
          .every((p) => p.color == AppColors.amber),
      isTrue,
    );
  });

  testWidgets('empty exclusions hide the panel', (tester) async {
    await tester.pumpWidget(wrap(const ExcludedYearsPanel(excludedYears: [])));
    expect(find.text('Excluded years'), findsNothing);
    expect(find.byType(StatusPill), findsNothing);
  });

  for (final width in [320.0, 360.0, 1200.0]) {
    testWidgets('seasonal and exclusion content fits width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        wrap(
          Column(
            children: [
              SeasonalTrendCard(
                title: 'Seasonal Precipitation Trend',
                trend: seasonal(significant: false, slope: -123.4),
                accentColor: AppColors.amber,
              ),
              ExcludedYearsPanel(
                excludedYears: List.generate(
                  45,
                  (i) => ExcludedYear(year: 1981 + i, validMonths: i % 12),
                ),
              ),
            ],
          ),
        ),
      );
      expect(find.byType(StatusPill), findsNWidgets(47));
      expect(tester.takeException(), isNull);
    });
  }
}
