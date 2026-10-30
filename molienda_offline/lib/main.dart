import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'services/offline_queue.dart';
import 'services/connectivity_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  assert(Env.url.isNotEmpty && Env.anonKey.isNotEmpty,
      'Faltan --dart-define=SUPABASE_URL y SUPABASE_ANON_KEY');

  await Supabase.initialize(
    url: Env.url,
    anonKey: Env.anonKey,
    authOptions: FlutterAuthClientOptions(localStorage: SecureLocalStorage()),
  );

  // Inicializar cola offline (Hive) y monitor de conectividad
  await OfflineQueue.instance.init();
  await ConnectivityService.instance.init();

  runApp(const MoliendaApp());
}

class MoliendaApp extends StatelessWidget {
  const MoliendaApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Molienda',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
        home: const AuthGate(),
      );
}

/// Decide login vs. panel según la sesión. Reacciona a login, logout
/// y expiración/renovación del token.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
        stream: supabase.auth.onAuthStateChange,
        builder: (context, snap) {
          final session = snap.data?.session ?? supabase.auth.currentSession;
          return session == null ? const LoginPage() : const HomePage();
        },
      );
}
