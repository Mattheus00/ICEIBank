import 'package:material_ui/material_ui.dart';

import 'core/api_client.dart';
import 'core/session.dart';
import 'data/bank_repository.dart';
import 'features/home/home_page.dart';
import 'features/login/login_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const IceiBankApp());
}

class IceiBankApp extends StatelessWidget {
  const IceiBankApp({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionStore();
    final api = ApiClient(session);
    final bank = BankRepository(api);

    return MaterialApp(
      title: 'ICEIBank',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B4D3E)),
        useMaterial3: true,
      ),
      home: FutureBuilder<String?>(
        future: session.token(),
        builder: (context, snap) {
          if (!snap.hasData &&
              snap.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final token = snap.data;
          if (token == null || token.isEmpty) {
            return LoginPage(session: session, api: api, bank: bank);
          }
          return HomePage(
            session: session,
            api: api,
            bank: bank,
            agenciaPreferida: 0,
          );
        },
      ),
    );
  }
}
