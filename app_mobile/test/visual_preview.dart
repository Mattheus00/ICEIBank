// Renderiza os widgets reais com dados demonstrativos, sem acessar a rede.
// Estas imagens não são evidências de integração, offline real ou failover.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iceibank_mobile/core/api_client.dart';
import 'package:iceibank_mobile/core/app_theme.dart';
import 'package:iceibank_mobile/core/session.dart';
import 'package:iceibank_mobile/data/bank_repository.dart';
import 'package:iceibank_mobile/data/offline_models.dart';
import 'package:iceibank_mobile/data/offline_store.dart';
import 'package:iceibank_mobile/features/home/home_page.dart';
import 'package:iceibank_mobile/features/login/login_page.dart';

class PreviewBinding extends WidgetsFlutterBinding {
  Size previewSize = const Size(390, 1100);

  @override
  ViewConfiguration createViewConfigurationFor(RenderView renderView) =>
      ViewConfiguration(
        logicalConstraints: BoxConstraints.tight(previewSize),
        physicalConstraints: BoxConstraints.tight(previewSize),
        devicePixelRatio: 1,
      );
}

class PreviewApi extends ApiClient {
  PreviewApi(super.session);
  bool online = true;

  @override
  Future<Map<String, dynamic>> getJson(
    String baseUrl,
    String path, {
    bool auth = true,
  }) async {
    if (!online) throw ApiException('Sem conexão (demonstração visual).');
    if (path == '/health') return {'status': 'ok'};
    if (path == '/bully/lider') {
      return {'liderAtual': 2, 'estado': 'CONHECIDO'};
    }
    return {
      'id': 12,
      'nomeAluno': 'Matheus Pereira',
      'saldo': 1250.50,
      'vetorAtual': [3, 0, 0],
    };
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String baseUrl,
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    throw ApiException('Envio desativado na prévia visual.');
  }
}

Future<void> main() async {
  final binding = PreviewBinding();
  var errors = 0;
  FlutterError.onError = (details) {
    errors++;
    FlutterError.dumpErrorToConsole(details);
  };
  final fontFile = File('C:/Windows/Fonts/segoeui.ttf');
  if (await fontFile.exists()) {
    await (FontLoader('Segoe UI')..addFont(
          fontFile.readAsBytes().then((bytes) => bytes.buffer.asByteData()),
        ))
        .load();
  }
  SharedPreferences.setMockInitialValues({});
  final session = SessionStore();
  await session.salvar(token: 'preview-only', usuario: 'demo');
  final api = PreviewApi(session);
  final bank = BankRepository(api);
  final store = OfflineStore();
  await store.salvarCache(
    ContaCache(
      usuario: 'demo',
      agencia: 0,
      contaId: 12,
      nome: 'Matheus Pereira',
      saldoConfirmado: 1250.50,
      vetorConfirmado: [3, 0, 0],
      lidoEm: DateTime(2026, 11, 14, 14, 30),
    ),
  );
  final output = Directory('../evidencias/sprint3/revisao-ui');
  await output.create(recursive: true);

  Future<void> capture(
    String filename,
    Size size,
    Widget page, {
    String? action,
  }) async {
    binding.previewSize = size;
    binding.handleMetricsChanged();
    final boundaryKey = GlobalKey();
    runApp(
      RepaintBoundary(
        key: boundaryKey,
        child: MaterialApp(
          key: UniqueKey(),
          debugShowCheckedModeBanner: false,
          theme: BankTheme.light,
          builder: (context, child) => Column(
            children: [
              Container(
                height: 30,
                width: double.infinity,
                alignment: Alignment.center,
                color: const Color(0xFFE6EBDD),
                child: const Text(
                  'PRÉVIA VISUAL · DADOS DEMONSTRATIVOS',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontFamily: 'Segoe UI',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: BankTheme.green,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              Expanded(child: child!),
            ],
          ),
          home: page,
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (action != null) {
      bool containsLabel(Element element) {
        if (element.widget is Text && (element.widget as Text).data == action) {
          return true;
        }
        var found = false;
        element.visitChildElements((child) {
          if (containsLabel(child)) found = true;
        });
        return found;
      }

      var tapped = false;
      void visit(Element element) {
        if (!tapped && element.widget is InkWell && containsLabel(element)) {
          (element.widget as InkWell).onTap!();
          tapped = true;
        } else {
          element.visitChildElements(visit);
        }
      }

      binding.rootElement!.visitChildElements(visit);
      if (!tapped) throw StateError('Ação não encontrada: $action');
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    binding.scheduleFrame();
    await binding.endOfFrame;
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final picture = await boundary.toImage(pixelRatio: 2);
    final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
    await File('${output.path}/$filename.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    picture.dispose();
    stdout.writeln('CAPTURED $filename (${size.width} x ${size.height})');
    runApp(const SizedBox.shrink());
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  Widget login() => LoginPage(session: session, api: api, bank: bank);
  Widget home() =>
      HomePage(session: session, api: api, bank: bank, agenciaPreferida: 0);
  await capture('01-login-celular', const Size(390, 844), login());
  await capture('02-login-desktop', const Size(1280, 900), login());
  await capture('03-conta-celular', const Size(390, 1250), home());
  await capture('04-conta-desktop', const Size(1280, 900), home());
  await capture('05-conta-compacta', const Size(320, 1250), home());
  await capture(
    '07-depositar-celular',
    const Size(390, 844),
    home(),
    action: 'Depositar',
  );
  api.online = false;
  await store.upsertPendencia(
    Pendencia(
      id: 'preview-pending-01',
      usuario: 'demo',
      agencia: 0,
      contaId: 12,
      tipo: 'DEPOSITO',
      valor: 150,
      vetorBase: [3, 0, 0],
      criadaEm: DateTime(2026, 11, 14, 14, 32),
      estado: EstadoPendencia.pendente,
    ),
  );
  await capture('06-pendencia-demonstracao', const Size(390, 1450), home());
  await store.upsertPendencia(
    Pendencia(
      id: 'preview-pending-01',
      usuario: 'demo',
      agencia: 0,
      contaId: 12,
      tipo: 'DEPOSITO',
      valor: 150,
      vetorBase: [3, 0, 0],
      tentada: true,
      criadaEm: DateTime(2026, 11, 14, 14, 32),
      estado: EstadoPendencia.conflito,
      mensagemErro:
          'Conflito demonstrativo: vetor do servidor diferente da base.',
    ),
  );
  await capture('08-conflito-demonstracao', const Size(390, 1550), home());
  stdout.writeln('RENDER_ERRORS=$errors');
  exit(errors == 0 ? 0 : 1);
}
