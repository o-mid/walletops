import 'package:get_it/get_it.dart';

import '../../features/auth/data/auth_repository_impl.dart';
import '../../features/auth/domain/auth_repository.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/demo/data/demo_api.dart';
import '../../features/demo/data/demo_repository_impl.dart';
import '../../features/demo/domain/demo_repository.dart';
import '../../features/events/data/events_api.dart';
import '../../features/events/data/events_repository_impl.dart';
import '../../features/events/domain/events_repository.dart';
import '../../features/events/presentation/cubit/event_detail_cubit.dart';
import '../../features/events/presentation/cubit/events_cubit.dart';
import '../../features/explain/data/ai_api.dart';
import '../../features/explain/data/explain_repository_impl.dart';
import '../../features/explain/domain/explain_repository.dart';
import '../../features/explain/presentation/cubit/explain_cubit.dart';
import '../../features/ops/data/health_api.dart';
import '../../features/ops/data/ops_repository_impl.dart';
import '../../features/ops/domain/ops_repository.dart';
import '../../features/ops/presentation/cubit/ops_health_cubit.dart';
import '../../features/rules/data/rules_api.dart';
import '../../features/rules/data/rules_repository_impl.dart';
import '../../features/rules/domain/rules_repository.dart';
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

  final authRepo = AuthRepositoryImpl(api: api.authApi, storage: storage);
  getIt.registerSingleton<AuthRepository>(authRepo);

  authCubit = AuthCubit(authRepo);
  getIt.registerSingleton<AuthCubit>(authCubit);

  final eventsRepo = EventsRepositoryImpl(EventsApi(api.dio));
  getIt.registerSingleton<EventsRepository>(eventsRepo);
  final demoRepo = DemoRepositoryImpl(DemoApi(api.dio));
  getIt.registerSingleton<DemoRepository>(demoRepo);
  getIt.registerFactory(() => EventsCubit(eventsRepo, demoRepo));
  getIt.registerFactory(() => EventDetailCubit(eventsRepo));

  final rulesRepo = RulesRepositoryImpl(RulesApi(api.dio));
  getIt.registerSingleton<RulesRepository>(rulesRepo);
  getIt.registerFactory(() => RulesCubit(rulesRepo));

  final explainRepo = ExplainRepositoryImpl(AiApi(api.dio));
  getIt.registerSingleton<ExplainRepository>(explainRepo);
  getIt.registerFactory(() => ExplainCubit(explainRepo));

  final opsRepo = OpsRepositoryImpl(HealthApi(api.dio));
  getIt.registerSingleton<OpsRepository>(opsRepo);
  getIt.registerLazySingleton(() => OpsHealthCubit(opsRepo));
}
