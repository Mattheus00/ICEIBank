import 'package:flutter_test/flutter_test.dart';
import 'package:iceibank_mobile/core/api_client.dart';
import 'package:iceibank_mobile/core/session.dart';
import 'package:iceibank_mobile/data/bank_repository.dart';
import 'package:iceibank_mobile/data/offline_models.dart';
import 'package:iceibank_mobile/data/offline_store.dart';
import 'package:iceibank_mobile/data/sync_service.dart';
import 'package:iceibank_mobile/features/home/home_page.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servidor em memória: valida o vetor, guarda recibos e pode perder a resposta
/// depois de aplicar. Os testes exercitam o serviço e a persistência reais do app.
class FakeApi extends ApiClient {
  FakeApi(super.session);
  bool online = true;
  bool perderResposta = false;
  bool expirada = false;
  int aplicadas = 0;
  final saldos = <int, double>{3: 100, 6: 100, 1: 100, 12: 100};
  final vetores = <int, List<int>>{
    0: [1, 0, 0],
    1: [0, 1, 0],
  };
  final recibos = <String, Map<String, dynamic>>{};
  final envios = <Map<String, dynamic>>[];
  void Function()? depoisDeAplicar;

  Map<String, dynamic> conta(int id) => {
    'id': id,
    'nomeAluno': 'Teste',
    'saldo': saldos[id],
    'vetorAtual': List<int>.from(vetores[id % 3]!),
  };

  void alterarExternamente(int id) {
    saldos[id] = saldos[id]! + 5;
    vetores[id % 3]![id % 3]++;
  }

