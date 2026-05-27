// Basic smoke test for Zero Vault app.
import 'package:flutter_test/flutter_test.dart';

import 'package:zero_knowledge_vault/main.dart';

void main() {
  testWidgets('App starts without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const PasswordVaultApp(isSetup: false));
    // Splash screen should be visible
    expect(find.text('ZERO VAULT'), findsOneWidget);
  });
}
