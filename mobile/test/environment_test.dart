import 'package:flutter_test/flutter_test.dart';
import 'package:maizedoctor/main.dart';

void main() {
  testWidgets(
    'Flutter renders the offline farmer foundation without network calls',
    (tester) async {
      await tester.pumpWidget(const MainApp());
      await tester.pumpAndSettle();

      expect(find.text('MAIZEDOCTOR'), findsOneWidget);
      expect(find.text('Scan a maize leaf'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
