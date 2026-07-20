import 'package:flutter/material.dart';

import 'app.dart';
import 'core/di/injection.dart';
import 'core/router/app_router.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';
import 'features/auth/presentation/cubit/auth_state.dart';
import 'features/ops/presentation/cubit/ops_health_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  final authCubit = getIt<AuthCubit>();
  final router = createAppRouter(authCubit);
  runApp(WalletOpsApp(authCubit: authCubit, router: router));
  await authCubit.bootstrap();
  if (authCubit.state.status == AuthStatus.authenticated) {
    getIt<OpsHealthCubit>().start();
  }
}
