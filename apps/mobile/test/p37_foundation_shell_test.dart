import 'dart:ui' show Tristate;
import 'dart:ui' as ui;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme.dart';
import 'package:mobile/widgets/app_shell.dart';
import 'package:mobile/widgets/location_form.dart';
import 'package:mobile/widgets/observatory_layout.dart';

Future<void> pumpShell(
  WidgetTester tester,
  double width,
  double scale,
  double height,
) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  var selected = 0;
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: StatefulBuilder(
        builder: (context, setState) => AppShell(
          selectedIndex: selected,
          onDestinationSelected: (i) => setState(() => selected = i),
          child: Column(
            children: [
              LocationForm(onAnalyze: (a, b, c, d) {}),
              const SizedBox(height: 800),
              const Text('End of content'),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void expectReadableText(WidgetTester tester, double width) {
  for (final element in find.byType(RichText).evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    final rect = MatrixUtils.transformRect(
      paragraph.getTransformTo(null),
      Offset.zero & paragraph.size,
    );
    expect(
      rect.left,
      greaterThanOrEqualTo(-0.01),
      reason: paragraph.text.toPlainText(),
    );
    expect(
      rect.right,
      lessThanOrEqualTo(width + 0.01),
      reason: paragraph.text.toPlainText(),
    );
    // Navigation labels must wrap in full, rather than disappear into ellipses.
    if (kShellDestinations.any(
      (d) => d.label == paragraph.text.toPlainText(),
    )) {
      expect(
        paragraph.didExceedMaxLines,
        isFalse,
        reason: paragraph.text.toPlainText(),
      );
    }
  }
  expect(tester.takeException(), isNull);
}

void main() {
  // Optional review frames use existing SDK fonts and write only to /tmp.
  // Normal regression runs do not load files or create screenshots.
  if (const bool.fromEnvironment('P37_CAPTURE')) {
    setUpAll(() async {
      final fonts = Platform.environment['P37_FONT_ROOT']!;
      for (final (family, names) in [
        (
          'Roboto',
          ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf'],
        ),
        ('MaterialIcons', ['MaterialIcons-Regular.otf']),
      ]) {
        final loader = FontLoader(family);
        for (final name in names) {
          loader.addFont(
            File('$fonts/$name').readAsBytes().then(ByteData.sublistView),
          );
        }
        await loader.load();
      }
    });
    for (final width in [390.0, 768.0, 1280.0]) {
      testWidgets('capture foundation preview $width', (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(),
            home: RepaintBoundary(
              key: key,
              child: AppShell(
                selectedIndex: 0,
                onDestinationSelected: (_) {},
                child: Column(
                  children: [
                    const ObservatoryHero(
                      eyebrow: 'Earth Observatory',
                      title: 'Explore Earth’s climate',
                      description: 'A clearer view of long-term climate observations and the evidence behind their trends.',
                    ),
                    const ObservatorySection(
                      title: 'Explore a location',
                      description: 'Coordinates and analysis period',
                      child: LocationForm(onAnalyze: _previewAnalyze),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('/tmp/p37-foundation-${width.toInt()}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final width in [
    320.0,
    390.0,
    599.0,
    600.0,
    768.0,
    999.0,
    1000.0,
    1280.0,
  ]) {
    for (final scale in [1.0, 2.0]) {
      for (final height in [900.0, 320.0]) {
        testWidgets(
          'shell at $width x $height text $scale keeps destinations and content reachable',
          (tester) async {
            await pumpShell(tester, width, scale, height);
            expectReadableText(tester, width);
            if (width < 600) {
              expect(find.byType(NavigationBar), findsOneWidget);
              expect(find.byType(NavigationRail), findsNothing);
            } else if (width < 1000) {
              expect(find.byType(NavigationRail), findsOneWidget);
              expect(find.byType(NavigationBar), findsNothing);
            } else {
              expect(find.byType(NavigationRail), findsNothing);
              expect(find.byType(NavigationBar), findsNothing);
              expect(find.text('Stone to Stars'), findsOneWidget);
            }
            for (final index in [1, 2, 3, 0]) {
              final target = width >= 1000
                  ? find.byKey(ValueKey('observatory_nav_$index'))
                  : find.byIcon(kShellDestinations[index].icon).first;
              await tester.ensureVisible(target);
              await tester.pumpAndSettle();
              expect(target.hitTestable(), findsOneWidget);
              await tester.tap(target);
              await tester.pumpAndSettle();
              if (width < 600) {
                expect(
                  tester
                      .widget<NavigationBar>(find.byType(NavigationBar))
                      .selectedIndex,
                  index,
                );
                expect(
                  find.bySemanticsLabel(
                    RegExp(kShellDestinations[index].label),
                  ),
                  findsWidgets,
                );
              } else if (width < 1000) {
                expect(
                  tester
                      .widget<NavigationRail>(find.byType(NavigationRail))
                      .selectedIndex,
                  index,
                );
              } else {
                expect(
                  tester.getSemantics(target).flagsCollection.isSelected,
                  Tristate.isTrue,
                );
                expect(
                  tester.getSemantics(target).flagsCollection.isButton,
                  isTrue,
                );
              }
              expectReadableText(tester, width);
            }
            await tester.ensureVisible(find.text('End of content'));
            await tester.pumpAndSettle();
            final end = tester.getRect(find.text('End of content'));
            expect(
              end.bottom,
              lessThanOrEqualTo(
                width < 600
                    ? tester.getTopLeft(find.byType(NavigationBar)).dy
                    : height,
              ),
            );
            expect(find.text('End of content').hitTestable(), findsOneWidget);
            expectReadableText(tester, width);
          },
        );
      }
    }
  }

  testWidgets('short tablet content starts at the top of the reading area', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(768, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: AppShell(
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          child: const Text('Start of reading area'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Start of reading area')).dy,
      AppSpacing.xl,
    );
  });

  testWidgets(
    'drafts and focused controller survive every navigation layout transition',
    (tester) async {
      await pumpShell(tester, 599, 1, 900);
      final fields = find.byType(TextFormField);
      final controllers = tester
          .widgetList<TextFormField>(fields)
          .map((f) => f.controller)
          .toList();
      await tester.enterText(fields.first, '-12.345678');
      final editable = find.byType(EditableText).first;
      final focus = tester.widget<EditableText>(editable).focusNode;
      for (final width in [600.0, 999.0, 1000.0, 1280.0, 999.0, 599.0]) {
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpAndSettle();
        expect(
          tester
              .widgetList<TextFormField>(fields)
              .map((f) => f.controller)
              .toList(),
          controllers,
        );
        expect(
          tester.widget<TextFormField>(fields.first).controller!.text,
          '-12.345678',
        );
        expect(tester.widget<EditableText>(editable).focusNode, same(focus));
        expect(focus.hasFocus, isTrue);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'desktop top navigation is keyboard accessible and announces selection',
    (tester) async {
      await pumpShell(tester, 1000, 1, 900);
      final target = find.byKey(const ValueKey('observatory_nav_2'));
      Focus.of(
        tester.element(
          find.descendant(of: target, matching: find.text('Precipitation')),
        ),
      ).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(target).flagsCollection.isSelected,
        Tristate.isTrue,
      );
    },
  );

  testWidgets(
    'atmospheric gradients and editorial type retain dark scientific contrast',
    (tester) async {
      expect(
        AppText.editorial.fontSize,
        greaterThan(AppText.display.fontSize!),
      );
      expect(AppText.editorial.fontFamily, 'Roboto');
      expect(
        AppText.numeric.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      for (final background in [
        AppColors.atmosphere,
        AppColors.navigation,
        AppColors.background,
      ]) {
        final b = background.computeLuminance();
        for (final foreground in [
          AppColors.textPrimary,
          AppColors.textSecondary,
        ]) {
          expect(
            (foreground.computeLuminance() + 0.05) / (b + 0.05),
            greaterThanOrEqualTo(4.5),
          );
        }
      }
      await pumpShell(tester, 1280, 1, 900);
      expect(
        tester
            .widgetList<DecoratedBox>(find.byType(DecoratedBox))
            .any(
              (box) =>
                  box.decoration is BoxDecoration &&
                  (box.decoration as BoxDecoration).gradient ==
                      AppGradients.atmosphere,
            ),
        isTrue,
      );
    },
  );

  for (final width in [320.0, 768.0, 1280.0]) {
    testWidgets(
      'future hero and reading section fit $width with enlarged text',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(),
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 900),
                textScaler: TextScaler.linear(2),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const ObservatoryHero(
                        eyebrow: 'Earth Observatory',
                        title: 'Explore Earth’s climate',
                        description: 'Climate observations and the evidence behind their trends.',
                        supporting: Text('Supporting context'),
                      ),
                      const ObservatorySection(
                        title: 'Scientific context',
                        description: 'Available observations',
                        child: Text('Reading content'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Supporting context'), findsOneWidget);
        expect(find.text('Reading content'), findsOneWidget);
        expectReadableText(tester, width);
      },
    );
  }
}

void _previewAnalyze(double lat, double lon, int start, int end) {}
