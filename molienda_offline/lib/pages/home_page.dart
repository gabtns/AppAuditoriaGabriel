import 'package:flutter/material.dart';

import '../config.dart';
import '../forms/bolsas_form.dart';
import '../forms/ciclos_form.dart';
import '../forms/molienda_form.dart';
import '../forms/planillas_form.dart';
import '../widgets/offline_banner.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<Map<String, dynamic>?> _perfil() => supabase
      .from('usuarios')
      .select('nombre, rol, activo')
      .eq('id', supabase.auth.currentUser!.id)
      .maybeSingle();

  @override
  Widget build(BuildContext context) {
    final items = <(String, IconData, Widget)>[
      ('Ciclos', Icons.autorenew, const CiclosForm()),
      ('Molienda', Icons.settings, const MoliendaForm()),
      ('Bolsas de molienda', Icons.inventory_2, const BolsasForm()),
      ('Planillas del molino', Icons.fact_check, const PlanillasForm()),
    ];

    return FutureBuilder<Map<String, dynamic>?>(
      future: _perfil(),
      builder: (context, snap) {
        final perfil = snap.data;
        final inactivo = snap.connectionState == ConnectionState.done &&
            (perfil == null || perfil['activo'] != true);

        return Scaffold(
          appBar: AppBar(
            title: Text(perfil == null
                ? 'Molienda'
                : 'Molienda · ${perfil['nombre'] == '' ? supabase.auth.currentUser!.email : perfil['nombre']}'),
            actions: [
              IconButton(
                tooltip: 'Cerrar sesión',
                icon: const Icon(Icons.logout),
                onPressed: () => supabase.auth.signOut(),
              ),
            ],
          ),
          body: inactivo
              ? const Center(
                  child:
                      Text('Usuario inactivo. Contactá al administrador.'))
              : Column(
                  children: [
                    // Banner de estado offline / pendientes
                    const OfflineBanner(),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 800),
                          child: GridView.extent(
                            maxCrossAxisExtent: 300,
                            padding: const EdgeInsets.all(20),
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            children: [
                              for (final (title, icon, page) in items)
                                Card(
                                  child: InkWell(
                                    onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => page)),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(icon, size: 48),
                                        const SizedBox(height: 12),
                                        Text(title,
                                            textAlign: TextAlign.center,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
