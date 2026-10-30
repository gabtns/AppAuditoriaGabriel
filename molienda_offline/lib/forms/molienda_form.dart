import 'package:flutter/material.dart';

import '../widgets/common.dart';

class MoliendaForm extends StatefulWidget {
  const MoliendaForm({super.key});

  @override
  State<MoliendaForm> createState() => _MoliendaFormState();
}

class _MoliendaFormState extends State<MoliendaForm> {
  final _c = {
    for (final k in [
      'lote', 'molino', 'tiempo', 'rpm', 'temp', 'material', 'operador', 'obs'
    ])
      k: TextEditingController()
  };
  String _estado = 'en_proceso';

  Map<String, dynamic> _buildData() {
    String? opt(String k) =>
        _c[k]!.text.trim().isEmpty ? null : _c[k]!.text.trim();
    return {
      'lote': _c['lote']!.text.trim(),
      'molino': _c['molino']!.text.trim(),
      'tiempo_min': parseNum(_c['tiempo']!.text),
      'rpm': parseNum(_c['rpm']!.text),
      'temperatura_c':
          opt('temp') == null ? null : parseNum(_c['temp']!.text),
      'tipo_material': _c['material']!.text.trim(),
      'operador_nombre': _c['operador']!.text.trim(),
      'estado': _estado,
      'observaciones': opt('obs'),
    };
  }

  Future<void> _limpiar() async {
    for (final c in _c.values) {
      c.clear();
    }
    setState(() => _estado = 'en_proceso');
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FormPage(
        title: 'Molienda',
        tableName: 'moliendas',
        buildData: _buildData,
        onSave: _limpiar,
        children: [
          tf(_c['lote']!, 'Identificador de lote'),
          tf(_c['molino']!, 'Molino'),
          tf(_c['material']!, 'Tipo de grano / material'),
          tf(_c['tiempo']!, 'Tiempo de molienda (min)', numeric: true),
          tf(_c['rpm']!, 'RPM', numeric: true),
          tf(_c['temp']!, 'Temperatura (°C)', numeric: true, required: false),
          tf(_c['operador']!, 'Operador a cargo'),
          dd('Estado del proceso', _estado, const {
            'en_proceso': 'En proceso',
            'finalizada': 'Finalizada',
            'detenida': 'Detenida',
          }, (v) => setState(() => _estado = v)),
          tf(_c['obs']!, 'Observaciones', required: false, maxLines: 3),
        ],
      );
}
