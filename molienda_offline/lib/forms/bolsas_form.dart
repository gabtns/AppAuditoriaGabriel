import 'package:flutter/material.dart';

import '../widgets/common.dart';

class BolsasForm extends StatefulWidget {
  const BolsasForm({super.key});

  @override
  State<BolsasForm> createState() => _BolsasFormState();
}

class _BolsasFormState extends State<BolsasForm> {
  final _c = {
    for (final k in ['lote', 'cantidad', 'neto', 'tara', 'merma', 'motivo'])
      k: TextEditingController()
  };
  String _calidad = 'A';

  Map<String, dynamic> _buildData() => {
        'lote': _c['lote']!.text.trim(),
        'cantidad_bolsas': int.tryParse(_c['cantidad']!.text.trim()) ?? 0,
        'peso_neto_kg': parseNum(_c['neto']!.text),
        'tara_kg': _c['tara']!.text.trim().isEmpty
            ? 0
            : parseNum(_c['tara']!.text),
        'calidad': _calidad,
        'merma_kg': _c['merma']!.text.trim().isEmpty
            ? 0
            : parseNum(_c['merma']!.text),
        'motivo_merma':
            _c['motivo']!.text.trim().isEmpty ? null : _c['motivo']!.text.trim(),
      };

  /// Solo limpia el formulario (el insert lo maneja FormPage + OfflineQueue).
  Future<void> _limpiar() async {
    for (final c in _c.values) {
      c.clear();
    }
    setState(() => _calidad = 'A');
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
        title: 'Contabilidad de bolsas',
        tableName: 'contabilidad_bolsas',
        buildData: _buildData,
        onSave: _limpiar,
        children: [
          tf(_c['lote']!, 'Lote'),
          tf(_c['cantidad']!, 'Cantidad de bolsas producidas', integer: true),
          tf(_c['neto']!, 'Peso neto por bolsa (kg)', numeric: true),
          tf(_c['tara']!, 'Tara por bolsa (kg)', numeric: true, required: false),
          dd('Clasificación de calidad', _calidad, const {
            'A': 'A',
            'B': 'B',
            'C': 'C',
            'descarte': 'Descarte',
          }, (v) => setState(() => _calidad = v)),
          tf(_c['merma']!, 'Merma / descarte (kg)',
              numeric: true, required: false),
          tf(_c['motivo']!, 'Motivo de la merma', required: false, maxLines: 2),
        ],
      );
}
