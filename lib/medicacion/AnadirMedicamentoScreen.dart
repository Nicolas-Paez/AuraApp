import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:aura3/widgets/common_appbar.dart';
import 'package:aura3/utils/time_picker_wheel.dart';
import 'package:aura3/models/Medicamento.dart';
import 'package:aura3/models/HistorialMedicamento.dart';
import 'package:aura3/models/TomaMedicamento.dart';
import 'package:aura3/utils/notifications.dart';
import 'package:aura3/utils/hive_boxes.dart';

class AnadirMedicamentoScreen extends StatefulWidget {
  const AnadirMedicamentoScreen({super.key});

  @override
  State<AnadirMedicamentoScreen> createState() =>
      _AnadirMedicamentoScreenState();
}

class _AnadirMedicamentoScreenState extends State<AnadirMedicamentoScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nombreController = TextEditingController();
  final TextEditingController dosisController = TextEditingController();
  final TextEditingController notasController = TextEditingController();

  String unidad = 'mg';
  bool esRescate = false;

  // Horarios como lista de strings "HH:mm"
  final List<String> horarios = [];

  // unidades permitidas
  final List<String> unidades = ['mg', 'ml', 'pastilla(s)'];

  Future<void> _pickTime() async {
    final initial = TimeOfDay.now();
    final picked = await showWheelTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null) {
      final formatted = _formatTimeOfDay(picked);
      if (!horarios.contains(formatted)) {
        setState(() => horarios.add(formatted));
        // ordenar horarios cronológicamente por hora
        horarios.sort((a, b) => a.compareTo(b));
      } else {
        // opcional: mostrar mensaje si ya existe
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('El horario $formatted ya fue agregado')),
        );
      }
    }
  }

  String _formatTimeOfDay(TimeOfDay t) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, t.hour, t.minute);
    return DateFormat('HH:mm').format(dt);
  }

  Future<void> _guardarMedicamento() async {
    if (!_formKey.currentState!.validate()) return;

    // validar que la dosis sea numérica
    final dosisStr = dosisController.text.replaceAll(',', '.');
    final parsed = double.tryParse(dosisStr);
    if (parsed == null || parsed <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa una dosis válida (> 0)')),
      );
      return;
    }

    final box = Hive.box<Medicamento>('medicamentosBox');
    final nuevo = Medicamento(
      nombre: nombreController.text.trim(),
      dosis: parsed,
      dosisInicial: parsed,
      unidad: unidad,
      horarios: List<String>.from(horarios),
      notas: notasController.text.trim().isEmpty
          ? null
          : notasController.text.trim(),
      esRescate: esRescate,
      fechaInicio: DateTime.now(),
    );

    await box.add(nuevo);

    // Crear entrada inicial en el historial farmacológico
    try {
      if (!Hive.isBoxOpen(historialMedicamentosBoxName)) {
        await Hive.openBox<HistorialMedicamento>(historialMedicamentosBoxName);
      }
      final histBox = Hive.box<HistorialMedicamento>(
        historialMedicamentosBoxName,
      );
      final historial = HistorialMedicamento(
        fechaInicio: DateTime.now(),
        medicamento: nuevo.nombre,
        dosis: nuevo.dosis.toString(),
        unidad: nuevo.unidad,
      );
      await histBox.add(historial);
    } catch (e) {
      print('No se pudo crear historial inicial: $e');
    }

    // Programar alarmas diarias y crear tomas pendientes para el próximo turno
    try {
      // Asegurarnos de que el sistema de notificaciones esté inicializado
      // antes de programar recordatorios (evita race conditions si
      // `initLocalNotifications()` todavía está arrancando en background).
      try {
        await initLocalNotifications();
      } catch (e) {
        print('Advertencia: no se pudieron inicializar notificaciones: $e');
        // Continuamos de todas maneras; las llamadas a schedule intentarán
        // programar aunque la inicialización falle.
      }
      if (!Hive.isBoxOpen(tomasMedicamentosBoxName)) {
        await Hive.openBox<TomaMedicamento>(tomasMedicamentosBoxName);
      }
      final tomaBox = Hive.box<TomaMedicamento>(tomasMedicamentosBoxName);

      for (var h in nuevo.horarios) {
        final parts = h.split(':');
        if (parts.length != 2) continue;
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour == null || minute == null) continue;

        var fechaProgramada = DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day,
          hour,
          minute,
        );
        if (fechaProgramada.isBefore(DateTime.now())) {
          fechaProgramada = fechaProgramada.add(const Duration(days: 1));
        }

        // Añadir una toma pendiente para la próxima fecha si no existe
        final exists = tomaBox.values.any(
          (t) =>
              t.medicamentoNombre == nuevo.nombre &&
              t.fechaProgramada.year == fechaProgramada.year &&
              t.fechaProgramada.month == fechaProgramada.month &&
              t.fechaProgramada.day == fechaProgramada.day &&
              t.fechaProgramada.hour == fechaProgramada.hour &&
              t.fechaProgramada.minute == fechaProgramada.minute,
        );

        if (!exists) {
          final toma = TomaMedicamento(
            medicamentoKey: nuevo.key as int,
            medicamentoNombre: nuevo.nombre,
            fechaProgramada: fechaProgramada,
            estado: 'Pendiente',
          );
          await tomaBox.add(toma);
        }

        // Programar notificación diaria (repetitiva)
        await scheduleMedicationReminder(nuevo, fechaProgramada);
      }

      // Actualizar scheduling global para forzar recálculo hoy
      await scheduleAllSmartNotifications(force: true);
    } catch (e) {
      print('Error programando alarmas/tomas iniciales: $e');
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Medicamento añadido correctamente')),
    );

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: const CommonAppBar(title: 'Añadir Medicamento'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel('Nombre del medicamento:'),
              _buildTextField(nombreController, hint: 'Ej: Ácido Valproico'),

              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Dosis:'),
                        TextFormField(
                          controller: dosisController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (val) => (val == null || val.isEmpty)
                              ? 'Campo obligatorio'
                              : null,
                          decoration: InputDecoration(
                            hintText: 'Ej: 500',
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Unidad:'),
                        DropdownButtonFormField<String>(
                          initialValue: unidad,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: unidades
                              .map(
                                (u) =>
                                    DropdownMenuItem(value: u, child: Text(u)),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => unidad = v ?? unidades.first),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              _buildLabel('Horarios (puedes añadir varios):'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...horarios.map(
                    (h) => Chip(
                      label: Text(h),
                      deleteIcon: const Icon(Icons.close),
                      onDeleted: () => setState(() => horarios.remove(h)),
                    ),
                  ),
                  ActionChip(
                    label: const Text('Añadir horario'),
                    avatar: const Icon(Icons.add, size: 18),
                    onPressed: _pickTime,
                    backgroundColor: Colors.white,
                    elevation: 1,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              _buildLabel('Notas adicionales:'),
              _buildTextField(
                notasController,
                hint: 'Ej: tomar con comida',
                maxLines: 3,
                requiredField: false,
              ),

              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('¿Es medicación de rescate?'),
                  const SizedBox(width: 8),
                  Switch(
                    activeThumbColor: const Color(0xFF1E3A8A),
                    value: esRescate,
                    onChanged: (v) => setState(() => esRescate = v),
                  ),
                ],
              ),

              const SizedBox(height: 28),
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save_rounded, color: Colors.white),
                  label: const Text(
                    'Guardar Medicamento',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 36,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _guardarMedicamento,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        color: Color(0xFF1E3A8A),
      ),
    ),
  );

  Widget _buildTextField(
    TextEditingController controller, {
    String? hint,
    int maxLines = 1,
    bool requiredField = true,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: requiredField
          ? (val) => (val == null || val.isEmpty) ? 'Campo obligatorio' : null
          : null,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
