import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/auth/presentation/cubit/auth_state.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/events/presentation/cubit/event_detail_cubit.dart';
import '../../features/events/presentation/cubit/events_cubit.dart';
import '../../features/events/presentation/event_detail_page.dart';
import '../../features/events/presentation/events_page.dart';
import '../../features/explain/presentation/cubit/explain_cubit.dart';
import '../../features/explain/presentation/explain_page.dart';
import '../../features/rules/presentation/cubit/rules_cubit.dart';
import '../../features/rules/presentation/rules_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/shell/presentation/app_shell.dart';
import '../di/injection.dart';

GoRouter createAppRouter(AuthCubit authCubit) {
  return GoRouter(
    initialLocation: '/events',
    refreshListenable: GoRouterRefreshStream(authCubit.stream),
    redirect: (context, state) {
      final status = authCubit.state.status;
      final loggingIn = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (status == AuthStatus.unknown) {
        return null;
      }
      if (status == AuthStatus.unauthenticated) {
        return loggingIn ? null : '/login';
      }
      if (loggingIn) {
        return '/events';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) => getIt<EventsCubit>()..load(),
              ),
              BlocProvider(
                create: (_) => getIt<RulesCubit>()..load(),
              ),
            ],
            child: AppShell(navigationShell: navigationShell),
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/events',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: EventsPage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/rules',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: RulesPage(),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/events/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return BlocProvider(
            create: (_) => getIt<EventDetailCubit>()..load(id),
            child: EventDetailPage(eventId: id),
          );
        },
      ),
      GoRoute(
        path: '/explain',
        builder: (context, state) {
          final raw = state.uri.queryParameters['ids'] ?? '';
          final ids = raw
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
          return BlocProvider(
            create: (_) => getIt<ExplainCubit>()..load(ids),
            child: ExplainPage(eventIds: ids),
          );
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
    ],
  );
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
