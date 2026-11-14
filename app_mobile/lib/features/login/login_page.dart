import 'package:material_ui/material_ui.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/config.dart';
import '../../core/session.dart';
import '../../data/bank_repository.dart';
import '../home/home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.session,
    required this.api,
    required this.bank,
  });
  final SessionStore session;
  final ApiClient api;
  final BankRepository bank;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usuario = TextEditingController(text: 'admin');
  final _senha = TextEditingController(text: 'admin123');
  final _form = GlobalKey<FormState>();
  int _agenciaLogin = 0;
  bool _carregando = false;
  bool _mostrarSenha = false;
  String? _erro;

  @override
  void dispose() {
    _usuario.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (_carregando || !_form.currentState!.validate()) return;
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final token = await widget.bank.login(
        _agenciaLogin,
        _usuario.text.trim(),
        _senha.text,
      );
      await widget.session.salvar(token: token, usuario: _usuario.text.trim());
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomePage(
            session: widget.session,
            api: widget.api,
            bank: widget.bank,
            agenciaPreferida: _agenciaLogin,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _erro = e is ApiException ? e.message : e.toString());
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxWidth >= 900;
          final form = ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!wide) ...[const BankBrand(), const SizedBox(height: 46)],
                const BankBadge('AMBIENTE ACADÊMICO'),
                const SizedBox(height: 24),
                const Text(
                  'Bom ter você aqui.',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Acesse sua conta para acompanhar o saldo e suas operações.',
                  style: TextStyle(
                    color: BankTheme.muted,
                    fontSize: 15,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 32),
                Form(
                  key: _form,
                  child: Column(
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Login',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _usuario,
                        enabled: !_carregando,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.username],
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Informe seu usuário.'
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Usuário',
                          prefixIcon: Icon(
                            Icons.person_outline_rounded,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _senha,
                        enabled: !_carregando,
                        obscureText: !_mostrarSenha,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _entrar(),
                        validator: (v) => v == null || v.isEmpty
                            ? 'Informe sua senha.'
                            : null,
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          prefixIcon: const Icon(
                            Icons.lock_outline_rounded,
                            size: 20,
                          ),
                          suffixIcon: IconButton(
                            tooltip: _mostrarSenha
                                ? 'Ocultar senha'
                                : 'Mostrar senha',
                            onPressed: () =>
                                setState(() => _mostrarSenha = !_mostrarSenha),
                            icon: Icon(
                              _mostrarSenha
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        initialValue: _agenciaLogin,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Agência de acesso',
                          prefixIcon: Icon(
                            Icons.account_balance_outlined,
                            size: 20,
                          ),
                        ),
                        items: AppConfig.agencias
                            .map(
                              (a) => DropdownMenuItem(
                                value: a.id,
                                child: Text('Agência ${a.id}'),
                              ),
                            )
                            .toList(),
                        onChanged: _carregando
                            ? null
                            : (v) => setState(() => _agenciaLogin = v ?? 0),
                      ),
                      if (_erro != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 18),
                          child: Text(
                            _erro!,
                            style: const TextStyle(
                              color: BankTheme.red,
                              height: 1.5,
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _carregando ? null : _entrar,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(_carregando ? 'Entrando...' : 'Entrar'),
                              const SizedBox(width: 12),
                              if (_carregando)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              else
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 18,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 16,
                      color: BankTheme.muted,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sua senha não é salva no aparelho.',
                        style: TextStyle(
                          color: BankTheme.muted,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
          if (!wide) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: form,
              ),
            );
          }
          return Row(
            children: [
              Expanded(
                child: Container(
                  color: BankTheme.green,
                  padding: const EdgeInsets.all(56),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const BankBrand(light: true),
                      const Spacer(),
                      const Text(
                        'Um banco.\nTrês agências.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 56,
                          fontWeight: FontWeight.w600,
                          height: 1.08,
                          letterSpacing: -2,
                        ),
                      ),
                      const SizedBox(height: 26),
                      const SizedBox(
                        width: 360,
                        child: Text(
                          'Saldo, operações e conexão.\nTudo no mesmo lugar.',
                          style: TextStyle(
                            color: Color(0xFFB9CFC2),
                            fontSize: 18,
                            height: 1.7,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: List.generate(
                          3,
                          (i) => BankBadge(
                            'Agência $i',
                            color: Colors.white,
                            background: const Color(0xFF2C5146),
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'ICEIBank  /  Sistemas distribuídos',
                        style: TextStyle(
                          color: Color(0xFFB9CFC2),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(48),
                    child: form,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
