import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../widgets/common.dart';
import '../widgets/scan_field.dart';
import '../services/connectivity_service.dart';

class CiclosForm extends StatefulWidget {
  const CiclosForm({super.key});

  @override
  State<CiclosForm> createState() => _CiclosFormState();
}

class _CiclosFormState extends State<CiclosForm> {
  final _codigo = TextEditingController();
  final _numero = TextEditingController();
  final _obs = TextEditingController();
  String _estado = 'abierto';
  DateTime _fecha = DateTime.now();
  bool _buscando = false;
  String? _aviso;

  /// Busca el número asociado al código escaneado.
  /// Si no hay red, avisa al usuario pero permite continuar
  /// para que pueda guardar el registro offline.
  Future<void> _buscar(String raw) async {
    final code = raw.trim();
    if (code.isEmpty) return;
    setState(() {
      _buscando = true;
      _aviso = null;
    });

    // Si estamos offline, no intentamos la consulta
    if (!ConnectivityService.instance.isOnline.value) {
      if (mounted) {
        setState(() {
          _aviso = 'Sin conexión — ingrese el número manualmente o '
              'guarde y se sincronizará al volver la red.';
          _buscando = false;
        });
      }
      return;
    }

    try {
      final r = await supabase
          .from('codigos_ciclo')
          .select('numero_asociado')
          .eq('codigo', code)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _numero.text = (r?['numero_asociado'] as String?) ?? '';
        _aviso = r == null ? 'Código no registrado en el catálogo' : null;
      });
    } on PostgrestException catch (e) {
      if (mounted) setState(() => _aviso = 'Error de búsqueda: ${e.message}');
    } catch (_) {
      if (mounted) {
        setState(() => _aviso = 'Error de red — ingrese el número manualmente.');
      }
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  Future<void> _pickFecha() async {
    final d = await showDatePicker(
        context: context,
        initialDate: _fecha,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100));
    if (d == null || !mounted) return;
    final t = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(_fecha));
    if (t == null) return;
    setState(
        () => _fecha = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  Map<String, dynamic> _buildData() => {
        'codigo': _codigo.text.trim(),
        'numero_asociado':
            _numero.text.trim().isEmpty ? null : _numero.text.trim(),
        'estado': _estado,
        'fecha_hora': _fecha.toUtc().toIso8601String(),
        'observaciones':
            _obs.text.trim().isEmpty ? null : _obs.text.trim(),
      };

  Future<void> _limpiar() async {
    _codigo.clear();
    _numero.clear();
    _obs.clear();
    setState(() {
      _estado = 'abierto';
      _fecha = DateTime.now();
      _aviso = null;
    });
  }

  @override
  void dispose() {
    _codigo.dispose();
    _numero.dispose();
    _obs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FormPage(
        title: 'Ciclos',
        tableName: 'ciclos',
        buildData: _buildData,
        onSave: _limpiar,
        children: [
          ScanField(controller: _codigo, onCode: _buscar, loading: _buscando),
          if (_aviso != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_aviso!,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: TextFormField(
              controller: _numero,
              // Ya no es solo readOnly: si estamos offline,
              // el usuario puede ingresar manualmente
              readOnly: ConnectivityService.instance.isOnline.value,
              decoration: InputDecoration(
                labelText: ConnectivityService.instance.isOnline.value
                    ? 'Número asociado (autocompletado)'
                    : 'Número asociado (manual)',
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          dd('Estado', _estado, const {
            'abierto': 'Abierto',
            'en_proceso': 'En proceso',
            'cerrado': 'Cerrado',
            'anulado': 'Anulado',
          }, (v) => setState(() => _estado = v)),
          pickerTile('Fecha y hora', fmtFechaHora(_fecha), _pickFecha),
          tf(_obs, 'Observaciones', required: false, maxLines: 3),
        ],
      );
}
