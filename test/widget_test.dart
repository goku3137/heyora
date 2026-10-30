import 'package:flutter_test/flutter_test.dart';
import 'package:heyora/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('HeyOra smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const HeyOraApp());
    expect(find.text('HeyOra'), findsOneWidget);
  });
}
