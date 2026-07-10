import 'package:flutter/material.dart';

import 'app.dart';
import 'core/di/injection.dart';
import 'core/router/app_router.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  final authCubit = getIt<AuthCubit>();
  await authCubit.bootstrap();
  final router = createAppRouter(authCubit);
  runApp(WalletOpsApp(authCubit: authCubit, router: router));
}
