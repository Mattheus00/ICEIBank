import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/config.dart';
import '../../core/session.dart';
import '../../data/agencies_status_repository.dart';
import '../../data/bank_repository.dart';
import '../../data/leadership_repository.dart';
import '../../data/offline_models.dart';
import '../../data/offline_store.dart';
import '../../data/sync_service.dart';
import '../agencies/agencies_status_panel.dart';
import '../leadership/leadership_panel.dart';
import '../login/login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.session,
    required this.api,
    required this.bank,
    required this.agenciaPreferida,
  });

  final SessionStore session;
  final ApiClient api;
  final BankRepository bank;
  final int agenciaPreferida;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final _idConta = TextEditingController(text: '12');
  final _nome = TextEditingController();
  final _valor = TextEditingController(text: '10');
  final _idDestino = TextEditingController(text: '1');

  String? _resultado;
  String? _erro;
  bool _busy = false;
  bool _autoBusy = false;
  bool _modalAberto = false;
  Timer? _syncTimer;
  bool get _ocupado => _busy || _autoBusy;
  ContaCache? _cache;
  List<Pendencia> _pendencias = [];
  double? _provisorio;

  late final LeadershipRepository _leadership = LeadershipRepository(
    widget.api,
  );
  late final AgenciesStatusRepository _agenciesStatus =
      AgenciesStatusRepository(widget.api);
  late final SyncService _sync = SyncService(
    session: widget.session,
    api: widget.api,
    bank: widget.bank,
    store: OfflineStore(),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _recarregarOffline();
    _iniciarSincronizacaoAutomatica();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncTimer?.cancel();
    _sync.encerrar();
    _idConta.dispose();
    _nome.dispose();
    _valor.dispose();
    _idDestino.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _iniciarSincronizacaoAutomatica();
    } else {
      _syncTimer?.cancel();
      _syncTimer = null;
    }
  }

  void _iniciarSincronizacaoAutomatica() {
    _syncTimer?.cancel();
    // Tenta a própria API: Wi-Fi conectado não garante acesso à agência.
    _syncTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _tentarSincronizarAutomatico(),
    );
    _tentarSincronizarAutomatico();
  }

  int get _contaId => int.tryParse(_idConta.text.trim()) ?? -1;
  double get _valorNum =>
      double.tryParse(_valor.text.trim().replaceAll(',', '.')) ?? 0;

  Future<void> _recarregarOffline() async {
    final id = _contaId;
    if (id < 0) return;
    final cache = await _sync.cacheDaConta(id);
    final pend = await _sync.pendenciasAbertas();
    final prov = await _sync.saldoProvisorio(id);
    if (!mounted || id != _contaId) return;
    setState(() {
      _cache = cache;
      _pendencias = pend.where((e) => e.contaId == id).toList();
      _provisorio = cache == null ? null : prov;
    });
  }

  Future<void> _tentarSincronizarAutomatico() async {
    if (!mounted || _ocupado || _modalAberto) return;
    setState(() => _autoBusy = true);
    try {
      final msg = await _sync.sincronizarAgora();
      if (!mounted) return;
      if (msg != 'Nenhuma pendência para sincronizar.') {
        setState(() => _resultado = msg);
      }
      await _recarregarOffline();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        setState(
          () => _erro =
              'Sessão expirada. Pendências preservadas — faça login de novo.',
        );
      }
    } catch (e) {
      if (mounted) setState(() => _erro = 'Não foi possível sincronizar: $e');
    } finally {
      if (mounted) setState(() => _autoBusy = false);
    }
  }

  Future<void> _rodar(Future<void> Function() acao) async {
    if (_ocupado) return;
    setState(() {
      _busy = true;
      _erro = null;
      _resultado = null;
    });
    try {
      await acao();
      await _recarregarOffline();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = e.statusCode == null
            ? e.message
            : '[${e.statusCode}] ${e.message}';
      });
      if (e.statusCode == 401 && mounted) {
        // Não apaga a fila.
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => LoginPage(
              session: widget.session,
              api: widget.api,
              bank: widget.bank,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _erro = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _registrarOperacao(String tipo) async {
    await _sync.enfileirarOffline(
      contaId: _contaId,
      tipo: tipo,
      valor: _valorNum,
    );
    if (!mounted) return;
    setState(() => _resultado = 'Operação salva; aguardando confirmação.');
    await _recarregarOffline();
    final msg = await _sync.sincronizarAgora();
    if (mounted) setState(() => _resultado = msg);
  }

  Future<void> _consultarSaldo() async {
    try {
      final cache = await _sync.atualizarCacheDoServidor(_contaId);
      if (mounted) {
        setState(
          () => _resultado =
              'Saldo atualizado às ${BankTheme.time(cache.lidoEm)}.',
        );
      }
    } on ApiException catch (e) {
      if (e.statusCode != null) rethrow;
      final cache = await _sync.cacheDaConta(_contaId);
      if (cache == null) {
        throw ApiException('Sem conexão e sem saldo salvo para esta conta.');
      }
      if (mounted) {
        setState(
          () => _resultado =
              'Sem conexão. Exibindo o último saldo salvo no aparelho.',
        );
      }
    }
  }

  Future<void> _trocarConta() async {
    if (_ocupado) return;
    var numero = _idConta.text;
    final form = GlobalKey<FormState>();
    _modalAberto = true;
    final id = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Consultar outra conta'),
        content: Form(
          key: form,
          child: TextFormField(
            initialValue: numero,
            onChanged: (value) => numero = value,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Número da conta'),
            validator: (v) => (int.tryParse(v ?? '') ?? -1) < 0
                ? 'Informe um número válido.'
                : null,
            onFieldSubmitted: (_) {
              if (form.currentState!.validate()) {
                Navigator.pop(ctx, int.parse(numero));
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(ctx, int.parse(numero));
              }
            },
            child: const Text('Consultar'),
          ),
        ],
      ),
    ).whenComplete(() => _modalAberto = false);
    if (id == null || !mounted) return;
    _idConta.text = '$id';
    await _rodar(() async {
      await _recarregarOffline();
      await _consultarSaldo();
    });
  }

  Future<void> _abrirOperacao(String tipo) async {
    if (_ocupado) return;
    final criar = tipo == 'CRIAR';
    final transferir = tipo == 'TRANSFERENCIA';
    final titulo = switch (tipo) {
      'DEPOSITO' => 'Depositar',
      'SAQUE' => 'Sacar',
      'TRANSFERENCIA' => 'Transferir',
      _ => 'Criar conta',
    };
    final form = GlobalKey<FormState>();
    var contaNova = _idConta.text;
    _modalAberto = true;
    final confirmar = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      constraints: const BoxConstraints(maxWidth: 520),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            4,
            24,
            24 + MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  criar
                      ? 'Preencha os dados da nova conta.'
                      : 'Conta $_contaId · Agência ${AppConfig.agenciaDaConta(_contaId)}',
                  style: const TextStyle(color: BankTheme.muted, height: 1.5),
                ),
                const SizedBox(height: 26),
                if (criar) ...[
                  TextFormField(
                    initialValue: contaNova,
                    onChanged: (value) => contaNova = value,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Número da nova conta',
                    ),
                    validator: (v) => (int.tryParse(v ?? '') ?? -1) < 0
                        ? 'Informe um número válido.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nome,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nome do titular',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Informe o nome.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                ],
                if (transferir) ...[
                  TextFormField(
                    controller: _idDestino,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Conta de destino',
                    ),
                    validator: (v) => (int.tryParse(v ?? '') ?? -1) < 0
                        ? 'Informe uma conta válida.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _valor,
                  autofocus: !criar && !transferir,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    labelText: criar ? 'Saldo inicial' : 'Valor',
                    prefixText: 'R\$ ',
                  ),
                  validator: (v) {
                    final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                    if (n == null || !n.isFinite || (criar ? n < 0 : n <= 0)) {
                      return 'Informe um valor ${criar ? 'não negativo' : 'maior que zero'}.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      transferir || criar
                          ? Icons.wifi_rounded
                          : Icons.sync_rounded,
                      size: 17,
                      color: BankTheme.muted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        transferir || criar
                            ? 'Esta operação precisa de conexão.'
                            : 'Sem conexão? A operação fica salva e será sincronizada quando a agência responder.',
                        style: const TextStyle(
                          color: BankTheme.muted,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      if (form.currentState!.validate()) {
                        Navigator.pop(ctx, true);
                      }
                    },
                    child: Text(
                      criar
                          ? 'Criar conta'
                          : 'Confirmar ${transferir
                                ? 'transferência'
                                : tipo == 'DEPOSITO'
                                ? 'depósito'
                                : 'saque'}',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() => _modalAberto = false);
    if (confirmar != true || !mounted) return;
    await _rodar(() async {
      if (criar) {
        final id = int.parse(contaNova);
        await widget.bank.criarConta(
          id: id,
          nome: _nome.text.trim(),
          saldoInicial: _valorNum,
        );
        _idConta.text = '$id';
        await _sync.atualizarCacheDoServidor(id);
        if (mounted) setState(() => _resultado = 'Conta $id criada.');
      } else if (transferir) {
        final r = await widget.bank.transferir(
          idOrigem: _contaId,
          idDestino: int.parse(_idDestino.text),
          valor: _valorNum,
        );
        final mensagem = r['mensagem']?.toString() ?? 'Transferência enviada.';
        try {
          await _sync.atualizarCacheDoServidor(_contaId);
        } catch (_) {
          /* Não repete a transferência por falha na consulta. */
        }
        if (mounted) setState(() => _resultado = mensagem);
      } else {
        await _registrarOperacao(tipo);
      }
    });
  }

  Future<void> _sair() async {
    await widget.session.limpar();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LoginPage(
          session: widget.session,
          api: widget.api,
          bank: widget.bank,
        ),
      ),
    );
  }

  Widget _acao(String titulo, IconData icon, String tipo) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _ocupado ? null : () => _abrirOperacao(tipo),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _ocupado ? BankTheme.line : BankTheme.pale,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  size: 23,
                  color: _ocupado ? BankTheme.muted : BankTheme.green,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _saldo() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(26),
    decoration: BoxDecoration(
      color: BankTheme.green,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Saldo confirmado',
                style: TextStyle(color: Color(0xFFC0D3C7), fontSize: 14),
              ),
            ),
            IconButton(
              tooltip: 'Atualizar saldo',
              onPressed: _ocupado ? null : () => _rodar(_consultarSaldo),
              icon: const Icon(
                Icons.refresh_rounded,
                color: Color(0xFFD4EEA0),
                size: 22,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            _cache == null ? 'R\$ —' : BankTheme.money(_cache!.saldoConfirmado),
            style: const TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w600,
              letterSpacing: -1.6,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _cache == null
              ? 'Consulte o saldo ou crie sua primeira conta.'
              : '${_cache!.nome.isEmpty ? 'Conta $_contaId' : _cache!.nome} · Conta $_contaId',
          style: const TextStyle(color: Color(0xFFC0D3C7), fontSize: 13),
        ),
        if (_pendencias.isNotEmpty) ...[
          const SizedBox(height: 24),
          Container(height: 1, color: const Color(0xFF3A5C4F)),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Saldo provisório',
                    style: TextStyle(color: Color(0xFFC0D3C7), fontSize: 12),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    BankTheme.money(
                      _provisorio ?? _cache?.saldoConfirmado ?? 0,
                    ),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              BankBadge(
                '${_pendencias.length} pendente${_pendencias.length == 1 ? '' : 's'}',
                color: BankTheme.green,
                background: BankTheme.lime,
              ),
            ],
          ),
        ] else if (_cache != null) ...[
          const SizedBox(height: 22),
          Text(
            'Última leitura às ${BankTheme.time(_cache!.lidoEm)}',
            style: const TextStyle(color: Color(0xFFC0D3C7), fontSize: 12),
          ),
        ],
      ],
    ),
  );

  Widget _pendencia(Pendencia p) {
    final conflito = p.estado == EstadoPendencia.conflito;
    final falha = p.estado == EstadoPendencia.falha;
    final estado = switch (p.estado) {
      EstadoPendencia.conflito => 'Conflito',
      EstadoPendencia.falha => 'Recusada',
      EstadoPendencia.enviando => 'Enviando',
      EstadoPendencia.sincronizada => 'Concluída',
      EstadoPendencia.pendente => 'Aguardando',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: BankTheme.pale,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  p.tipo == 'DEPOSITO'
                      ? Icons.south_west_rounded
                      : Icons.north_east_rounded,
                  size: 20,
                  color: BankTheme.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.tipo == 'DEPOSITO' ? 'Depósito' : 'Saque',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      BankTheme.time(p.criadaEm),
                      style: const TextStyle(
                        color: BankTheme.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Text(
                  BankTheme.money(p.valor),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              BankBadge(
                estado,
                color: conflito || falha ? BankTheme.amber : BankTheme.green,
                background: conflito || falha
                    ? const Color(0xFFFFF1D9)
                    : BankTheme.pale,
              ),
              if (conflito)
                const Text(
                  'Sua decisão é necessária.',
                  style: TextStyle(color: BankTheme.amber, fontSize: 12),
                ),
            ],
          ),
          if (conflito)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'O saldo mudou desde sua última leitura. Confira o valor confirmado antes de tentar novamente.',
                style: TextStyle(
                  color: BankTheme.muted,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          if (p.estado != EstadoPendencia.enviando)
            Wrap(
              spacing: 8,
              children: [
                if (!p.tentada || conflito || falha)
                  TextButton(
                    onPressed: _ocupado
                        ? null
                        : () => _rodar(() async {
                            await _sync.descartarConflito(p.id);
                            if (mounted) {
                              setState(
                                () => _resultado = 'Operação descartada.',
                              );
                            }
                          }),
                    child: const Text('Descartar'),
                  ),
                if (conflito)
                  TextButton(
                    onPressed: _ocupado
                        ? null
                        : () => _rodar(() async {
                            await _sync.reenfileirarAposConflito(p.id);
                            final msg = await _sync.sincronizarAgora();
                            if (mounted) setState(() => _resultado = msg);
                          }),
                    child: const Text('Nova tentativa'),
                  ),
              ],
            ),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 4),
              title: const Text(
                'Detalhes da operação',
                style: TextStyle(fontSize: 12, color: BankTheme.muted),
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(
                    'ID: ${p.id}\nVetor: ${p.vetorBase}${p.mensagemErro == null ? '' : '\n${p.mensagemErro}'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: BankTheme.muted,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fila() => BankSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Operações pendentes',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.3,
                ),
              ),
            ),
            if (_pendencias.isNotEmpty)
              TextButton(
                onPressed: _ocupado
                    ? null
                    : () => _rodar(() async {
                        final msg = await _sync.sincronizarAgora();
                        if (mounted) setState(() => _resultado = msg);
                      }),
                child: const Text('Sincronizar'),
              ),
          ],
        ),
        if (_pendencias.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  color: BankTheme.green,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nenhuma operação pendente',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Operações feitas sem conexão aparecem aqui até a confirmação.',
                        style: TextStyle(
                          color: BankTheme.muted,
                          fontSize: 13,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else ...[
          for (var i = 0; i < _pendencias.length; i++) ...[
            if (i > 0) const Divider(),
            _pendencia(_pendencias[i]),
          ],
        ],
        const Divider(),
        const Padding(
          padding: EdgeInsets.only(top: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.sync_rounded, size: 16, color: BankTheme.muted),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tentativas automáticas enquanto o app está aberto.',
                  style: TextStyle(
                    color: BankTheme.muted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _aviso(String message, {bool error = false}) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 18),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: error ? const Color(0xFFFFEFEC) : BankTheme.pale,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          error ? Icons.error_outline_rounded : Icons.info_outline_rounded,
          size: 19,
          color: error ? BankTheme.red : BankTheme.green,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              color: error ? BankTheme.red : BankTheme.green,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 940;
          final pad = constraints.maxWidth < 400 ? 18.0 : 28.0;
          final account = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _saldo(),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _acao('Depositar', Icons.add_rounded, 'DEPOSITO'),
                  _acao('Sacar', Icons.remove_rounded, 'SAQUE'),
                  _acao(
                    'Transferir',
                    Icons.arrow_outward_rounded,
                    'TRANSFERENCIA',
                  ),
                  _acao('Nova conta', Icons.person_add_alt_1_outlined, 'CRIAR'),
                ],
              ),
              const SizedBox(height: 20),
              if (_erro != null) _aviso(_erro!, error: true),
              if (_resultado != null) _aviso(_resultado!),
              _fila(),
              const SizedBox(height: 16),
              if (_cache != null)
                ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: const Text(
                    'Detalhes da conta',
                    style: TextStyle(fontSize: 13, color: BankTheme.muted),
                  ),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                        child: SelectableText(
                          'Agência: ${_cache!.agencia}\nVetor confirmado: ${_cache!.vetorConfirmado}\nÚltima leitura: ${_cache!.lidoEm}',
                          style: const TextStyle(
                            color: BankTheme.muted,
                            fontSize: 12,
                            height: 1.7,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          );
          final network = Column(
            children: [
              LeadershipPanel(
                repository: _leadership,
                agenciaPreferida: widget.agenciaPreferida,
              ),
              const SizedBox(height: 18),
              AgenciesStatusPanel(
                statusRepository: _agenciesStatus,
                leadershipRepository: _leadership,
              ),
            ],
          );
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1160),
              child: ListView(
                padding: EdgeInsets.fromLTRB(pad, 22, pad, 32),
                children: [
                  Row(
                    children: [
                      const BankBrand(),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Sincronizar agora',
                        onPressed: _ocupado
                            ? null
                            : () => _rodar(() async {
                                final msg = await _sync.sincronizarAgora();
                                if (mounted) setState(() => _resultado = msg);
                              }),
                        icon: const Icon(Icons.sync_rounded, size: 22),
                      ),
                      IconButton(
                        tooltip: 'Sair',
                        onPressed: _ocupado ? null : _sair,
                        icon: const Icon(Icons.logout_rounded, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 20,
                    runSpacing: 10,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sua conta',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -.9,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Saldo e operações, em um só lugar.',
                            style: TextStyle(
                              color: BankTheme.muted,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      OutlinedButton.icon(
                        onPressed: _ocupado ? null : _trocarConta,
                        icon: const Icon(Icons.credit_card_rounded, size: 18),
                        label: Text('Conta $_contaId  ·  Trocar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  if (desktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: account),
                        const SizedBox(width: 28),
                        Expanded(flex: 4, child: network),
                      ],
                    )
                  else ...[
                    account,
                    const SizedBox(height: 24),
                    network,
                  ],
                  const SizedBox(height: 30),
                  const Center(
                    child: Text(
                      'ICEIBank · Ambiente acadêmico',
                      style: TextStyle(color: BankTheme.muted, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}
