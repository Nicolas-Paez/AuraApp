import 'package:flutter/material.dart';
import 'package:aura3/widgets/common_appbar.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import '../models/Medicamento.dart';
import '../models/TomaMedicamento.dart';
import '../models/CambioDosis.dart'; // 👈 nuevo modelo para cambios de dosis
import '../models/HistorialMedicamento.dart';
import '../utils/hive_boxes.dart'; // ya que define los nombres centralizados

class DetalleMedicamentoScreen extends StatefulWidget {
  final int medicamentoKey;

  const DetalleMedicamentoScreen({super.key, required this.medicamentoKey});

  @override
  State<DetalleMedicamentoScreen> createState() =>
      _DetalleMedicamentoScreenState();
}

class _DetalleMedicamentoScreenState extends State<DetalleMedicamentoScreen> {
  late Future<void> _datosCargados;
  late Medicamento medicamento;
  List<TomaMedicamento> tomas = [];
  List<CambioDosis> cambiosDosis = []; // 👈 nueva lista
  List<_DosisHistorica> dosisHistorica = [];
  double adherenciaPromedio = 0.0;
  double? _dosisInicialMostrada;

  @override
  void initState() {
    super.initState();
    _datosCargados = _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    // Asegurar que las cajas necesarias estén abiertas
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
    final boxCambios = Hive.box<CambioDosis>(CambioDosisBoxName);

    medicamento = boxMedicamentos.get(widget.medicamentoKey)!;
    cambiosDosis =
        boxCambios.values
            .where((c) => c.medicamentoKey == widget.medicamentoKey)
            .toList()
          ..sort((a, b) => a.fechaCambio.compareTo(b.fechaCambio));

    // Determinar y guardar la dosis inicial que mostraremos en la UI
    double dosisInicio = medicamento.dosisInicial ?? medicamento.dosis;
    try {
      if (Hive.isBoxOpen(historialMedicamentosBoxName)) {
        final boxHist = Hive.box<HistorialMedicamento>(
          historialMedicamentosBoxName,
        );
        final encontrados = boxHist.values.where((HistorialMedicamento h) {
          final matchByKey =
              h.medicamentoKey != null &&
              h.medicamentoKey == widget.medicamentoKey;
          final matchByName = h.medicamento == medicamento.nombre;
          return matchByKey || matchByName;
        }).toList();

        if (encontrados.isNotEmpty) {
          final hist = encontrados.first;
          dosisInicio = double.tryParse(hist.dosis) ?? dosisInicio;
        }
      }
    } catch (_) {}
    _dosisInicialMostrada = dosisInicio;

    _calcularDosisHistorica();

    // Las tomas se obtendrán dinámicamente desde la caja para que la UI
    // refleje cambios en tiempo real.

    print('--- DEBUG DETALLE MEDICAMENTO ---');
    print('Cambios dosis cargados: ${cambiosDosis.length}');
    print('Dosis Histórica (Puntos): ${dosisHistorica.length}');
    print('-----------------------------------');
  }

  void _calcularDosisHistorica() {
    dosisHistorica.clear();

    // Aseguramos orden cronológico
    cambiosDosis.sort((a, b) => a.fechaCambio.compareTo(b.fechaCambio));

    // Intentar obtener la información inicial desde HistorialMedicamento
    DateTime inicioTratamiento = medicamento.fechaInicio.toLocal().copyWith(
      hour: 0,
      minute: 0,
    );

    // Usar la dosis inicial ya calculada en _cargarDatos si está disponible.
    final dosisInicio = _dosisInicialMostrada ?? medicamento.dosis;
    dosisHistorica.add(
      _DosisHistorica(inicioTratamiento, dosisInicio, medicamento.unidad),
    );

    // 🔹 Añadimos cada cambio de dosis
    for (var cambio in cambiosDosis) {
      final fechaCambio = cambio.fechaCambio.toLocal().copyWith(
        hour: 0,
        minute: 0,
      );
      dosisHistorica.add(
        _DosisHistorica(fechaCambio, cambio.nuevaDosis, medicamento.unidad),
      );
    }

    // 🔹 Último punto (hoy) para mantener línea visible hasta la fecha actual
    final hoy = DateTime.now().toLocal().copyWith(hour: 0, minute: 0);
    final ultimaDosis = cambiosDosis.isNotEmpty
        ? cambiosDosis.last.nuevaDosis
        : medicamento.dosis;

    // Si la última dosis no llega hasta hoy, extendemos la línea
    if (dosisHistorica.isEmpty || dosisHistorica.last.fecha.isBefore(hoy)) {
      dosisHistorica.add(_DosisHistorica(hoy, ultimaDosis, medicamento.unidad));
    }

    // 🔹 Ordenar por fecha final
    dosisHistorica.sort((a, b) => a.fecha.compareTo(b.fecha));
  }

