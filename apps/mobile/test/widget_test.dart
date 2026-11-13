import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/main.dart';

void main() {
  testWidgets('App shows the project title', (WidgetTester tester) async {
    await tester.pumpWidget(const StoneToStarsApp());
    expect(find.text('Stone to Stars'), findsOneWidget);
  });
}
