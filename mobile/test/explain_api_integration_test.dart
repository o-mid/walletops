import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walletops_mobile/core/network/api_client.dart';
import 'package:walletops_mobile/core/storage/token_storage.dart';
import 'package:walletops_mobile/features/auth/data/auth_repository_impl.dart';
import 'package:walletops_mobile/features/explain/data/ai_api.dart';
import 'package:walletops_mobile/features/explain/data/explain_repository_impl.dart';
import 'package:walletops_mobile/features/explain/presentation/cubit/explain_cubit.dart';
import 'package:walletops_mobile/features/explain/presentation/cubit/explain_state.dart';

void main() {
  test('explain summarizes owned events via mock AI', () async {
    const base = String.fromEnvironment(
      'API_BASE',
      defaultValue: 'http://127.0.0.1:8080',
    );
    const webhookSecret = 'dev-webhook-secret';
    final storage = InMemoryTokenStorage();
    final api = ApiClient(
      storage: storage,
      baseUrl: base,
      onSessionExpired: () {},
    );
    final auth = AuthRepositoryImpl(api: api.authApi, storage: storage);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final email = 'explain-$stamp@walletops.local';
    final userRef = 'explain-ref-$stamp';

    final profile = await auth.register(email: email, password: 'ops-secret-1');

    final mapped = await Process.run(
      'docker',
      [
        'compose',
        'exec',
        '-T',
        'postgres',
        'psql',
        '-U',
        'walletops',
        '-d',
        'walletops',
        '-v',
        'ON_ERROR_STOP=1',
        '-c',
        "UPDATE users SET user_ref = '$userRef' WHERE id = '${profile.id}';",
      ],
      workingDirectory: Directory.current.path.endsWith('mobile') ? '..' : '.',
    );
    expect(mapped.exitCode, 0, reason: '${mapped.stderr}\n${mapped.stdout}');

    final body = jsonEncode({
      'idempotency_key': 'evt_explain_$stamp',
      'type': 'balance_drop',
      'user_ref': userRef,
      'payload': {
        'address_label': 'hot-sim-1',
        'amount': 120.5,
        'asset': 'USDC',
        'note': 'explain test',
      },
      'occurred_at': '2026-07-16T10:00:00Z',
    });
    final bytes = utf8.encode(body);
    final rawSig =
        Hmac(sha256, utf8.encode(webhookSecret)).convert(bytes).toString();

    final client = HttpClient();
    final req = await client.postUrl(Uri.parse('$base/v1/webhooks/events'));
    req.headers.set('Content-Type', 'application/json');
    req.headers.set('X-Signature', 'sha256=$rawSig');
    req.add(bytes);
    final res = await req.close();
    final resBody = await res.transform(utf8.decoder).join();
    client.close(force: true);
    expect(res.statusCode, anyOf(200, 202), reason: resBody);
    final eventId = jsonDecode(resBody)['id'] as String;

    final cubit = ExplainCubit(ExplainRepositoryImpl(AiApi(api.dio)));
    await cubit.load([eventId]);
    expect(cubit.state.status, ExplainStatus.ready);
    expect(cubit.state.summary?.title, isNotEmpty);
    expect(cubit.state.summary?.summaryBullets, isNotEmpty);
    expect(
      ['low', 'medium', 'high', 'unknown'],
      contains(cubit.state.summary?.riskLevel),
    );
    expect(cubit.state.summary?.followUps, isNotEmpty);
    expect(cubit.state.summary?.eventIds, contains(eventId));
    await cubit.close();
  });
}
