import 'package:flutter/material.dart';
import 'package:aura3/models/Medicamento.dart';
import 'package:intl/intl.dart';
import 'package:aura3/widgets/common_appbar.dart';
import 'package:aura3/utils/time_picker_wheel.dart';
import 'package:hive/hive.dart';
import 'package:aura3/models/CambioDosis.dart';
import 'package:aura3/models/HistorialMedicamento.dart';
import 'package:aura3/utils/hive_boxes.dart';

class EditarMedicamentoScreen extends StatefulWidget {
  final int medicamentoKey; // key dentro de la box
  const EditarMedicamentoScreen({super.key, required this.medicamentoKey});

  @override
  State<EditarMedicamentoScreen> createState() =>
      _EditarMedicamentoScreenState();
}

class _EditarMedicamentoScreenState extends State<EditarMedicamentoScreen> {
  final _formKey = GlobalKey<FormState>();
  late Box<Medicamento> box;
  Medicamento? medicamento;

  final TextEditingController nombreController = TextEditingController();
  final TextEditingController dosisController = TextEditingController();
  final TextEditingController notasController = TextEditingController();
  String unidad = 'mg';
  bool esRescate = false;
  List<String> horarios = [];

  @override
  void initState() {
    super.initState();
    // Cargar la caja y el medicamento de forma segura. Evita excepciones si
    // la caja aún no ha sido abierta en el flujo de la app.
    _ensureBoxAndLoad();
  }

  Future<void> _ensureBoxAndLoad() async {
    try {
      if (!Hive.isBoxOpen(medicamentosBoxName)) {
        await Hive.openBox<Medicamento>(medicamentosBoxName);
      }
      box = Hive.box<Medicamento>(medicamentosBoxName);
      medicamento = box.getAt(widget.medicamentoKey);
      if (medicamento != null) {
        nombreController.text = medicamento!.nombre;
        dosisController.text = medicamento!.dosis.toString();
        unidad = medicamento!.unidad;
        notasController.text = medicamento!.notas ?? '';
        esRescate = medicamento!.esRescate;
        horarios = List<String>.from(medicamento!.horarios);
      }
      // Refrescar UI
      if (mounted) setState(() {});
    } catch (e) {
      // En caso de error, mostrar en consola y dejar la pantalla en estado seguro
      debugPrint('Error cargando medicamento: $e');
    }
  }

  String _formatTimeOfDay(TimeOfDay t) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, t.hour, t.minute);
    return DateFormat('HH:mm').format(dt);
  }

  Future<void> _pickTime() async {
    final picked = await showWheelTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      final formatted = _formatTimeOfDay(picked);
      if (!horarios.contains(formatted)) {
        setState(() => horarios.add(formatted));
        horarios.sort();
      }
    }
  }

  Future<void> _guardarCambios() async {
    if (!_formKey.currentState!.validate()) return;
    final parsed = double.tryParse(dosisController.text.replaceAll(',', '.'));
    if (parsed == null || parsed <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ingresa una dosis válida')));
      return;
    }
    if (medicamento == null) return;

    // Guardar valor previo para detectar cambio de dosis
    final previousDosis = medicamento!.dosis;

    medicamento!
      ..nombre = nombreController.text.trim()
      ..dosis = parsed
      ..unidad = unidad
      ..horarios = List<String>.from(horarios)
      ..notas = notasController.text.trim().isEmpty
          ? null
          : notasController.text.trim()
      ..esRescate = esRescate;

    await medicamento!.save();

    // Si la dosis cambió, registrar el cambio en la caja de cambios y en el historial
    try {
      if (previousDosis != parsed) {
        // Create cambio record
        if (!Hive.isBoxOpen(CambioDosisBoxName)) {
          await Hive.openBox<CambioDosis>(CambioDosisBoxName);
        }
        final cambiosBox = Hive.box<CambioDosis>(CambioDosisBoxName);
        final cambio = CambioDosis(
          fecha: DateTime.now(),
          dosis: parsed.toString(),
          razon: 'Ajuste manual',
          unidad: unidad,
          medicamentoKey: medicamento!.key as int?,
        );
        await cambiosBox.add(cambio);

        // También intentar anexar al HistorialMedicamento si existe (por nombre)
        if (!Hive.isBoxOpen(historialMedicamentosBoxName)) {
          await Hive.openBox<HistorialMedicamento>(
            historialMedicamentosBoxName,
          );
        }
        final histBox = Hive.box<HistorialMedicamento>(
          historialMedicamentosBoxName,
        );
        try {
          final posible = histBox.values
              .where((h) => h.medicamento == medicamento!.nombre)
              .toList();
          if (posible.isNotEmpty) {
            final h = posible.first;
            h.agregarCambioDosis(cambio);
          }
        } catch (_) {}
      }
    } catch (e) {
      print('Error guardando cambio de dosis: $e');
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Cambios guardados')));
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (medicamento == null) {
      return Scaffold(
        appBar: const CommonAppBar(title: 'Editar Medicamento'),
        body: const Center(child: Text('Medicamento no encontrado')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: const CommonAppBar(title: 'Editar Medicamento'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel('Nombre del medicamento:'),
              _buildTextField(nombreController, hint: 'Nombre'),

              const SizedBox(height: 16),
              _buildLabel('Dosis:'),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
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
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      initialValue: unidad,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: ['mg', 'ml', 'pastilla(s)']
                          .map(
                            (u) => DropdownMenuItem(value: u, child: Text(u)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => unidad = v ?? 'mg'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              _buildLabel('Horarios:'),
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
                    avatar: const Icon(Icons.add),
                    onPressed: _pickTime,
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
                  // Evitar overflow en pantallas pequeñas envolviendo el texto
                  // en un Expanded para que ocupe el espacio restante.
                  Expanded(child: Text('¿Es medicación de rescate?')),
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
                  icon: const Icon(
                    Icons.save,
                    color: Colors.white, // Ícono blanco
                  ),
                  label: const Text(
                    'Guardar Cambios',
                    style: TextStyle(
                      color: Colors.white, // Texto blanco
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: _guardarCambios,
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
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () async {
                    // Quitar del tratamiento: eliminar de hive
                    final key = medicamento!.key;
                    await box.delete(key);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Medicamento eliminado')),
                    );
                    Navigator.pop(context, true);
                  },
                  child: const Text(
                    'Quitar del tratamiento',
                    style: TextStyle(color: Colors.red),
                  ),
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
