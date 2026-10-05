import 'package:flutter_test/flutter_test.dart';
import 'package:maizedoctor/main.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('Flutter and Provider can render the development scaffold', (
    tester,
  ) async {
    await tester.pumpWidget(
      Provider<String>(create: (_) => 'environment', child: const MainApp()),
    );

    expect(find.text('MAIZEDOCTOR development scaffold'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