  @override
  Widget build(BuildContext context) {
    if (!Hive.isBoxOpen('medicamentosBox')) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: CommonAppBar(title: medicamento.nombre),
      body: FutureBuilder(
        future: _datosCargados,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          return _buildContenido(context);
        },
      ),
    );
  }

  Widget _buildContenido(BuildContext context) {
    double? minDosis;
    double? maxDosis;

    if (dosisHistorica.isNotEmpty) {
      final valores = dosisHistorica.map((d) => d.dosis).toList();
      minDosis = valores.reduce((a, b) => a < b ? a : b) * 0.9;
      maxDosis = valores.reduce((a, b) => a > b ? a : b) * 1.1;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resumen General',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text('Nombre: ${medicamento.nombre}'),
                Text(
                  'Dosis Actual: ${medicamento.dosisInicial} ${medicamento.unidad}',
                ),
                const SizedBox(height: 4),
                Text(
                  'Dosis inicial: ${_dosisInicialMostrada ?? medicamento.dosis} ${medicamento.unidad}',
                ),
                Text(
                  'Inicio: ${medicamento.fechaInicio.toLocal().toString().split(' ')[0]}',
                ),
                // Mostrar adherencia en tiempo real consultando la caja de tomas.
                ValueListenableBuilder(
                  valueListenable: Hive.box<TomaMedicamento>(
                    tomasMedicamentosBoxName,
                  ).listenable(),
                  builder: (context, Box<TomaMedicamento> box, _) {
                    final ahora = DateTime.now();
                    final desde = ahora.subtract(const Duration(days: 30));
                    final tomasPeriodo = box.values
                        .where(
                          (t) =>
                              t.medicamentoKey == widget.medicamentoKey &&
                              !t.fechaProgramada.isAfter(ahora) &&
                              !t.fechaProgramada.isBefore(desde),
                        )
                        .toList();
                    double adh = 0.0;
                    if (tomasPeriodo.isNotEmpty) {
                      final tomadas = tomasPeriodo
                          .where((t) => t.estado.toLowerCase() == 'tomada')
                          .length;
                      adh = tomadas / tomasPeriodo.length;
                    }
                    return Text(
                      'Adherencia promedio: ${(adh * 100).toStringAsFixed(0)}%',
                    );
                  },
                ),
                Text('Notas: ${medicamento.notas ?? 'Sin notas'}'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 📈 Gráfico de tendencia de dosis
          if (dosisHistorica.length > 1)
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tendencia de Dosis',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: SfCartesianChart(
                      title: const ChartTitle(
                        text: 'Evolución de Dosis',
                        textStyle: TextStyle(fontSize: 12),
                      ),
                      primaryXAxis: DateTimeAxis(
                        dateFormat: DateFormat.yMd(),
                        title: const AxisTitle(text: 'Fecha'),
                      ),
                      primaryYAxis: NumericAxis(
                        title: AxisTitle(text: 'Dosis (${medicamento.unidad})'),
                        minimum: minDosis,
                        maximum: maxDosis,
                      ),
                      tooltipBehavior: TooltipBehavior(enable: true),
                      series: <CartesianSeries<_DosisHistorica, DateTime>>[
                        LineSeries<_DosisHistorica, DateTime>(
                          dataSource: dosisHistorica,
                          xValueMapper: (d, _) => d.fecha,
                          yValueMapper: (d, _) => d.dosis,
                          name: 'Dosis',
                          dataLabelSettings: const DataLabelSettings(
                            isVisible: true,
                            textStyle: TextStyle(fontSize: 10),
                          ),
                          markerSettings: const MarkerSettings(isVisible: true),
                          color: const Color(0xFF1E3A8A),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // 📋 Registro de tomas (dinámico)
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Registro de Tomas',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<Box<TomaMedicamento>>(
                  valueListenable: Hive.box<TomaMedicamento>(
                    tomasMedicamentosBoxName,
                  ).listenable(),
                  builder: (context, box, _) {
                    final entries =
                        box.values
                            .where(
                              (t) => t.medicamentoKey == widget.medicamentoKey,
                            )
                            .toList()
                          ..sort(
                            (a, b) =>
                                b.fechaProgramada.compareTo(a.fechaProgramada),
                          );
                    if (entries.isEmpty)
                      return const Text('No hay registros de toma.');
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: entries.map((t) {
                        final fechaProg = t.fechaProgramada
                            .toLocal()
                            .toString()
                            .split(' ');
                        final fecha = fechaProg[0];
                        final horaProg = fechaProg[1].substring(0, 5);
                        String texto = '$fecha $horaProg - ${t.estado}';
                        if (t.razon != null && t.razon!.trim().isNotEmpty) {
                          texto += ' (${t.razon})';
                        }
                        // Mostrar hora real sólo si la toma fue registrada como tomada
                        if ((t.estado.toLowerCase() == 'tomada') &&
                            t.fechaReal != null) {
                          final horaReal = t.fechaReal!
                              .toLocal()
                              .toString()
                              .split(' ')[1]
                              .substring(0, 5);
                          texto += ' [Tomado: $horaReal]';
                        }
                        return Text(texto);
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 📜 Historial de cambios de dosis
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Historial de Cambios de Dosis',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (cambiosDosis.isEmpty)
                  const Text('Sin cambios registrados.')
                else
                  ...cambiosDosis.map(
                    (c) => Text(
                      '${c.fechaCambio.toLocal().toString().split(" ")[0]} - '
                      '${c.nuevaDosis} ${medicamento.unidad} (${c.motivo})',
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 📊 Adherencia semanal (dinámica)
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Adherencia Semanal',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<Box<TomaMedicamento>>(
                  valueListenable: Hive.box<TomaMedicamento>(
                    tomasMedicamentosBoxName,
                  ).listenable(),
                  builder: (context, box, _) {
                    final entries = box.values
                        .where((t) => t.medicamentoKey == widget.medicamentoKey)
                        .toList();
                    if (entries.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(
                            'Sin datos disponibles',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      );
                    }
                    final series = _calcularAdherenciaSemanal(entries);
                    return SizedBox(
                      height: 180,
                      child: SfCartesianChart(
                        primaryXAxis: CategoryAxis(),
                        primaryYAxis: NumericAxis(
                          minimum: 0,
                          maximum: 1,
                          interval: 0.25,
                        ),
                        series: <CartesianSeries<_AdherenciaDia, String>>[
                          ColumnSeries<_AdherenciaDia, String>(
                            dataSource: series,
                            xValueMapper: (d, _) => d.dia,
                            yValueMapper: (d, _) => d.adherencia,
                            pointColorMapper: (d, _) {
                              if (d.adherencia == 1.0) return Colors.green;
                              if (d.adherencia >= 0.7) return Colors.orange;
                              return Colors.red;
                            },
                            dataLabelSettings: const DataLabelSettings(
                              isVisible: true,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_AdherenciaDia> _calcularAdherenciaSemanal(
    List<TomaMedicamento> tomasList,
  ) {
    final hoy = DateTime.now();
    final dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    final semana = <_AdherenciaDia>[];

    for (int i = 0; i < 7; i++) {
      final dia = hoy.subtract(Duration(days: i));
      final tomasDia = tomasList.where(
        (t) =>
            t.fechaProgramada.year == dia.year &&
            t.fechaProgramada.month == dia.month &&
            t.fechaProgramada.day == dia.day,
      );

      final nombreDia = dias[dia.weekday - 1];
      if (tomasDia.isEmpty) {
        semana.add(_AdherenciaDia(nombreDia, 0.0));
      } else {
        final total = tomasDia.length;
        final tomadas = tomasDia
            .where((t) => t.estado.toLowerCase() == 'tomada')
            .length;
        semana.add(_AdherenciaDia(nombreDia, tomadas / total));
      }
    }
    return semana.reversed.toList();
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
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
      child: child,
    );
  }
}

class _AdherenciaDia {
  final String dia;
  final double adherencia;
  _AdherenciaDia(this.dia, this.adherencia);
}

class _DosisHistorica {
  final DateTime fecha;
  final double dosis;
  final String unidad;
  _DosisHistorica(this.fecha, this.dosis, this.unidad);
}
