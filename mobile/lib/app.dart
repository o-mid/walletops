import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/di/injection.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';
import 'features/auth/presentation/cubit/auth_state.dart';
import 'features/ops/presentation/cubit/ops_health_cubit.dart';

class WalletOpsApp extends StatelessWidget {
  const WalletOpsApp({
    super.key,
    required this.authCubit,
    required this.router,
  });

  final AuthCubit authCubit;
  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: authCubit),
        BlocProvider(create: (_) => getIt<OpsHealthCubit>()),
      ],
      child: BlocListener<AuthCubit, AuthState>(
        listenWhen: (prev, next) => prev.status != next.status,
        listener: (context, state) {
          final ops = context.read<OpsHealthCubit>();
          if (state.status == AuthStatus.authenticated) {
            ops.start();
          } else {
            ops.stop();
          }
        },
        child: MaterialApp.router(
          title: 'WalletOps',
          theme: buildAppTheme(),
          darkTheme: buildAppDarkTheme(),
          themeMode: ThemeMode.dark,
          routerConfig: router,
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}
