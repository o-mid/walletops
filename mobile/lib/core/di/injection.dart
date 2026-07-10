import 'package:get_it/get_it.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../network/api_client.dart';
import '../storage/token_storage.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies({
  TokenStorage? tokenStorage,
  String? apiBase,
}) async {
  if (getIt.isRegistered<AuthCubit>()) {
    return;
  }

  final storage = tokenStorage ?? SecureTokenStorage();
  getIt.registerSingleton<TokenStorage>(storage);

  late final AuthCubit authCubit;
  final api = ApiClient(
    storage: storage,
    baseUrl: apiBase,
    onSessionExpired: () => authCubit.markLoggedOut(),
  );
  getIt.registerSingleton<ApiClient>(api);

  final repo = AuthRepository(api: api.authApi, storage: storage);
  getIt.registerSingleton<AuthRepository>(repo);

  authCubit = AuthCubit(repo);
  getIt.registerSingleton<AuthCubit>(authCubit);
}
