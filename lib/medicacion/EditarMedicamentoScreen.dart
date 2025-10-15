import 'package:flutter/material.dart';
import 'package:aura3/models/Medicamento.dart';
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';

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
    box = Hive.box<Medicamento>('medicamentosBox');
    medicamento = box.getAt(widget.medicamentoKey);
    if (medicamento != null) {
      nombreController.text = medicamento!.nombre;
      dosisController.text = medicamento!.dosis.toString();
      unidad = medicamento!.unidad;
      notasController.text = medicamento!.notas ?? '';
      esRescate = medicamento!.esRescate;
      horarios = List<String>.from(medicamento!.horarios);
    }
  }

  String _formatTimeOfDay(TimeOfDay t) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, t.hour, t.minute);
    return DateFormat('HH:mm').format(dt);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Cambios guardados')));
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (medicamento == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Editar Medicamento')),
        body: const Center(child: Text('Medicamento no encontrado')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E3A8A),
        title: const Text('Editar Medicamento'),
        elevation: 0,
      ),
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
                      value: unidad,
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
                  const Text('¿Es medicación de rescate?'),
                  const SizedBox(width: 8),
                  Switch(
                    activeColor: const Color(0xFF1E3A8A),
                    value: esRescate,
                    onChanged: (v) => setState(() => esRescate = v),
                  ),
                ],
              ),

              const SizedBox(height: 28),
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Guardar Cambios'),
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
