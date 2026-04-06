import 'package:flutter_test/flutter_test.dart';

import 'package:mina_iptv_player/main.dart';

void main() {
  testWidgets('app boots', (WidgetTester tester) async {
    await tester.pumpWidget(const MinaIptvApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.byType(MinaIptvApp), findsOneWidget);
  });
}
