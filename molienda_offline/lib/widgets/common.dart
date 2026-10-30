import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/connectivity_service.dart';
import '../services/offline_queue.dart';
import 'offline_banner.dart';

num? parseNum(String s) => num.tryParse(s.trim().replaceAll(',', '.'));

/// Campo de texto con validación básica.
Widget tf(
  TextEditingController c,
  String label, {
  bool numeric = false,
  bool integer = false,
  bool required = true,
  int maxLines = 1,
  String? Function(String?)? extra,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: c,
      maxLines: maxLines,
      keyboardType: numeric || integer
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration:
          InputDecoration(labelText: label, border: const OutlineInputBorder()),
      validator: (v) {
        final t = (v ?? '').trim();
        if (t.isEmpty) return required ? 'Requerido' : null;
        if (integer) {
          final n = int.tryParse(t);
          if (n == null || n <= 0) return 'Entero mayor a 0';
        } else if (numeric) {
          final n = parseNum(t);
          if (n == null || n < 0) return 'Número inválido';
        }
        return extra?.call(v);
      },
    ),
  );
}

Widget dd(String label, String value, Map<String, String> items,
    ValueChanged<String> onChanged) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: DropdownButtonFormField<String>(
      value: value,
      decoration:
          InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: [
        for (final e in items.entries)
          DropdownMenuItem(value: e.key, child: Text(e.value)),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    ),
  );
}

String two(int n) => n.toString().padLeft(2, '0');
String fmtFecha(DateTime d) => '${two(d.day)}/${two(d.month)}/${d.year}';
String fmtFechaHora(DateTime d) => '${fmtFecha(d)} ${two(d.hour)}:${two(d.minute)}';

void aviso(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
    ));
}

/// Estructura común de los formularios: validación, botón Guardar,
/// manejo de errores, ancho máximo, banner offline y cola de sync.
class FormPage extends StatefulWidget {
  const FormPage({
    super.key,
    required this.title,
    required this.children,
    required this.onSave,
    this.tableName,
    this.buildData,
  });

  final String title;
  final List<Widget> children;

  /// Callback original (insert directo a Supabase).
  final Future<void> Function() onSave;

  /// Nombre de la tabla destino (para la cola offline).
  /// Si es null, se usa onSave sin cola.
  final String? tableName;

  /// Construye el Map de datos para insertar.
  /// Si es null, se usa onSave directamente.
  final Map<String, dynamic> Function()? buildData;

  @override
  State<FormPage> createState() => _FormPageState();
}

class _FormPageState extends State<FormPage> {
  final _key = GlobalKey<FormState>();
  bool _saving = false;

  Future<void> _submit() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (widget.tableName != null && widget.buildData != null) {
        // ── Ruta con cola offline ──
        final data = widget.buildData!();
        final online =
            await OfflineQueue.instance.insertOrQueue(widget.tableName!, data);
        if (mounted) {
          if (online) {
            aviso(context, 'Guardado correctamente');
          } else {
            aviso(context,
                'Sin conexión — guardado localmente, se sincronizará automáticamente');
          }
        }
        // Llamar onSave solo para limpiar el form (sin el insert).
        // Los formularios deben separar la limpieza del insert.
      } else {
        // ── Ruta legacy (sin cola) ──
        await widget.onSave();
        if (mounted) aviso(context, 'Guardado correctamente');
      }

      // Limpiar formulario a través de onSave (que ahora solo limpia).
      if (widget.tableName != null) {
        await widget.onSave();
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        // Detectar constraint planilla_unica
        if (e.message.contains('planilla_unica')) {
          aviso(context,
              'Ya existe una planilla para este día, turno y molino',
              error: true);
        } else {
          aviso(context, 'No se pudo guardar: ${e.message}', error: true);
        }
      }
    } catch (_) {
      if (mounted) aviso(context, 'Error de conexión. Reintentá.', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Column(
          children: [
            // ── Banner offline ──
            const OfflineBanner(),
            // ── Formulario ──
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Form(
                    key: _key,
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        ...widget.children,
                        const SizedBox(height: 8),
                        // Indicador de pendientes
                        ValueListenableBuilder<int>(
                          valueListenable:
                              OfflineQueue.instance.pendingCount,
                          builder: (context, count, _) {
                            if (count == 0) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                '$count registro${count == 1 ? '' : 's'} pendiente${count == 1 ? '' : 's'}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.tertiary,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          },
                        ),
                        FilledButton.icon(
                          onPressed: _saving ? null : _submit,
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.save),
                          label: const Text('Guardar'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

/// Fila "etiqueta + valor" tocable (fecha, hora).
Widget pickerTile(String label, String value, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              suffixIcon: const Icon(Icons.calendar_today)),
          child: Text(value),
        ),
      ),
    );
