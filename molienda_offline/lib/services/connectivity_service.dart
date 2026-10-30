import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'offline_queue.dart';

/// Monitorea la conectividad y dispara sincronización automática
/// cuando la red vuelve.
class ConnectivityService {
  ConnectivityService._();
  static final instance = ConnectivityService._();

  final _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;

  /// `true` = hay alguna conexión (wifi, mobile, ethernet).
  final isOnline = ValueNotifier<bool>(true);

  /// Inicializar. Llamar una vez en main() después de OfflineQueue.init().
  Future<void> init() async {
    // Estado inicial.
    final results = await _connectivity.checkConnectivity();
    isOnline.value = _hasConnection(results);

    // Escuchar cambios.
    _sub = _connectivity.onConnectivityChanged.listen((results) {
      final online = _hasConnection(results);
      isOnline.value = online;
      if (online) {
        // La red volvió → sincronizar cola.
        debugPrint('[Connectivity] Online → sincronizando cola…');
        OfflineQueue.instance.syncAll();
      }
    });
  }

  bool _hasConnection(List<ConnectivityResult> results) =>
      results.any((r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet);

  void dispose() {
    _sub?.cancel();
  }
}
