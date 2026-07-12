import 'package:get_it/get_it.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/events/data/events_api.dart';
import '../../features/events/data/events_repository.dart';
import '../../features/events/presentation/cubit/event_detail_cubit.dart';
import '../../features/events/presentation/cubit/events_cubit.dart';
import '../../features/rules/data/rules_api.dart';
import '../../features/rules/data/rules_repository.dart';
import '../../features/rules/presentation/cubit/rules_cubit.dart';
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

  final authRepo = AuthRepository(api: api.authApi, storage: storage);
  getIt.registerSingleton<AuthRepository>(authRepo);

  authCubit = AuthCubit(authRepo);
  getIt.registerSingleton<AuthCubit>(authCubit);

  final eventsRepo = EventsRepository(EventsApi(api.dio));
  getIt.registerSingleton<EventsRepository>(eventsRepo);
  getIt.registerFactory(() => EventsCubit(eventsRepo));
  getIt.registerFactory(() => EventDetailCubit(eventsRepo));

  final rulesRepo = RulesRepository(RulesApi(api.dio));
  getIt.registerSingleton<RulesRepository>(rulesRepo);
  getIt.registerFactory(() => RulesCubit(rulesRepo));
}
