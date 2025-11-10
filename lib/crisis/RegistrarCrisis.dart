import 'package:flutter/material.dart';
import 'package:aura3/widgets/common_appbar.dart';
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';
import 'package:aura3/models/Crisis.dart';
import 'package:aura3/models/Medicamento.dart';
import 'package:aura3/utils/time_picker_wheel.dart';

class PantallaRegistrarCrisis extends StatefulWidget {
  final Crisis? crisisExistente;
  final bool detallesColapsados;

  const PantallaRegistrarCrisis({
    super.key,
    this.crisisExistente,
    this.detallesColapsados = false,
  });

  @override
  State<PantallaRegistrarCrisis> createState() =>
      _PantallaRegistrarCrisisState();
}

class _PantallaRegistrarCrisisState extends State<PantallaRegistrarCrisis> {
  late DateTime fechaHora;

  // Registro rápido
  String? duracion;
  String? consciente;
  String? medicamentoRescate;
  int? medicamentoKey;

  List<Medicamento> medicamentosRescate = [];

  // Detalles opcionales
  String? preictal;
  String? ictal;
  String? postictalSentimiento;
  String? postictalTiempoRecuperacion;
  String? otro;

  // Escala Likert
  int? estadoAnimoAntes;
  int? estadoAnimoDespues;

  bool rapidoExpanded = true;
  bool opcionalesExpanded = true;

  @override
  void initState() {
    super.initState();
    final c = widget.crisisExistente;
    fechaHora = c?.fechaHora ?? DateTime.now();
    duracion = c?.duracion;
    consciente = c?.consciente;
    medicamentoRescate = c?.medicamentoRescate;
    medicamentoKey = c?.medicamentoRescateKey;
    postictalSentimiento = c?.postictalSentimiento;
    postictalTiempoRecuperacion = c?.postictalTiempoRecuperacion;
    estadoAnimoAntes = c?.estadoAnimoAntes;
    estadoAnimoDespues = c?.estadoAnimoDespues;
    preictal = c?.preictal;
    ictal = c?.ictal;
    otro = '';

    rapidoExpanded = !widget.detallesColapsados;
    opcionalesExpanded = !widget.detallesColapsados;

    _cargarMedicamentosRescate();
  }

