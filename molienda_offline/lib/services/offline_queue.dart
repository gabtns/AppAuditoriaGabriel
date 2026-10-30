import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../config.dart';

/// Registro pendiente de sincronización.
class PendingRecord {
  PendingRecord({
    required this.table,
    required this.data,
    required this.createdAt,
    this.retries = 0,
  });

  factory PendingRecord.fromJson(Map<String, dynamic> json) => PendingRecord(
        table: json['table'] as String,
        data: Map<String, dynamic>.from(json['data'] as Map),
        createdAt: DateTime.parse(json['createdAt'] as String),
        retries: (json['retries'] as int?) ?? 0,
      );

  final String table;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  int retries;

  Map<String, dynamic> toJson() => {
        'table': table,
        'data': data,
        'createdAt': createdAt.toIso8601String(),
        'retries': retries,
      };
}

/// Cola local que almacena inserts fallidos o hechos sin conexión
/// y los sincroniza con Supabase cuando vuelve la red.
///
/// Usa una Box de Hive (funciona en Android, iOS y Windows).
class OfflineQueue {
  OfflineQueue._();
  static final instance = OfflineQueue._();

  static const _boxName = 'pending_inserts';
  static const _maxRetries = 5;

  late Box<String> _box;
  bool _syncing = false;

  /// Cantidad de registros pendientes (observable desde la UI).
  final pendingCount = ValueNotifier<int>(0);

  /// Inicializar Hive y abrir la box. Llamar en main() después de
  /// WidgetsFlutterBinding.ensureInitialized().
  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<String>(_boxName);
    pendingCount.value = _box.length;
  }

  /// Encola un insert para sincronizar después.
  Future<void> enqueue(String table, Map<String, dynamic> data) async {
    final record = PendingRecord(
      table: table,
      data: data,
      createdAt: DateTime.now(),
    );
    await _box.add(jsonEncode(record.toJson()));
    pendingCount.value = _box.length;
    debugPrint('[OfflineQueue] Encolado → $table (${_box.length} pendientes)');
  }

  /// Intenta insertar en Supabase. Si falla por red, encola.
  /// Retorna `true` si se insertó online, `false` si se encoló.
  Future<bool> insertOrQueue(String table, Map<String, dynamic> data) async {
    try {
      await supabase.from(table).insert(data);
      return true;
    } catch (e) {
      if (_isNetworkError(e)) {
        await enqueue(table, data);
        return false;
      }
      // Error de validación/RLS → no encolar, relanzar.
      rethrow;
    }
  }

  /// Sincroniza todos los registros pendientes con Supabase.
  /// Se llama automáticamente cuando vuelve la conexión.
  Future<SyncResult> syncAll() async {
    if (_syncing || _box.isEmpty) {
      return SyncResult(sent: 0, failed: 0, remaining: _box.length);
    }
    _syncing = true;
    int sent = 0;
    int failed = 0;
    final keysToDelete = <dynamic>[];

    try {
      for (final key in _box.keys.toList()) {
        final raw = _box.get(key);
        if (raw == null) continue;

        final record = PendingRecord.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );

        try {
          await supabase.from(record.table).insert(record.data);
          keysToDelete.add(key);
          sent++;
        } catch (e) {
          if (_isNetworkError(e)) {
            // Sin red → parar, reintentar luego.
            break;
          }
          // Error de Supabase (RLS, constraint, etc.)
          record.retries++;
          if (record.retries >= _maxRetries) {
            // Descartar después de N intentos fallidos.
            keysToDelete.add(key);
            failed++;
            debugPrint('[OfflineQueue] Descartado tras $_maxRetries intentos: '
                '${record.table} — $e');
          } else {
            await _box.put(key, jsonEncode(record.toJson()));
          }
        }
      }

      // Borrar los que se enviaron o se descartaron.
      for (final key in keysToDelete) {
        await _box.delete(key);
      }
    } finally {
      _syncing = false;
      pendingCount.value = _box.length;
    }

    final result = SyncResult(
      sent: sent,
      failed: failed,
      remaining: _box.length,
    );
    debugPrint('[OfflineQueue] Sync: $result');
    return result;
  }

  bool _isNetworkError(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('socketexception') ||
        msg.contains('handshakeexception') ||
        msg.contains('clientexception') ||
        msg.contains('timeout') ||
        msg.contains('no address associated') ||
        msg.contains('connection refused') ||
        msg.contains('network is unreachable');
  }
}

class SyncResult {
  const SyncResult({
    required this.sent,
    required this.failed,
    required this.remaining,
  });
  final int sent;
  final int failed;
  final int remaining;

  @override
  String toString() =>
      'enviados=$sent, fallidos=$failed, pendientes=$remaining';
}
