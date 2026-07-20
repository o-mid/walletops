import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:integration_test/integration_test.dart';
import 'package:walletops_mobile/bootstrap.dart';
import 'package:walletops_mobile/core/storage/token_storage.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> snap(String name) async {
    await binding.takeScreenshot(name);
  }

  Future<void> settle(WidgetTester tester, {int pumps = 12}) async {
    for (var i = 0; i < pumps; i++) {
      await tester.pump(const Duration(milliseconds: 350));
    }
  }

  Future<void> tapNav(WidgetTester tester, String label) async {
    final dest = find.widgetWithText(NavigationDestination, label);
    if (dest.evaluate().isNotEmpty) {
      await tester.tap(dest);
    } else {
      await tester.tap(find.text(label).last);
    }
    await settle(tester, pumps: 16);
  }

  testWidgets(
    'demo walkthrough screenshots',
    (tester) async {
      await GetIt.instance.reset();
      await bootstrapApp(
        tokenStorage: InMemoryTokenStorage(),
        apiBase: const String.fromEnvironment(
          'API_BASE',
          defaultValue: 'http://127.0.0.1:8080',
        ),
      );
      await settle(tester, pumps: 18);
      await snap('01-login');

      await tester.tap(find.text('Sign in'));
      await settle(tester, pumps: 22);
      await snap('02-events');

      // Show Rules before the live demo so the viewer sees the matcher.
      await tapNav(tester, 'Rules');
      await snap('03-rules-list');

      final demoRule = find.textContaining('Demo balance watch');
      if (demoRule.evaluate().isNotEmpty) {
        await tester.tap(demoRule.first);
        await settle(tester, pumps: 14);
        await snap('04-rules-detail');
        // Dismiss sheet / return to list.
        final close = find.byIcon(Icons.close);
        if (close.evaluate().isNotEmpty) {
          await tester.tap(close.first);
        } else {
          await tester.tapAt(const Offset(20, 80));
        }
        await settle(tester, pumps: 10);
      } else {
        // Open create sheet to show how a rule is defined.
        final add = find.byTooltip('New rule');
        if (add.evaluate().isNotEmpty) {
          await tester.tap(add);
          await settle(tester, pumps: 12);
          await snap('04-rules-create');
          final cancel = find.text('Cancel');
          if (cancel.evaluate().isNotEmpty) {
            await tester.tap(cancel);
            await settle(tester, pumps: 10);
          }
        }
      }

      await tapNav(tester, 'Events');
      await snap('05-events-ready');

      await tester.tap(find.text('Run live demo'));
      await settle(tester, pumps: 10);
      await snap('06-demo-confirm');

      await tester.tap(find.text('Start demo'));
      await settle(tester, pumps: 12);
      await snap('07-demo-started');

      var sawProcessing = false;
      var sawComplete = false;
      for (var i = 0; i < 100 && !sawComplete; i++) {
        await tester.pump(const Duration(seconds: 1));
        if (!sawProcessing &&
            find.textContaining('PROCESSING').evaluate().isNotEmpty) {
          await snap('08-demo-processing');
          sawProcessing = true;
        }
        if (find.textContaining('Demo complete').evaluate().isNotEmpty) {
          sawComplete = true;
        }
      }
      expect(sawComplete, isTrue, reason: 'guided demo did not finish');
      await settle(tester, pumps: 8);
      await snap('09-demo-complete');

      final eventTitle = find.textContaining('balance drop');
      if (eventTitle.evaluate().isNotEmpty) {
        await tester.tap(eventTitle.first);
      } else {
        await tester.tap(find.text('PROCESSED').first);
      }
      await settle(tester, pumps: 18);
      await snap('10-event-detail');

      // Scroll to show matched rule / explain CTA.
      await tester.drag(find.byType(ListView).first, const Offset(0, -280));
      await settle(tester, pumps: 8);
      await snap('11-event-pipeline-matched-rule');

      final explain = find.text('Explain with schema summary');
      if (explain.evaluate().isNotEmpty) {
        await tester.ensureVisible(explain);
        await tester.tap(explain);
        await settle(tester, pumps: 22);
        await snap('12-explain');
        final back = find.byTooltip('Back');
        if (back.evaluate().isNotEmpty) {
          await tester.tap(back);
          await settle(tester, pumps: 10);
        }
      }

      // Back to events then Rules again after matching happened.
      final eventBack = find.byTooltip('Back');
      if (eventBack.evaluate().isNotEmpty) {
        await tester.tap(eventBack);
        await settle(tester, pumps: 12);
      }
      await tapNav(tester, 'Rules');
      await snap('13-rules-after-demo');
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
