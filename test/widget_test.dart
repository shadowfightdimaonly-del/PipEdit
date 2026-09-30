import 'package:flutter_test/flutter_test.dart';
import 'package:pip_edit/main.dart';

void main() {
  testWidgets('PipEdit opens the editor', (tester) async {
    await tester.pumpWidget(const PipEditApp());

    expect(find.text('PipEdit'), findsOneWidget);
    expect(find.text('main.dart'), findsOneWidget);
    expect(find.text('README.md'), findsOneWidget);
  });
}
