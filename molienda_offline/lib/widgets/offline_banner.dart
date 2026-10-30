import 'package:flutter/material.dart';

import '../services/connectivity_service.dart';
import '../services/offline_queue.dart';

/// Banner que aparece cuando la app está offline o hay registros pendientes.
/// Se coloca dentro del Scaffold, arriba del body.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ConnectivityService.instance.isOnline,
      builder: (context, online, _) {
        return ValueListenableBuilder<int>(
          valueListenable: OfflineQueue.instance.pendingCount,
          builder: (context, pending, _) {
            if (online && pending == 0) return const SizedBox.shrink();

            final color = online
                ? Colors.orange          // online pero con pendientes
                : Colors.grey.shade700;  // offline
            final icon = online
                ? Icons.sync
                : Icons.cloud_off;
            final text = !online
                ? 'Sin conexión — los registros se guardarán localmente'
                : '$pending registro${pending == 1 ? '' : 's'} pendiente${pending == 1 ? '' : 's'} de sincronizar';

            return Material(
              color: color,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(icon, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(text,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13)),
                      ),
                      if (online && pending > 0)
                        TextButton(
                          onPressed: () async {
                            final result =
                                await OfflineQueue.instance.syncAll();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(result.sent > 0
                                      ? '${result.sent} registro${result.sent == 1 ? '' : 's'} sincronizado${result.sent == 1 ? '' : 's'}'
                                      : 'No se pudo sincronizar'),
                                ),
                              );
                            }
                          },
                          child: const Text('Reintentar',
                              style: TextStyle(color: Colors.white)),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
