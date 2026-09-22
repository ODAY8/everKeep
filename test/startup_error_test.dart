import 'package:everkeep/core/config/startup_error_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a missing backend configuration is shown, not hidden', (
    tester,
  ) async {
    await tester.pumpWidget(
      const StartupErrorApp(
        title: 'Everkeep isn\'t connected yet',
        message: 'SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY are not set.',
      ),
    );

    expect(find.text('Everkeep isn\'t connected yet'), findsOneWidget);
    expect(find.textContaining('SUPABASE_URL'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