  void _cargarMedicamentosRescate() async {
    if (!Hive.isBoxOpen('medicamentosBox')) {
      await Hive.openBox<Medicamento>('medicamentosBox');
    }
    final boxMedicamentos = Hive.box<Medicamento>('medicamentosBox');
    final lista = boxMedicamentos.values.where((m) => m.esRescate).toList();
    setState(() {
      medicamentosRescate = lista;
      if (medicamentoRescate == 'Sí' &&
          lista.isNotEmpty &&
          medicamentoKey == null) {
        medicamentoKey = lista.first.key;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: CommonAppBar(
        title: widget.crisisExistente != null
            ? 'Editar Crisis'
            : 'Registrar Crisis',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateTimePicker(),
            const SizedBox(height: 20),
            _buildSectionTitle(
              '¿Cuánto tiempo duró aproximadamente la crisis? *',
            ),
            const SizedBox(height: 8),
            _buildOptionCards(
              groupValue: duracion,
              onSelected: (val) => setState(() => duracion = val),
              options: [
                'Menos de 1 minuto',
                'Entre 1 y 3 minutos',
                'Entre 3 y 5 minutos',
                'Más de 5 minutos',
                'No estoy seguro/a',
              ],
            ),
            const SizedBox(height: 16),
            _buildSectionTitle('¿Permaneciste consciente durante la crisis? *'),
            const SizedBox(height: 8),
            _buildOptionCards(
              groupValue: consciente,
              onSelected: (val) => setState(() => consciente = val),
              options: [
                'Sí, estuve consciente todo el tiempo',
                'Parcialmente consciente',
                'No, perdí la conciencia',
                'No lo recuerdo',
              ],
            ),
            const SizedBox(height: 16),
            _buildSectionTitle('¿Usaste medicación de rescate? *'),
            const SizedBox(height: 8),
            _buildOptionCards(
              groupValue: medicamentoRescate,
              onSelected: (val) => setState(() {
                medicamentoRescate = val;
                if (val == 'No')
                  medicamentoKey = null;
                else if (val == 'Sí' &&
                    medicamentosRescate.isNotEmpty &&
                    medicamentoKey == null) {
                  medicamentoKey = medicamentosRescate.first.key;
                }
              }),
              options: ['Sí', 'No'],
            ),
            const SizedBox(height: 8),
            if (medicamentoRescate == 'Sí')
              if (medicamentosRescate.isNotEmpty)
                _buildDropdown(
                  label: 'Selecciona el medicamento de rescate',
                  value: medicamentosRescate
                      .firstWhere(
                        (m) => m.key == medicamentoKey,
                        orElse: () => medicamentosRescate.first,
                      )
                      .nombre,
                  options: medicamentosRescate.map((m) => m.nombre).toList(),
                  onChanged: (val) {
                    setState(() {
                      final m = medicamentosRescate.firstWhere(
                        (med) => med.nombre == val,
                      );
                      medicamentoKey = m.key;
                    });
                  },
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No hay medicamentos de rescate disponibles. Por favor, registra alguno primero.',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            const SizedBox(height: 24),

            // ---------------- DETALLES OPCIONALES ----------------
            ExpansionTile(
              title: const Text(
                'DETALLES OPCIONALES',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A),
                ),
              ),
              initiallyExpanded: opcionalesExpanded,
              childrenPadding: const EdgeInsets.all(12),
              iconColor: const Color(0xFF1E3A8A),
              collapsedIconColor: const Color(0xFF1E3A8A),
              children: [
                _buildSectionTitle('¿Cómo comenzó la crisis? (Fase preictal)'),
                const SizedBox(height: 8),
                _buildDropdown(
                  label: 'Selecciona una opción',
                  value: preictal,
                  options: [
                    'Comenzó de repente, sin aviso',
                    'Sentí señales antes (luces, sonidos, olores, emociones, mareo, etc.)',
                    'Estaba estresado/a, cansado/a o con falta de sueño',
                    'No lo sé / No lo recuerdo',
                  ],
                  onChanged: (val) => setState(() => preictal = val),
                ),
                const SizedBox(height: 16),
                _buildSectionTitle(
                  '¿Qué sucedió durante la crisis? (Fase ictal)',
                ),
                const SizedBox(height: 8),
                _buildDropdown(
                  label: 'Selecciona una opción',
                  value: ictal,
                  options: [
                    'Movimientos involuntarios o sacudidas',
                    'Pérdida de fuerza o caída',
                    'Me quedé inmóvil o rígido/a',
                    'Hice movimientos repetitivos (labios, manos, mirada, etc.)',
                    'No respondía, pero estaba consciente',
                    'No lo recuerdo bien',
                  ],
                  onChanged: (val) => setState(() => ictal = val),
                ),
                const SizedBox(height: 16),
                _buildSectionTitle(
                  '¿Cómo te sentiste después de la crisis? (Fase postictal)',
                ),
                const SizedBox(height: 8),
                _buildDropdown(
                  label: 'Selecciona una opción',
                  value: postictalSentimiento,
                  options: [
                    'Cansado/a o con sueño',
                    'Confundido/a o desorientado/a',
                    'Con dolor de cabeza o molestias físicas',
                    'Me recuperé rápido y me sentí bien',
                    'Otro',
                  ],
                  onChanged: (val) =>
                      setState(() => postictalSentimiento = val),
                ),
                if (postictalSentimiento == 'Otro')
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 16),
                    child: _buildTextInput(
                      label: 'Describe brevemente',
                      onChanged: (val) => otro = val,
                    ),
                  ),
                _buildSectionTitle(
                  '¿Cuánto tiempo tardaste en sentirte recuperado/a?',
                ),
                const SizedBox(height: 8),
                _buildDropdown(
                  label: 'Selecciona una opción',
                  value: postictalTiempoRecuperacion,
                  options: [
                    'Menos de 15 minutos',
                    'Entre 15 y 60 minutos',
                    'Más de 1 hora',
                    'No lo recuerdo',
                  ],
                  onChanged: (val) =>
                      setState(() => postictalTiempoRecuperacion = val),
                ),
                const SizedBox(height: 16),
                _buildSectionTitle('Estado de ánimo antes de la crisis'),
                const SizedBox(height: 8),
                _buildLikertSelector(
                  selected: estadoAnimoAntes,
                  onSelected: (val) => setState(() => estadoAnimoAntes = val),
                  antes: true,
                ),
                const SizedBox(height: 16),
                _buildSectionTitle('Estado de ánimo después de la crisis'),
                const SizedBox(height: 8),
                _buildLikertSelector(
                  selected: estadoAnimoDespues,
                  onSelected: (val) => setState(() => estadoAnimoDespues = val),
                  antes: false,
                ),
                const SizedBox(height: 16),
                _buildSectionTitle(
                  '¿Quieres agregar algo más sobre lo que sentiste o notaste?',
                ),
                const SizedBox(height: 8),
                _buildTextInput(
                  label: 'Escribe aquí (opcional)',
                  onChanged: (val) => otro = val,
                ),
                const SizedBox(height: 16),
              ],
            ),
            const SizedBox(height: 32),
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.bolt_rounded, color: Colors.white),
                onPressed: _guardarCrisis,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 40,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 5,
                ),
                label: Text(
                  widget.crisisExistente != null
                      ? 'Actualizar Registro'
                      : 'Guardar Registro',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ----------------- WIDGETS AUXILIARES -----------------
  Widget _buildSectionTitle(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      color: Color(0xFF1E3A8A),
    ),
  );

