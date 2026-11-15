import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme.dart';
import 'package:mobile/widgets/app_card.dart';
import 'package:mobile/widgets/brand_mark.dart';
import 'package:mobile/widgets/section_header.dart';
import 'package:mobile/widgets/status_pill.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: buildTheme(),
  home: Scaffold(body: Center(child: child)),
);

double _lum(Color c) => c.computeLuminance();

double _contrast(Color a, Color b) {
  final l1 = _lum(a), l2 = _lum(b);
  final hi = l1 > l2 ? l1 : l2, lo = l1 > l2 ? l2 : l1;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('P3.1 tokens & theme', () {
    test('text colours meet WCAG AA on surface and background', () {
      for (final bg in [AppColors.surface, AppColors.background]) {
        expect(_contrast(AppColors.textPrimary, bg), greaterThan(7));
        expect(_contrast(AppColors.textSecondary, bg), greaterThan(4.5));
        expect(_contrast(AppColors.cyan, bg), greaterThan(4.5));
        expect(_contrast(AppColors.amber, bg), greaterThan(4.5));
        expect(_contrast(AppColors.danger, bg), greaterThan(4.5));
      }
      expect(_contrast(AppColors.onAccent, AppColors.cyan), greaterThan(7));
      expect(_contrast(AppColors.onAccent, AppColors.amber), greaterThan(7));
    });

    test('numeric styles use tabular figures', () {
      expect(
        AppText.numeric.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      expect(
        AppText.numericLarge.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    });

    test('theme is dark with cyan primary and amber secondary', () {
      final t = buildTheme();
      expect(t.brightness, Brightness.dark);
      expect(t.colorScheme.primary, AppColors.cyan);
      expect(t.colorScheme.secondary, AppColors.amber);
      expect(t.scaffoldBackgroundColor, AppColors.background);
    });
  });

  group('P3.1 shared components', () {
    testWidgets('AppCard renders child with border and radius', (t) async {
      await t.pumpWidget(_wrap(const AppCard(child: Text('hello'))));
      expect(find.text('hello'), findsOneWidget);
      final box = t.widget<Container>(
        find
            .descendant(
              of: find.byType(AppCard),
              matching: find.byType(Container),
            )
            .first,
      );
      final deco = box.decoration! as BoxDecoration;
      expect(deco.borderRadius, AppRadii.lgAll);
      expect(deco.color, AppColors.surface);
    });

    testWidgets('StatusPill.direction mutes non-significant trends', (t) async {
      await t.pumpWidget(
        _wrap(
          Column(
            children: [
              StatusPill.direction(direction: 'increasing', significant: false),
              StatusPill.direction(direction: 'decreasing', significant: true),
            ],
          ),
        ),
      );
      expect(find.text('Increasing'), findsOneWidget);
      expect(find.text('Decreasing'), findsOneWidget);
      final inc = t.widget<Text>(find.text('Increasing'));
      final dec = t.widget<Text>(find.text('Decreasing'));
      expect(inc.style!.color, AppColors.textSecondary);
      expect(dec.style!.color, AppColors.amber);
    });

    testWidgets('StatusPill.direction renders nothing for none/null', (
      t,
    ) async {
      await t.pumpWidget(
        _wrap(
          Column(
            children: [
              StatusPill.direction(direction: 'none', significant: true),
              StatusPill.direction(direction: null, significant: false),
            ],
          ),
        ),
      );
      expect(find.text('None'), findsNothing);
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('StatusPill.significance has text and icon', (t) async {
      await t.pumpWidget(_wrap(StatusPill.significance(significant: true)));
      expect(find.text('Significant'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('SectionHeader shows eyebrow, title, subtitle, trailing', (
      t,
    ) async {
      await t.pumpWidget(
        _wrap(
          const SectionHeader(
            eyebrow: 'Annual',
            title: 'Temperature',
            subtitle: 'Mean, °C',
            trailing: Icon(Icons.info_outline),
          ),
        ),
      );
      expect(find.text('ANNUAL'), findsOneWidget);
      expect(find.text('Temperature'), findsOneWidget);
      expect(find.text('Mean, °C'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('BrandMark paints without exception at several sizes', (
      t,
    ) async {
      for (final s in [16.0, 32.0, 96.0]) {
        await t.pumpWidget(_wrap(BrandMark(size: s)));
        expect(t.takeException(), isNull);
        expect(t.getSize(find.byType(BrandMark)), Size(s, s));
      }
    });
  });
}
