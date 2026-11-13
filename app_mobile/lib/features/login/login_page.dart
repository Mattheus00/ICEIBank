import 'package:material_ui/material_ui.dart';

import '../../core/api_client.dart';
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
  int _agenciaLogin = 0;
  bool _carregando = false;
  String? _erro;

  @override
  void dispose() {
    _usuario.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
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
      await widget.session.salvar(
        token: token,
        usuario: _usuario.text.trim(),
      );
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
    } on ApiException catch (e) {
      setState(() => _erro = e.message);
    } catch (e) {
      setState(() => _erro = e.toString());
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ICEIBank')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Login',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _agenciaLogin,
            decoration: const InputDecoration(
              labelText: 'Agência do login (JWT)',
              border: OutlineInputBorder(),
            ),
            items: AppConfig.agencias
                .map(
                  (a) => DropdownMenuItem(
                    value: a.id,
                    child: Text('Agência ${a.id} (${a.baseUrl})'),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _agenciaLogin = v ?? 0),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _usuario,
            decoration: const InputDecoration(
              labelText: 'Usuário',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _senha,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Senha',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          if (_erro != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_erro!, style: const TextStyle(color: Colors.red)),
            ),
          FilledButton(
            onPressed: _carregando ? null : _entrar,
            child: Text(_carregando ? 'Entrando...' : 'Entrar'),
          ),
          const SizedBox(height: 8),
          const Text(
            'A senha não é guardada. Só o token JWT fica no aparelho.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
