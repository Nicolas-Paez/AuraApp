import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:aura3/models/Medicamento.dart';
import 'package:aura3/models/HistorialMedicamento.dart';
import 'package:intl/intl.dart';
import 'package:aura3/widgets/common_appbar.dart';
import 'package:aura3/utils/hive_boxes.dart';
import 'EditarMedicamentoScreen.dart';

enum FiltroMedicamento { todos, activos, inactivos }

class ListarMedicamentosScreen extends StatefulWidget {
  const ListarMedicamentosScreen({super.key});

  @override
  State<ListarMedicamentosScreen> createState() =>
      _ListarMedicamentosScreenState();
}

class _ListarMedicamentosScreenState extends State<ListarMedicamentosScreen> {
  Box<Medicamento>? boxMedicamentos;
  Box<HistorialMedicamento>? boxHistorial;
  FiltroMedicamento filtro = FiltroMedicamento.todos;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _ensureBoxes();
  }

  Future<void> _ensureBoxes() async {
    try {
      if (!Hive.isBoxOpen(medicamentosBoxName)) {
        await Hive.openBox<Medicamento>(medicamentosBoxName);
      }
      if (!Hive.isBoxOpen(historialMedicamentosBoxName)) {
        await Hive.openBox<HistorialMedicamento>(historialMedicamentosBoxName);
      }
      boxMedicamentos = Hive.box<Medicamento>(medicamentosBoxName);
      boxHistorial = Hive.box<HistorialMedicamento>(
        historialMedicamentosBoxName,
      );
    } catch (e) {
      debugPrint('Error abriendo cajas de medicamentos/historial: $e');
    }
    if (mounted) setState(() => _ready = true);
  }

  bool _estaActivo(Medicamento medicamento) {
    final historial = boxHistorial!.values.where(
      (h) => h.medicamentoKey == medicamento.key,
    );
    if (historial.isEmpty) return true;
    final ultimoCambio = historial.last;
    final tipo = ultimoCambio.tipoCambio.toLowerCase();
    return !(tipo.contains('elimin') ||
        tipo.contains('suspend') ||
        tipo.contains('descontinu') ||
        tipo.contains('inact'));
  }

  List<Medicamento> _filtrarMedicamentos() {
    final meds = boxMedicamentos!.values.toList();
    switch (filtro) {
      case FiltroMedicamento.activos:
        return meds.where((m) => _estaActivo(m)).toList();
      case FiltroMedicamento.inactivos:
        return meds.where((m) => !_estaActivo(m)).toList();
      case FiltroMedicamento.todos:
        return meds;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si las cajas aún no están listas, mostrar indicador de carga
    if (!_ready || boxMedicamentos == null || boxHistorial == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: const CommonAppBar(title: 'Mis Medicamentos'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: const CommonAppBar(title: 'Mis Medicamentos'),
      body: ValueListenableBuilder(
        valueListenable: boxMedicamentos!.listenable(),
        builder: (context, Box<Medicamento> items, _) {
          if (items.isEmpty) {
            return const Center(
              child: Text(
                'No hay medicamentos registrados',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }

          final medicamentos = _filtrarMedicamentos();

          return Column(
            children: [
              // ======== FILTROS ========
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: ToggleButtons(
                  borderRadius: BorderRadius.circular(12),
                  selectedColor: Colors.white,
                  fillColor: const Color(0xFF1E3A8A),
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Todos'),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Activos'),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Inactivos'),
                    ),
                  ],
                  isSelected: [
                    filtro == FiltroMedicamento.todos,
                    filtro == FiltroMedicamento.activos,
                    filtro == FiltroMedicamento.inactivos,
                  ],
                  onPressed: (index) {
                    setState(() {
                      filtro = FiltroMedicamento.values[index];
                    });
                  },
                ),
              ),

              // ======== LISTA ========
              Expanded(
                child: medicamentos.isEmpty
                    ? Center(
                        child: Text(
                          filtro == FiltroMedicamento.activos
                              ? 'No hay medicamentos activos'
                              : filtro == FiltroMedicamento.inactivos
                              ? 'No hay medicamentos inactivos'
                              : 'No hay medicamentos registrados',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: medicamentos.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final medicamento = medicamentos[index];
                          final activo = _estaActivo(medicamento);
                          final historial = boxHistorial!.values
                              .where((h) => h.medicamentoKey == medicamento.key)
                              .toList();

                          final ultimaModificacion = historial.isNotEmpty
                              ? historial.last.fechaCambio
                              : medicamento.fechaInicio;

                          return Card(
                            color: activo ? Colors.white : Colors.grey.shade300,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 3,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              title: Text(
                                medicamento.nombre,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: activo
                                      ? const Color(0xFF0B1D5A)
                                      : Colors.black54,
                                  fontSize: 18,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (medicamento.horarios.isNotEmpty)
                                    Text(
                                      'Horarios: ${medicamento.horarios.join(', ')}',
                                      style: TextStyle(
                                        color: activo
                                            ? Colors.black87
                                            : Colors.black54,
                                        fontSize: 14,
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Inicio: ${DateFormat('dd/MM/yyyy').format(medicamento.fechaInicio)}',
                                    style: TextStyle(
                                      color: activo
                                          ? Colors.black54
                                          : Colors.black45,
                                    ),
                                  ),
                                  Text(
                                    'Último cambio: ${DateFormat('dd/MM/yyyy').format(ultimaModificacion)}',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  if (!activo && historial.isNotEmpty)
                                    Text(
                                      'Último estado: ${historial.last.tipoCambio}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: activo
                                  ? ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF1E3A8A,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                      ),
                                      onPressed: () async {
                                        final result = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                EditarMedicamentoScreen(
                                                  medicamentoKey:
                                                      medicamento.key as int,
                                                ),
                                          ),
                                        );
                                        if (result == true) setState(() {});
                                      },
                                      child: const Icon(
                                        Icons.edit,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
