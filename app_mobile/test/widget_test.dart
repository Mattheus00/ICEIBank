import 'package:flutter_test/flutter_test.dart';
import 'package:iceibank_mobile/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('abre tela de login', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const IceiBankApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('ICEIBank'), findsWidgets);
    expect(find.text('Login'), findsOneWidget);
  });
}
