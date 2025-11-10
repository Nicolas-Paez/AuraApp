import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../utils/hive_boxes.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../models/Medicamento.dart';
import '../models/TomaMedicamento.dart';
import '../models/CambioDosis.dart';
import '../models/HistorialMedicamento.dart';
import '../widgets/common_appbar.dart';
import 'DetallesMedicacion.dart';
import '../utils/adherence.dart';

enum FiltroMedicamento { todos, activos, inactivos }

class HistorialFarmacologicoScreen extends StatefulWidget {
  const HistorialFarmacologicoScreen({super.key});

  @override
  State<HistorialFarmacologicoScreen> createState() =>
      _HistorialFarmacologicoScreenState();
}

class _HistorialFarmacologicoScreenState
    extends State<HistorialFarmacologicoScreen> {
  // Filtro local para mostrar todos/activos/inactivos
  // Mantener en este archivo para independencia de ListadoMedicamentos
  // (mismo comportamiento visual)

  late Future<void> _datosCargados;
  List<Medicamento> medicamentos = [];
  List<TomaMedicamento> tomas = [];
  List<CambioDosis> cambios = [];
  Map<int, double> adherencias = {};
  FiltroMedicamento filtro = FiltroMedicamento.todos;

  @override
  void initState() {
    super.initState();
    _datosCargados = _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      if (!Hive.isBoxOpen(medicamentosBoxName)) {
        await Hive.openBox<Medicamento>(medicamentosBoxName);
      }
      if (!Hive.isBoxOpen(tomasMedicamentosBoxName)) {
        await Hive.openBox<TomaMedicamento>(tomasMedicamentosBoxName);
      }
      if (!Hive.isBoxOpen(CambioDosisBoxName)) {
        await Hive.openBox<CambioDosis>(CambioDosisBoxName);
      }

      final boxMedicamentos = Hive.box<Medicamento>(medicamentosBoxName);
      final boxTomas = Hive.box<TomaMedicamento>(tomasMedicamentosBoxName);
      final boxCambios = Hive.box<CambioDosis>(CambioDosisBoxName);

      // assign into local lists
      medicamentos = boxMedicamentos.values.toList();
      tomas = boxTomas.values.toList();
      cambios = boxCambios.values.toList();

      // Calcular adherencia en los últimos 30 días para cada medicamento
      adherencias = {};
      for (var m in medicamentos) {
        try {
          final key = m.key as int;
          final adh = await calcularAdherenciaMedicamento(key, days: 30);
          adherencias[key] = adh;
        } catch (_) {
          // Silenciar errores y continuar
          adherencias[m.key as int] = 0.0;
        }
      }
    } catch (e) {
      print('Error cargando datos farmacologicos: $e');
      medicamentos = [];
      tomas = [];
      cambios = [];
    }
  }

  bool _estaActivo(Medicamento medicamento) {
    try {
      if (!Hive.isBoxOpen(historialMedicamentosBoxName)) {
        // Sin historial, confiar en el flag del medicamento si existe
        return medicamento.activo;
      }

      final boxHist = Hive.box<HistorialMedicamento>(
        historialMedicamentosBoxName,
      );
      // Preferir enlace por key si está presente, fallback por nombre
      final historial = boxHist.values
          .where(
            (h) =>
                (h.medicamentoKey != null &&
                    h.medicamentoKey == medicamento.key) ||
                h.medicamento == medicamento.nombre,
          )
          .toList();

      if (historial.isEmpty) return medicamento.activo;
      final ultimo = historial.last;
      return ultimo.estaActivo;
    } catch (e) {
      // Si falla la lectura, asumimos activo para no ocultar datos
      return medicamento.activo;
    }
  }

  List<Medicamento> _filtrarMedicamentos() {
    switch (filtro) {
      case FiltroMedicamento.activos:
        return medicamentos.where((m) => _estaActivo(m)).toList();
      case FiltroMedicamento.inactivos:
        return medicamentos.where((m) => !_estaActivo(m)).toList();
      case FiltroMedicamento.todos:
        return medicamentos;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: const CommonAppBar(title: 'Historial Farmacológico'),
      body: FutureBuilder(
        future: _datosCargados,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final lista = _filtrarMedicamentos();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: ToggleButtons(
                  isSelected: [
                    filtro == FiltroMedicamento.todos,
                    filtro == FiltroMedicamento.activos,
                    filtro == FiltroMedicamento.inactivos,
                  ],
                  onPressed: (idx) {
                    setState(() {
                      filtro = FiltroMedicamento.values[idx];
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Text('Todos'),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Text('Activos'),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Text('Inactivos'),
                    ),
                  ],
                ),
              ),
              if (lista.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      'No hay medicamentos para este filtro.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: lista.length,
                    itemBuilder: (context, index) {
                      final m = lista[index];
                      // Obtener tomas dinámicamente desde la caja para que la UI
                      // refleje cambios en tiempo real cuando se actualicen las tomas.
                      final tomaBox = Hive.box<TomaMedicamento>(
                        tomasMedicamentosBoxName,
                      );
                      final tomasMed =
                          tomaBox.values
                              .where((t) => t.medicamentoKey == m.key)
                              .toList()
                            ..sort(
                              (a, b) => a.fechaProgramada.compareTo(
                                b.fechaProgramada,
                              ),
                            );

                      final cambiosMed =
                          cambios
                              .where((c) => c.medicamentoKey == m.key)
                              .toList()
                            ..sort(
                              (a, b) => a.fechaCambio.compareTo(b.fechaCambio),
                            );

                      final adherencia = _calcularAdherencia(tomasMed);
                      final dosisHistorica = _construirSerieDosis(
                        m,
                        cambiosMed,
                      );

                      return _buildMedicamentoCard(
                        context,
                        m,
                        tomasMed,
                        cambiosMed,
                        adherencia,
                        dosisHistorica,
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

  double _calcularAdherencia(List<TomaMedicamento> tomasMed) {
    if (tomasMed.isEmpty) return 0;
    final total = tomasMed.length;
    final tomadas = tomasMed
        .where((t) => t.estado.toLowerCase() == 'tomada')
        .length;
    return tomadas / total;
  }

  List<_DosisHistorica> _construirSerieDosis(
    Medicamento m,
    List<CambioDosis> cambios,
  ) {
    final List<_DosisHistorica> lista = [];

    // Valores por defecto tomados del Medicamento
    DateTime inicio = m.fechaInicio;
    double dosisInicial = m.dosisInicial ?? m.dosis;

    // Intentar preferir la información del HistorialMedicamento si existe
    try {
      if (Hive.isBoxOpen(historialMedicamentosBoxName)) {
        final boxHist = Hive.box<HistorialMedicamento>(
          historialMedicamentosBoxName,
        );
        final encontrados = boxHist.values.where((HistorialMedicamento h) {
          final matchByKey =
              h.medicamentoKey != null && h.medicamentoKey == m.key;
          final matchByName = h.medicamento == m.nombre;
          return matchByKey || matchByName;
        }).toList();

        if (encontrados.isNotEmpty) {
          final hist = encontrados.first;
          inicio = hist.fechaInicio;
          dosisInicial = double.tryParse(hist.dosis) ?? dosisInicial;
        }
      }
    } catch (_) {
      // Silenciar errores y usar valores por defecto
    }

    // Punto inicial
    lista.add(_DosisHistorica(inicio, dosisInicial));

    // Puntos por cambios
    for (var c in cambios) {
      lista.add(_DosisHistorica(c.fechaCambio, c.nuevaDosis));
    }

    // Punto final en hoy para extender la línea
    final hoy = DateTime.now();
    final ultimaDosis = cambios.isNotEmpty
        ? cambios.last.nuevaDosis
        : dosisInicial;
    if (lista.isEmpty || lista.last.fecha.isBefore(hoy)) {
      lista.add(_DosisHistorica(hoy, ultimaDosis));
    }

    lista.sort((a, b) => a.fecha.compareTo(b.fecha));
    return lista;
  }

  Widget _buildMedicamentoCard(
    BuildContext context,
    Medicamento m,
    List<TomaMedicamento> tomasMed,
    List<CambioDosis> cambiosMed,
    double adherencia,
    List<_DosisHistorica> dosisHistorica,
  ) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetalleMedicamentoScreen(medicamentoKey: m.key),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.05),
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 Encabezado con nombre + dosis actual
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    m.nombre,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${m.dosis} ${m.unidad}',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Inicio: ${DateFormat('dd/MM/yyyy').format(m.fechaInicio)}',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 8),

            // 📉 Mini gráfico de evolución de dosis
            if (dosisHistorica.length > 1)
              SizedBox(
                height: 150,
                child: SfCartesianChart(
                  primaryXAxis: DateTimeAxis(
                    dateFormat: DateFormat('dd/MM'),
                    majorGridLines: const MajorGridLines(width: 0),
                  ),
                  primaryYAxis: NumericAxis(
                    title: AxisTitle(text: 'Dosis (${m.unidad})'),
                    majorGridLines: const MajorGridLines(width: 0),
                  ),
                  tooltipBehavior: TooltipBehavior(enable: true),
                  series: <CartesianSeries<_DosisHistorica, DateTime>>[
                    LineSeries<_DosisHistorica, DateTime>(
                      dataSource: dosisHistorica,
                      xValueMapper: (d, _) => d.fecha,
                      yValueMapper: (d, _) => d.dosis,
                      color: const Color(0xFF1E3A8A),
                      width: 2,
                      markerSettings: const MarkerSettings(isVisible: true),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 8),

            // 📊 Adherencia visual
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Adherencia: ${(adherencia * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 🕒 Últimas 3 tomas
            if (tomasMed.isNotEmpty) ...[
              const Divider(),
              const Text(
                'Últimas tomas:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              ...tomasMed
                  .take(3)
                  .map(
                    (t) => Text(
                      '• ${DateFormat('dd/MM HH:mm').format(t.fechaProgramada)} - ${t.estado}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DosisHistorica {
  final DateTime fecha;
  final double dosis;
  _DosisHistorica(this.fecha, this.dosis);
}