  @override
  Future<Map<String, dynamic>> getJson(
    String baseUrl,
    String path, {
    bool auth = true,
  }) async {
    if (!online) throw ApiException('offline');
    if (path == '/bully/lider') return {'liderAtual': 2, 'estado': 'CONHECIDO'};
    if (path == '/health') return {'status': 'ok'};
    if (expirada) throw ApiException('expirada', statusCode: 401);
    return conta(int.parse(path.split('/')[2]));
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String baseUrl,
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    expect(
      path.endsWith('/sincronizar'),
      isTrue,
      reason: 'Depósito/saque devem usar o mesmo fluxo idempotente online e offline.',
    );
    envios.add(Map<String, dynamic>.from(body!));
    if (!online) throw ApiException('offline');
    if (expirada) throw ApiException('expirada', statusCode: 401);
    final op = body['operacaoId'] as String;
    if (recibos.containsKey(op)) return recibos[op]!;
    final id = int.parse(path.split('/')[2]);
    final vetor = vetores[id % 3]!;
    if (!OfflineStore.mesmosVetores(
      List<int>.from(body['vetorConhecido'] as List),
      vetor,
    )) {
      throw ApiException(
        'conflito',
        statusCode: 409,
        body: {'contaAtual': conta(id), 'vetorAtual': List<int>.from(vetor)},
      );
    }
    saldos[id] =
        saldos[id]! +
        (body['tipo'] == 'DEPOSITO' ? 1 : -1) * (body['valor'] as num);
    vetor[id % 3]++;
    aplicadas++;
    final resposta = {'conta': conta(id), 'vetor': List<int>.from(vetor)};
    recibos[op] = resposta;
    depoisDeAplicar?.call();
    if (perderResposta) {
      perderResposta = false;
      throw ApiException('timeout após aplicar');
    }
    return resposta;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SessionStore session;
  late FakeApi api;
  late BankRepository bank;
  late SyncService sync;

  SyncService reabrir() => SyncService(
    session: session,
    api: api,
    bank: bank,
    store: OfflineStore(),
  );
  Future<Pendencia> enfileirar([int conta = 3]) =>
      sync.enfileirarOffline(contaId: conta, tipo: 'DEPOSITO', valor: 10);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    session = SessionStore();
    await session.salvar(token: 'token-teste', usuario: 'admin');
    api = FakeApi(session);
    bank = BankRepository(api);
    sync = reabrir();
    for (final id in [3, 6, 1, 12]) {
      await sync.atualizarCacheDoServidor(id);
    }
  });

  test('consulta de saldo não troca vetor de pendência antiga', () async {
    await enfileirar();
    api.alterarExternamente(3);
    await sync.atualizarCacheDoServidor(3);
    await sync.sincronizarAgora();
    expect(api.aplicadas, 0);
    expect(api.envios.single['vetorConhecido'], [1, 0, 0]);
    expect(
      (await sync.pendenciasAbertas()).single.estado,
      EstadoPendencia.conflito,
    );
  });

  test(
    'conflito mantém agência bloqueada após reabrir, sem bloquear outras',
    () async {
      await enfileirar();
      await enfileirar(6);
      await enfileirar(1);
      api.alterarExternamente(3);
      await sync.sincronizarAgora();
      expect(api.aplicadas, 1); // somente a agência 1
      final chamadas = api.envios.length;
      await reabrir().sincronizarAgora();
      expect(api.envios.length, chamadas);
      expect(api.saldos[6], 100);
    },
  );

  test(
    'timeout após aplicação repete o mesmo ID sem duplicar ao reabrir',
    () async {
      await enfileirar();
      api.perderResposta = true;
      await sync.sincronizarAgora();
      expect(api.aplicadas, 1);
      expect(
        (await sync.pendenciasAbertas()).single.estado,
        EstadoPendencia.pendente,
      );
      await reabrir().sincronizarAgora();
      expect(api.aplicadas, 1);
      expect(api.saldos[3], 110);
      expect(api.envios[0], api.envios[1]);
      expect(await sync.pendenciasAbertas(), isEmpty);
    },
  );

  test('avanço confirmado funciona entre contas da mesma agência', () async {
    await enfileirar();
    await enfileirar(6);
    await sync.sincronizarAgora();
    expect(api.aplicadas, 2);
    expect(api.envios[0]['vetorConhecido'], [1, 0, 0]);
    expect(api.envios[1]['vetorConhecido'], [2, 0, 0]);
    expect(api.saldos[3], 110);
    expect(api.saldos[6], 110);
  });

  test(
    'alteração externa entre dois envios continua causando conflito',
    () async {
      await enfileirar();
      await enfileirar(6);
      api.depoisDeAplicar = () {
        api.alterarExternamente(6);
      };
      await sync.sincronizarAgora();
      expect(api.aplicadas, 1);
      expect(
        (await sync.pendenciasAbertas()).single.estado,
        EstadoPendencia.conflito,
      );
    },
  );

  test('resultado incerto não pode ser descartado nem limpo', () async {
    final p = await enfileirar();
    api.perderResposta = true;
    await sync.sincronizarAgora();
    await expectLater(
      sync.descartarConflito(p.id),
      throwsA(isA<ApiException>()),
    );
    await expectLater(
      sync.limparPendenciasDaConta(3),
      throwsA(isA<ApiException>()),
    );
    expect(await sync.pendenciasAbertas(), hasLength(1));
  });

  test('nova tentativa explícita preserva a posição da operação', () async {
    final primeira = await enfileirar();
    await enfileirar();
    api.alterarExternamente(3);
    await sync.sincronizarAgora();
    await sync.reenfileirarAposConflito(primeira.id);
    final fila = await sync.pendenciasAbertas();
    expect(fila.first.id, primeira.id);
    expect(fila.first.vetorBase, [2, 0, 0]);
    expect(fila[1].vetorBase, [1, 0, 0]); // sem rebase silencioso das seguintes
  });

  test('401 preserva ID e fila até autenticar novamente', () async {
    final p = await enfileirar();
    api.expirada = true;
    await expectLater(sync.sincronizarAgora(), throwsA(isA<ApiException>()));
    expect((await sync.pendenciasAbertas()).single.id, p.id);
    api.expirada = false;
    await reabrir().sincronizarAgora();
    expect(api.aplicadas, 1);
    expect(await sync.pendenciasAbertas(), isEmpty);
  });

  test('recibo antigo não regride cache mais recente', () async {
    await enfileirar();
    api.perderResposta = true;
    await sync.sincronizarAgora();
    api.alterarExternamente(3);
    await sync.atualizarCacheDoServidor(3);
    await sync.sincronizarAgora();
    expect((await sync.cacheDaConta(3))!.saldoConfirmado, 115);
    expect(api.aplicadas, 1);
  });

  test(
    'persistência serializada não perde enfileiramentos concorrentes',
    () async {
      await Future.wait(List.generate(12, (_) => enfileirar()));
      expect(await reabrir().pendenciasAbertas(), hasLength(12));
    },
  );

  test('valores inválidos não geram pendências nem saldo provisório', () async {
    for (final valor in [0.0, -1.0, double.nan, double.infinity]) {
      await expectLater(
        sync.enfileirarOffline(contaId: 3, tipo: 'DEPOSITO', valor: valor),
        throwsA(isA<ApiException>()),
      );
    }
    expect(await sync.pendenciasAbertas(), isEmpty);
    expect(await sync.saldoProvisorio(3), 100);
  });

  testWidgets('reconecta com tela aberta e sincroniza sem botão ou resume', (
    tester,
  ) async {
    api.online = false;
    await enfileirar(12);
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          session: session,
          api: api,
          bank: bank,
          agenciaPreferida: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(api.aplicadas, 0);
    api.online = true;
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(api.aplicadas, 1);
    expect(await sync.pendenciasAbertas(), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('primeira abertura online usa fila e endpoint idempotente', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          session: session,
          api: api,
          bank: bank,
          agenciaPreferida: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Depositar'));
    await tester.tap(find.text('Depositar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar depósito'));
    await tester.pumpAndSettle();
    expect(api.aplicadas, 1);
    expect(api.envios.single['operacaoId'], isNotEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
