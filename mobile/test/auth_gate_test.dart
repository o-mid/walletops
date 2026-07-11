import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletops_mobile/app.dart';
import 'package:walletops_mobile/core/di/injection.dart';
import 'package:walletops_mobile/core/router/app_router.dart';
import 'package:walletops_mobile/core/storage/token_storage.dart';
import 'package:walletops_mobile/features/auth/data/auth_repository.dart';
import 'package:walletops_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:walletops_mobile/features/auth/presentation/login_page.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AuthCubit cubit;
  late _MockAuthRepository repo;

  setUp(() async {
    await getIt.reset();
    repo = _MockAuthRepository();
    when(() => repo.restore()).thenAnswer((_) async => null);
    when(() => repo.hasSession()).thenAnswer((_) async => false);
    cubit = AuthCubit(repo);
    getIt.registerSingleton<TokenStorage>(InMemoryTokenStorage());
    getIt.registerSingleton<AuthRepository>(repo);
    getIt.registerSingleton<AuthCubit>(cubit);
  });

  tearDown(() async {
    await cubit.close();
    await getIt.reset();
  });

  testWidgets('auth gate redirects to login when logged out', (tester) async {
    await cubit.bootstrap();
    final router = createAppRouter(cubit);

    await tester.pumpWidget(
      WalletOpsApp(authCubit: cubit, router: router),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Event feed comes next.'), findsNothing);
  });
}
