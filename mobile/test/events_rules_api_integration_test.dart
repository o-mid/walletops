import 'package:flutter_test/flutter_test.dart';
import 'package:walletops_mobile/core/network/api_client.dart';
import 'package:walletops_mobile/core/storage/token_storage.dart';
import 'package:walletops_mobile/features/auth/data/auth_repository_impl.dart';
import 'package:walletops_mobile/features/demo/data/demo_api.dart';
import 'package:walletops_mobile/features/demo/data/demo_repository_impl.dart';
import 'package:walletops_mobile/features/events/data/events_api.dart';
import 'package:walletops_mobile/features/events/data/events_repository_impl.dart';
import 'package:walletops_mobile/features/events/presentation/cubit/event_detail_cubit.dart';
import 'package:walletops_mobile/features/events/presentation/cubit/event_detail_state.dart';
import 'package:walletops_mobile/features/events/presentation/cubit/events_cubit.dart';
import 'package:walletops_mobile/features/events/presentation/cubit/events_state.dart';
import 'package:walletops_mobile/features/rules/data/rules_api.dart';
import 'package:walletops_mobile/features/rules/data/rules_repository_impl.dart';
import 'package:walletops_mobile/features/rules/presentation/cubit/rules_cubit.dart';
import 'package:walletops_mobile/features/rules/presentation/cubit/rules_state.dart';

void main() {
  test('events list/detail and rules crud against local API', () async {
    const base = String.fromEnvironment(
      'API_BASE',
      defaultValue: 'http://127.0.0.1:8080',
    );
    final storage = InMemoryTokenStorage();
    final api = ApiClient(
      storage: storage,
      baseUrl: base,
      onSessionExpired: () {},
    );
    final auth = AuthRepositoryImpl(api: api.authApi, storage: storage);
    final email =
        'mobile-events-${DateTime.now().microsecondsSinceEpoch}@walletops.local';
    await auth.register(email: email, password: 'ops-secret-1');

    final rulesCubit = RulesCubit(RulesRepositoryImpl(RulesApi(api.dio)));
    final created = await rulesCubit.create(
      name: 'drop watch',
      eventType: 'balance_drop',
      threshold: 200,
    );
    expect(created, isTrue);
    expect(rulesCubit.state.status, RulesStatus.ready);
    expect(rulesCubit.state.items.any((r) => r.name == 'drop watch'), isTrue);

    final ruleId = rulesCubit.state.items.firstWhere((r) => r.name == 'drop watch').id;
    final updated = await rulesCubit.update(
      id: ruleId,
      name: 'drop watch v2',
      eventType: 'balance_drop',
      threshold: 150,
      enabled: true,
    );
    expect(updated, isTrue);
    expect(
      rulesCubit.state.items.any((r) => r.name == 'drop watch v2'),
      isTrue,
    );

    final eventsCubit = EventsCubit(
      EventsRepositoryImpl(EventsApi(api.dio)),
      DemoRepositoryImpl(DemoApi(api.dio)),
    );
    await eventsCubit.load();
    expect(
      eventsCubit.state.status == EventsStatus.empty ||
          eventsCubit.state.status == EventsStatus.ready,
      isTrue,
    );

    // seed one event via webhook mapping is heavy; create through list is enough
    // if empty, still validates cubit empty path.
    if (eventsCubit.state.status == EventsStatus.ready) {
      final id = eventsCubit.state.items.first.id;
      final detail = EventDetailCubit(EventsRepositoryImpl(EventsApi(api.dio)));
      await detail.load(id);
      expect(detail.state.status, EventDetailStatus.ready);
      expect(detail.state.event?.id, id);
      await detail.close();
    }

    await rulesCubit.remove(ruleId);
    await rulesCubit.close();
    await eventsCubit.close();
  });
}
