import 'package:flutter/material.dart';

import 'app.dart';
import 'core/di/injection.dart';
import 'core/router/app_router.dart';
import 'core/storage/token_storage.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';
import 'features/auth/presentation/cubit/auth_state.dart';
import 'features/ops/presentation/cubit/ops_health_cubit.dart';

Future<void> bootstrapApp({
  TokenStorage? tokenStorage,
  String? apiBase,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies(
    tokenStorage: tokenStorage,
    apiBase: apiBase,
  );
  final authCubit = getIt<AuthCubit>();
  final router = createAppRouter(authCubit);
  runApp(WalletOpsApp(authCubit: authCubit, router: router));
  await authCubit.bootstrap();
  if (authCubit.state.status == AuthStatus.authenticated) {
    getIt<OpsHealthCubit>().start();
  }
}
