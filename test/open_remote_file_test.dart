import 'dart:async';

import 'package:everkeep/widgets/feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// `openRemoteFile`'s own behaviour — the loading indicator's timing and the
/// error path — stopping short of the actual external-app hand-off (that
/// needs a real platform plugin, which nothing in this suite mocks; every
/// other "open externally" action in the app is tested only up to that same
/// boundary).
void main() {
  Future<void> pumpHost(WidgetTester tester, VoidCallback onPressed) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: onPressed,
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('a quick failure is reported without ever flashing a loader', (
    tester,
  ) async {
    late BuildContext ctx;
    await pumpHost(tester, () {});
    ctx = tester.element(find.byType(ElevatedButton));

    unawaited(
      openRemoteFile(
        ctx,
        fetchUrl: () async => null,
        errorMessage: () => 'Could not reach the server.',
      ),
    );
    await tester.pump(); // let the immediate future resolve
    await tester.pumpAndSettle();

    expect(find.text('Opening…'), findsNothing);
    expect(find.text('Could not reach the server.'), findsOneWidget);
  });

  testWidgets('a missing error message falls back to a generic one', (
    tester,
  ) async {
    late BuildContext ctx;
    await pumpHost(tester, () {});
    ctx = tester.element(find.byType(ElevatedButton));

    unawaited(openRemoteFile(ctx, fetchUrl: () async => null, errorMessage: () => null));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Could not open the file.'), findsOneWidget);
  });

  testWidgets(
    'a fetch that takes a moment shows "Opening…", then clears it',
    (tester) async {
      late BuildContext ctx;
      await pumpHost(tester, () {});
      ctx = tester.element(find.byType(ElevatedButton));

      final completer = Completer<String?>();
      unawaited(
        openRemoteFile(
          ctx,
          fetchUrl: () => completer.future,
          errorMessage: () => 'Could not reach the server.',
        ),
      );

      // Before the loader's own delay elapses, nothing shows yet.
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Opening…'), findsNothing);

      // Past it, with the fetch still pending, the loader appears.
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Opening…'), findsOneWidget);

      // Resolve with no link (so this never reaches the external-open step,
      // which needs a real platform plugin) and the loader clears.
      completer.complete(null);
      await tester.pumpAndSettle();

      expect(find.text('Opening…'), findsNothing);
      expect(find.text('Could not reach the server.'), findsOneWidget);
    },
  );

  testWidgets('a fetch that finishes quickly never shows the loader', (
    tester,
  ) async {
    late BuildContext ctx;
    await pumpHost(tester, () {});
    ctx = tester.element(find.byType(ElevatedButton));

    unawaited(
      openRemoteFile(
        ctx,
        fetchUrl: () => Future.delayed(const Duration(milliseconds: 50), () => null),
        errorMessage: () => 'x',
      ),
    );

    await tester.pump(const Duration(milliseconds: 60));
    expect(find.text('Opening…'), findsNothing, reason: 'resolved before the loader\'s delay');
    await tester.pumpAndSettle();
  });
}
