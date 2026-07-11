import 'package:flutter_test/flutter_test.dart';
import 'package:walletops_mobile/core/network/api_client.dart';
import 'package:walletops_mobile/core/storage/token_storage.dart';
import 'package:walletops_mobile/features/auth/data/auth_repository.dart';
import 'package:walletops_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:walletops_mobile/features/auth/presentation/cubit/auth_state.dart';

void main() {
  test('registers and logs in against local API', () async {
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
    final repo = AuthRepository(api: api.authApi, storage: storage);
    final cubit = AuthCubit(repo);

    final email =
        'mobile-${DateTime.now().microsecondsSinceEpoch}@walletops.local';
    const password = 'ops-secret-1';

    await cubit.register(email: email, password: password);
    expect(cubit.state.status, AuthStatus.authenticated);
    expect(cubit.state.user?.email, email);
    expect(await storage.readAccessToken(), isNotEmpty);

    await cubit.logout();
    expect(cubit.state.status, AuthStatus.unauthenticated);

    await cubit.login(email: email, password: password);
    expect(cubit.state.status, AuthStatus.authenticated);
    expect(cubit.state.user?.email, email);

    await cubit.close();
  });
}
