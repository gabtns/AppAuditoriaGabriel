import 'package:flutter/material.dart';

import '../widgets/common.dart';

class PlanillasForm extends StatefulWidget {
  const PlanillasForm({super.key});

  @override
  State<PlanillasForm> createState() => _PlanillasFormState();
}

class _PlanillasFormState extends State<PlanillasForm> {
  final _c = {
    for (final k in ['responsable', 'molino', 'hini', 'hfin', 'incidentes'])
      k: TextEditingController()
  };
  DateTime _fecha = DateTime.now();
  String _turno = 'manana';
  bool _lub = false, _limp = false, _vib = false, _guardas = false;

  Future<void> _pickFecha() async {
    final d = await showDatePicker(
        context: context,
        initialDate: _fecha,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100));
    if (d != null) setState(() => _fecha = d);
  }

  Map<String, dynamic> _buildData() => {
        'fecha': '${_fecha.year}-${two(_fecha.month)}-${two(_fecha.day)}',
        'turno': _turno,
        'responsable': _c['responsable']!.text.trim(),
        'molino': _c['molino']!.text.trim(),
        'chk_lubricacion': _lub,
        'chk_limpieza': _limp,
        'chk_vibraciones': _vib,
        'chk_guardas': _guardas,
        'horometro_inicio': parseNum(_c['hini']!.text),
        'horometro_fin': parseNum(_c['hfin']!.text),
        'incidentes': _c['incidentes']!.text.trim().isEmpty
            ? null
            : _c['incidentes']!.text.trim(),
      };

  Future<void> _limpiar() async {
    for (final c in _c.values) {
      c.clear();
    }
    setState(() {
      _lub = _limp = _vib = _guardas = false;
      _turno = 'manana';
    });
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
        title: 'Planillas del molino',
        tableName: 'planillas_molino',
        buildData: _buildData,
        onSave: _limpiar,
        children: [
          pickerTile('Fecha', fmtFecha(_fecha), _pickFecha),
          dd('Turno', _turno, const {
            'manana': 'Mañana',
            'tarde': 'Tarde',
            'noche': 'Noche',
          }, (v) => setState(() => _turno = v)),
          tf(_c['responsable']!, 'Responsable'),
          tf(_c['molino']!, 'Molino'),
          Text('Chequeo de mantenimiento y condiciones',
              style: Theme.of(context).textTheme.titleSmall),
          SwitchListTile(
              title: const Text('Lubricación OK'),
              value: _lub,
              onChanged: (v) => setState(() => _lub = v)),
          SwitchListTile(
              title: const Text('Limpieza OK'),
              value: _limp,
              onChanged: (v) => setState(() => _limp = v)),
          SwitchListTile(
              title: const Text('Sin vibraciones / ruidos anormales'),
              value: _vib,
              onChanged: (v) => setState(() => _vib = v)),
          SwitchListTile(
              title: const Text('Guardas de seguridad colocadas'),
              value: _guardas,
              onChanged: (v) => setState(() => _guardas = v)),
          const SizedBox(height: 12),
          tf(_c['hini']!, 'Horómetro inicio', numeric: true),
          tf(_c['hfin']!, 'Horómetro fin', numeric: true, extra: (v) {
            final ini = parseNum(_c['hini']!.text);
            final fin = parseNum(v ?? '');
            if (ini != null && fin != null && fin < ini) {
              return 'Debe ser ≥ horómetro inicio';
            }
            return null;
          }),
          tf(_c['incidentes']!, 'Incidentes o paradas operativas',
              required: false, maxLines: 4),
        ],
      );
}
