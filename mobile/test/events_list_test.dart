import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:walletops_mobile/core/theme/app_theme.dart';
import 'package:walletops_mobile/features/events/data/event_models.dart';
import 'package:walletops_mobile/features/events/presentation/events_page.dart';
import 'package:walletops_mobile/features/events/presentation/widgets/status_chip.dart';

void main() {
  testWidgets('event list renders fixtures with status chips', (tester) async {
    final fixtures = [
      OpsEvent(
        id: '11111111-1111-4111-8111-111111111111',
        userId: 'user-1',
        idempotencyKey: 'evt_fixture_balance',
        type: 'balance_drop',
        payload: const {'amount': 120.5, 'asset': 'USDC'},
        status: 'processed',
        attemptCount: 1,
        receivedAt: DateTime.utc(2026, 7, 16, 10),
        processedAt: DateTime.utc(2026, 7, 16, 10, 1),
      ),
      OpsEvent(
        id: '22222222-2222-4222-8222-222222222222',
        userId: 'user-1',
        idempotencyKey: 'evt_fixture_swap',
        type: 'swap_quote',
        payload: const {'amount': 40, 'asset': 'ETH'},
        status: 'pending',
        attemptCount: 0,
        receivedAt: DateTime.utc(2026, 7, 16, 10, 5),
      ),
    ];

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: EventsListView(items: fixtures),
          ),
          routes: [
            GoRoute(
              path: 'events/:id',
              builder: (context, state) =>
                  Text('detail ${state.pathParameters['id']}'),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        theme: buildAppTheme(),
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('balance_drop'), findsOneWidget);
    expect(find.text('swap_quote'), findsOneWidget);
    expect(find.text('evt_fixture_balance'), findsOneWidget);
    expect(find.text('evt_fixture_swap'), findsOneWidget);
    expect(find.byType(StatusChip), findsNWidgets(2));
    expect(find.text('processed'), findsOneWidget);
    expect(find.text('pending'), findsOneWidget);
  });
}