  Widget _buildOptionCards({
    required String? groupValue,
    required Function(String) onSelected,
    required List<String> options,
  }) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((opt) {
        final selected = groupValue == opt;
        return GestureDetector(
          onTap: () => onSelected(opt),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF1E3A8A) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? const Color(0xFF1E3A8A)
                    : Colors.grey.withAlpha(77),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(13),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              opt,
              style: TextStyle(
                color: selected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTextInput({
    required String label,
    required ValueChanged<String> onChanged,
  }) => TextField(
    onChanged: onChanged,
    maxLines: 2,
    decoration: InputDecoration(
      hintText: label,
      filled: true,
      fillColor: Colors.grey.shade100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),
  );

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) => DropdownButtonFormField<String>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: Colors.grey.shade100,
    ),
    items: options
        .map((opt) => DropdownMenuItem(value: opt, child: Text(opt)))
        .toList(),
    onChanged: onChanged,
  );

  Widget _buildDateTimePicker() {
    return InkWell(
      onTap: () async {
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: fechaHora,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: Color(0xFF1E3A8A),
                  onPrimary: Colors.white,
                  onSurface: Color(0xFF1E3A8A),
                ),
              ),
              child: child!,
            );
          },
        );
        if (pickedDate != null) {
          final pickedTime = await showWheelTimePicker(
            context: context,
            initialTime: TimeOfDay.fromDateTime(fechaHora),
          );
          if (pickedTime != null) {
            setState(() {
              fechaHora = DateTime(
                pickedDate.year,
                pickedDate.month,
                pickedDate.day,
                pickedTime.hour,
                pickedTime.minute,
              );
            });
          }
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'Fecha y hora: ${DateFormat('dd/MM/yyyy hh:mm a').format(fechaHora)}',
                style: const TextStyle(color: Colors.black87),
              ),
            ),
            const Icon(Icons.calendar_today_rounded, color: Color(0xFF1E3A8A)),
          ],
        ),
      ),
    );
  }

  Widget _buildLikertSelector({
    required int? selected,
    required ValueChanged<int> onSelected,
    bool antes = true,
  }) {
    final List<String> labels = antes
        ? [
            '1 Muy bajo — Me sentía bastante mal emocionalmente',
            '2 Bajo — Me sentía algo decaído/a o cansado/a',
            '3 Neutral — Me sentía normal, ni bien ni mal',
            '4 Alto — Me sentía bien, con ánimo positivo',
            '5 Muy alto — Me sentía muy bien, animado/a y enérgico/a',
          ]
        : [
            '1 Muy afectado — Me sentí muy mal, emocionalmente agotado/a',
            '2 Afectado — Me sentí decaído/a o con ánimo bajo',
            '3 Neutral — No noté un gran cambio en mi estado',
            '4 Mejor — Me sentí relativamente bien, con ánimo positivo',
            '5 Muy bien — Me recuperé rápido y me sentí completamente bien',
          ];

    return Column(
      children: List.generate(5, (index) {
        final isSelected = selected == index + 1;
        return GestureDetector(
          onTap: () => onSelected(index + 1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF1E3A8A).withAlpha(50)
                  : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF1E3A8A)
                    : Colors.grey.shade300,
              ),
            ),
            child: Text(labels[index], style: const TextStyle(fontSize: 13)),
          ),
        );
      }),
    );
  }

  void _guardarCrisis() async {
    if (duracion == null || consciente == null || medicamentoRescate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor completa los campos obligatorios.'),
        ),
      );
      return;
    }

    final box = Hive.box<Crisis>('crisisBox');

    final nuevaCrisis = Crisis(
      fechaHora: fechaHora,
      duracion: duracion!,
      consciente: consciente!,
      medicamentoRescate: medicamentoRescate!,
      medicamentoRescateKey: medicamentoKey,
      preictal: preictal,
      ictal: ictal,
      postictalSentimiento: postictalSentimiento,
      postictalTiempoRecuperacion: postictalTiempoRecuperacion,
      estadoAnimoAntes: estadoAnimoAntes,
      estadoAnimoDespues: estadoAnimoDespues,
      observacionesAdicionales: otro,
    );

    if (widget.crisisExistente != null) {
      final index = box.values.toList().indexOf(widget.crisisExistente!);
      await box.putAt(index, nuevaCrisis);
    } else {
      await box.add(nuevaCrisis);
    }

    Navigator.pop(context, true);
  }
}
