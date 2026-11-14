import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme.dart';
import 'package:mobile/models/climate_analysis.dart';
import 'package:mobile/widgets/app_card.dart';
import 'package:mobile/widgets/app_shell.dart';
import 'package:mobile/widgets/methodology_panel.dart';

Methodology methodology({bool longText = false, bool limitations = true}) {
  String description(String value) => longText
      ? '$value ${List.filled(12, 'Backend-provided description with additional detail.').join(' ')}'
      : value;
  return Methodology(
    alpha: 0.025,
    minObservations: 15,
    hamedRaoLag: 3,
    annualCompleteness: description('All 12 monthly observations required.'),
    significanceBasis: description('Hamed-Rao corrected p-value.'),
    confidenceInterval: description('Backend confidence interval description.'),
    seasonal: description('Seasonal Mann-Kendall across monthly sub-series.'),
    monthWise: description('Exploratory monthly trends; uncorrected tests.'),
    baseline: description('Backend anomaly baseline description.'),
    limitations: limitations
        ? [
            description('NASA POWER is gridded, not station-observed.'),
            description('Backend-specific limitation, preserved verbatim.'),
          ]
        : [],
  );
}

Future<void> pumpPanel(
  WidgetTester tester,
  Methodology data, {
  double width = 1280,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: AppShell(
        selectedIndex: 3,
        onDestinationSelected: (_) {},
        child: MethodologyPanel(methodology: data),
      ),
    ),
  );
  await tester.pump();
}

void expectSuppliedContent(Methodology data) {
  for (final value in [
    '${data.alpha}',
    '${data.minObservations} years',
    'lag ${data.hamedRaoLag}',
    data.annualCompleteness,
    data.significanceBasis,
    data.confidenceInterval,
    data.seasonal,
    data.monthWise,
    data.baseline,
    ...data.limitations,
  ]) {
    expect(find.text(value), findsOneWidget);
  }
}

void main() {
  testWidgets(
    'all supplied values and limitations remain verbatim and ordered',
    (tester) async {
      final data = methodology();
      await pumpPanel(tester, data);
      expectSuppliedContent(data);
      final text = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(MethodologyPanel),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data)
          .toList();
      final headings = [
        'Statistical Parameters',
        'Significance & CI',
        'Seasonality',
        'Month-wise Trends',
        'Anomaly Baseline',
        'Limitations',
        'Interpreting results',
      ];
      for (var i = 1; i < headings.length; i++) {
        expect(
          text.indexOf(headings[i]),
          greaterThan(text.indexOf(headings[i - 1])),
        );
      }
      expect(
        tester.getTopLeft(find.text(data.limitations[1])).dy,
        greaterThan(tester.getTopLeft(find.text(data.limitations[0])).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'empty limitations omit heading but retain interpretation guidance',
    (tester) async {
      await pumpPanel(tester, methodology(limitations: false));
      expect(find.text('Limitations'), findsNothing);
      expect(find.text('Interpreting results'), findsOneWidget);
      expect(
        find.textContaining('inconclusive and does not imply'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'uses Observatory cards, semantic headings, and informational colours',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpPanel(tester, methodology());
      expect(find.byType(AppCard), findsNWidgets(2));
      final heading = tester.getSemantics(find.text('Statistical Parameters'));
      expect(heading.flagsCollection.isHeader, isTrue);
      for (final text in tester.widgetList<Text>(
        find.descendant(
          of: find.byType(MethodologyPanel),
          matching: find.byType(Text),
        ),
      )) {
        expect(text.style?.color, isNot(AppColors.danger));
      }
      for (final icon in tester.widgetList<Icon>(
        find.descendant(
          of: find.byType(MethodologyPanel),
          matching: find.byType(Icon),
        ),
      )) {
        expect(icon.color, AppColors.amber);
      }
      semantics.dispose();
    },
  );

  testWidgets(
    'guidance distinguishes observation sufficiency and significance states',
    (tester) async {
      final data = methodology();
      await pumpPanel(tester, data);
      expectSuppliedContent(data);
      expect(
        find.textContaining('Insufficient observations means'),
        findsOneWidget,
      );
      expect(
        find.textContaining('no significance result is supplied'),
        findsOneWidget,
      );
      expect(
        find.textContaining('A non-significant result is inconclusive'),
        findsOneWidget,
      );
    },
  );

  for (final width in [360.0, 600.0, 768.0, 1024.0, 1280.0]) {
    for (final longText in [false, true]) {
      testWidgets('panel fits $width px with longText=$longText', (
        tester,
      ) async {
        final data = methodology(longText: longText);
        await pumpPanel(tester, data, width: width);
        expectSuppliedContent(data);
        final parameters = tester.getRect(find.text('Statistical Parameters'));
        final significance = tester.getRect(find.text('Significance & CI'));
        final seasonal = tester.getRect(find.text('Seasonality'));
        if (width >= 1024) {
          expect(seasonal.top, parameters.top);
          expect(seasonal.left, greaterThan(parameters.right));
        } else {
          expect(seasonal.left, parameters.left);
          expect(seasonal.top, greaterThan(significance.bottom));
        }
        final cards = find.byType(AppCard);
        final panel = tester.getRect(cards.first);
        final guidance = tester.getRect(cards.last);
        expect(
          guidance.left,
          panel.left + AppSpacing.cardPadding + AppBorders.width,
        );
        expect(
          guidance.right,
          panel.right - AppSpacing.cardPadding - AppBorders.width,
        );
        expect(tester.getTopLeft(find.text('Limitations')).dx, parameters.left);
        expect(
          tester.getTopLeft(find.text('Limitations')).dy,
          greaterThan(tester.getBottomLeft(find.text(data.baseline)).dy),
        );

        // Check actual laid-out text, including content below the viewport.
        for (final element
            in find
                .descendant(
                  of: find.byType(MethodologyPanel),
                  matching: find.byType(RichText),
                )
                .evaluate()) {
          final paragraph = element.renderObject! as RenderParagraph;
          expect(paragraph.didExceedMaxLines, isFalse);
          final rect = paragraph.localToGlobal(Offset.zero) & paragraph.size;
          expect(rect.left, greaterThanOrEqualTo(panel.left));
          expect(rect.right, lessThanOrEqualTo(panel.right));
        }
        if (longText) {
          expect(
            tester.getSize(find.text(data.seasonal)).height,
            greaterThan(AppText.bodySmall.fontSize! * 2),
          );
        }
        await tester.ensureVisible(find.text('Interpreting results'));
        await tester.pumpAndSettle();
        expect(find.text('Interpreting results').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
