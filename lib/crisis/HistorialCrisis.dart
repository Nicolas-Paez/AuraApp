import 'package:flutter/material.dart';
import 'package:aura3/widgets/common_appbar.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:aura3/models/Crisis.dart';
import 'package:aura3/utils/hive_boxes.dart';
import 'RegistrarCrisis.dart';
import 'package:aura3/models/Medicamento.dart';

// NOTE: this file provides the `HistorialCrisisScreen` widget.
// The app entrypoint (main) should live in `lib/main.dart`.

class HistorialCrisisScreen extends StatefulWidget {
  const HistorialCrisisScreen({super.key});

  @override
  State<HistorialCrisisScreen> createState() => _HistorialCrisisScreenState();
}

String getNombreMedicamento(Crisis crisis) {
  // Prefer resolver por key si existe, si no usar el texto guardado
  try {
    if (crisis.medicamentoRescateKey != null) {
      if (!Hive.isBoxOpen(medicamentosBoxName)) {
        // si la caja no está abierta, intentar abrirla (silencioso)
        Hive.openBox<Medicamento>(medicamentosBoxName);
      }
      final box = Hive.box<Medicamento>(medicamentosBoxName);
      final medicamento = box.get(crisis.medicamentoRescateKey);
      return medicamento?.nombre ?? crisis.medicamentoRescate;
    }
  } catch (_) {
    // ignore and fallback
  }
  return crisis.medicamentoRescate;
}

class _HistorialCrisisScreenState extends State<HistorialCrisisScreen> {
  late Box<Crisis> crisisBox;
  String filtroRango = 'Última semana';
  bool mostrarTendencia = false;
  final Map<int, bool> _expandedMap = {};
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    crisisBox = Hive.box<Crisis>('crisisBox');
  }

  List<Crisis> getCrisisFiltradas() {
    final todas = crisisBox.values.toList()
      ..sort((a, b) => b.fechaHora.compareTo(a.fechaHora));
    DateTime now = DateTime.now();
    DateTime semana = now.subtract(const Duration(days: 7));
    DateTime mes = now.subtract(const Duration(days: 30));
    List<Crisis> filtradas = todas;

    if (filtroRango == 'Última semana') {
      filtradas = todas.where((c) => c.fechaHora.isAfter(semana)).toList();
    } else if (filtroRango == 'Último mes') {
      filtradas = todas.where((c) => c.fechaHora.isAfter(mes)).toList();
    }

    if (searchQuery.isNotEmpty) {
      filtradas = filtradas
          .where(
            (c) =>
                c.duracion.toLowerCase().contains(searchQuery.toLowerCase()) ||
                DateFormat(
                  'dd/MM/yyyy',
                  'es',
                ).format(c.fechaHora).contains(searchQuery),
          )
          .toList();
    }

    return filtradas;
  }

  Color _colorSegunDuracion(String duracion) {
    switch (duracion) {
      case 'Menos de 1 minuto':
        return Colors.green.shade100;
      case 'Entre 3 a 5 minutos':
        return Colors.yellow.shade100;
      case 'Más de 5 minutos':
      case 'Prolongada':
        return Colors.red.shade100;
      default:
        return Colors.grey.shade200;
    }
  }

  Color _bordeSegunDuracion(String duracion) {
    switch (duracion) {
      case 'Menos de 1 minuto':
        return Colors.green.shade700;
      case 'Entre 3 a 5 minutos':
        return Colors.amber.shade700;
      case 'Más de 5 minutos':
      case 'Prolongada':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade500;
    }
  }

  Future<void> _abrirFormulario(Crisis? crisis) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaRegistrarCrisis(crisisExistente: crisis),
      ),
    );
    setState(() {});
  }

  // ✅ Función actualizada para incluir todos los días y meses con count 0
  List<CrisisData> _generateChartData(List<Crisis> crisisFiltradas) {
    if (crisisFiltradas.isEmpty) return [];

    final now = DateTime.now();
    final sorted = crisisFiltradas.toList()
      ..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));

    // Determinar inicio y fin del rango
    DateTime inicio;
    DateTime fin;

    if (filtroRango == 'Última semana') {
      fin = DateTime(now.year, now.month, now.day);
      inicio = fin.subtract(const Duration(days: 6));
    } else if (filtroRango == 'Último mes') {
      fin = DateTime(now.year, now.month, now.day);
      inicio = fin.subtract(const Duration(days: 29));
    } else {
      inicio = DateTime(
        sorted.first.fechaHora.year,
        sorted.first.fechaHora.month,
        sorted.first.fechaHora.day,
      );
      fin = DateTime(now.year, now.month, now.day);
    }

    final totalDias = fin.difference(inicio).inDays + 1;

    if (totalDias <= 30) {
      // Conteo diario
      final Map<DateTime, int> countByDay = {};
      for (int i = 0; i < totalDias; i++) {
        final day = DateTime(inicio.year, inicio.month, inicio.day + i);
        countByDay[day] = 0;
      }

      for (final c in crisisFiltradas) {
        final d = DateTime(
          c.fechaHora.year,
          c.fechaHora.month,
          c.fechaHora.day,
        );
        if (d.isBefore(inicio) || d.isAfter(fin)) continue;
        countByDay[d] = (countByDay[d] ?? 0) + 1;
      }

      return countByDay.entries.map((e) => CrisisData(e.key, e.value)).toList()
        ..sort((a, b) => a.fecha.compareTo(b.fecha));
    } else {
      // Conteo mensual
      final Map<String, int> countByMonth = {};

      // Inicializar todos los meses del rango
      DateTime temp = DateTime(inicio.year, inicio.month);
      while (!temp.isAfter(fin)) {
        final key = "${temp.year}-${temp.month}";
        countByMonth[key] = 0;
        temp = DateTime(temp.year, temp.month + 1);
      }

      for (final c in crisisFiltradas) {
        final key = "${c.fechaHora.year}-${c.fechaHora.month}";
        countByMonth[key] = (countByMonth[key] ?? 0) + 1;
      }

      List<CrisisData> chartData = [];
      countByMonth.forEach((key, value) {
        final parts = key.split('-');
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        chartData.add(CrisisData(DateTime(year, month, 1), value));
      });

      chartData.sort((a, b) => a.fecha.compareTo(b.fecha));
      return chartData;
    }
  }

  String obtenerDuracionModa(List<Crisis> crisisFiltradas) {
    if (crisisFiltradas.isEmpty) return "-";
    Map<String, int> freq = {};
    for (var c in crisisFiltradas) {
      String dur = c.duracion;
      freq[dur] = (freq[dur] ?? 0) + 1;
    }
    var moda = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return moda.first.key;
  }

  double obtenerPromedioGlobal() {
    final todas = crisisBox.values.toList();
    if (todas.isEmpty) return 0;

    todas.sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
    DateTime primera = todas.first.fechaHora;
    DateTime ultima = DateTime.now();

    int semanas = ((ultima.difference(primera).inDays) / 7).ceil();
    if (semanas == 0) semanas = 1;

    return todas.length / semanas;
  }

  Widget _buildResumenCrisisVisual(List<Crisis> crisisFiltradas) {
    if (crisisFiltradas.isEmpty) return const SizedBox();

    String totalTexto = filtroRango == 'Última semana'
        ? "${crisisFiltradas.length} crisis en la semana"
        : filtroRango == 'Último mes'
        ? "${crisisFiltradas.length} crisis en el mes"
        : "${crisisFiltradas.length} crisis totales";

    DateTime ultimaCrisis = crisisFiltradas.first.fechaHora;
    double promedioGlobal = obtenerPromedioGlobal();

    List<Map<String, dynamic>> resumenData = [
      {
        'titulo': 'Total',
        'valor': totalTexto,
        'icon': Icons.format_list_numbered,
        'color': Colors.green.shade100,
      },
      {
        'titulo': 'Duración más común',
        'valor': obtenerDuracionModa(crisisFiltradas),
        'icon': Icons.access_time,
        'color': Colors.orange.shade100,
      },
      {
        'titulo': 'Última crisis',
        'valor': DateFormat('dd/MM/yyyy – HH:mm', 'es').format(ultimaCrisis),
        'icon': Icons.history,
        'color': Colors.purple.shade100,
      },
      {
        'titulo': 'Promedio global',
        'valor': "${promedioGlobal.toStringAsFixed(2)} crisis/semana",
        'icon': Icons.show_chart,
        'color': Colors.blue.shade100,
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: resumenData.map((item) {
          return Container(
            width: (MediaQuery.of(context).size.width - 48) / 2,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: item['color'],
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha((0.05 * 255).round()),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(item['icon'], size: 28, color: Colors.grey.shade800),
                const SizedBox(height: 8),
                Text(
                  item['titulo'],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item['valor'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final crisisFiltradas = getCrisisFiltradas();
    final chartData = _generateChartData(crisisFiltradas);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: const CommonAppBar(title: 'Historial de Crisis'),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar por fecha o duración',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                ),
                onChanged: (val) => setState(() => searchQuery = val),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CheckboxListTile(
                value: mostrarTendencia,
                title: const Text("Mostrar gráfico de tendencia"),
                activeColor: const Color(0xFF1E3A8A),
                onChanged: (val) => setState(() => mostrarTendencia = val!),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFiltroButton('Última semana'),
                    const SizedBox(width: 8),
                    _buildFiltroButton('Último mes'),
                    const SizedBox(width: 8),
                    _buildFiltroButton('Todo'),
                  ],
                ),
              ),
            ),

            SizedBox(
              height: 220,
              child: SfCartesianChart(
                margin: const EdgeInsets.only(
                  left: 10,
                  right: 20,
                  top: 20,
                  bottom: 10,
                ),
                primaryXAxis: DateTimeAxis(
                  dateFormat: DateFormat('dd/MM', 'es'),
                  intervalType: DateTimeIntervalType.days,
                  majorGridLines: const MajorGridLines(width: 0),
                  maximum: chartData.isNotEmpty
                      ? chartData.last.fecha.add(const Duration(days: 1))
                      : null,
                ),
                primaryYAxis: NumericAxis(
                  title: AxisTitle(text: 'N° de crisis'),
                ),
                tooltipBehavior: TooltipBehavior(
                  enable: true,
                  format: 'point.x : point.y crisis',
                ),
                series: <CartesianSeries>[
                  mostrarTendencia
                      ? LineSeries<CrisisData, DateTime>(
                          dataSource: chartData,
                          xValueMapper: (CrisisData data, _) => data.fecha,
                          yValueMapper: (CrisisData data, _) => data.count,
                          color: const Color(0xFF1E3A8A),
                          markerSettings: const MarkerSettings(isVisible: true),
                          dataLabelSettings: DataLabelSettings(isVisible: true),
                        )
                      : ColumnSeries<CrisisData, DateTime>(
                          dataSource: chartData,
                          xValueMapper: (CrisisData data, _) => data.fecha,
                          yValueMapper: (CrisisData data, _) => data.count,
                          borderRadius: BorderRadius.circular(6),
                          color: const Color(0xFF1E3A8A),
                          dataLabelSettings: DataLabelSettings(isVisible: true),
                        ),
                ],
              ),
            ),
            _buildResumenCrisisVisual(crisisFiltradas),
            ...crisisFiltradas.map((crisis) {
              final index = crisisFiltradas.indexOf(crisis);
              final expanded = _expandedMap[index] ?? false;
              final faltaDetalles =
                  ((crisis.preictal ?? '').trim().isEmpty) ||
                  ((crisis.ictal ?? '').trim().isEmpty) ||
                  ((crisis.postictalSentimiento ?? '').trim().isEmpty) ||
                  ((crisis.postictalTiempoRecuperacion ?? '').trim().isEmpty);

              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _colorSegunDuracion(crisis.duracion),
                  border: Border(
                    left: BorderSide(
                      color: faltaDetalles
                          ? Colors.redAccent
                          : _bordeSegunDuracion(crisis.duracion),
                      width: 6,
                    ),
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha((0.05 * 255).round()),
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  title: Text(
                    DateFormat(
                      'dd MMM yyyy – HH:mm',
                      'es',
                    ).format(crisis.fechaHora),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Duración: ${crisis.duracion}'),
                      Text('Consciente: ${crisis.consciente}'),
                      Text(
                        'Medicamento de rescate: ${getNombreMedicamento(crisis)}',
                      ),
                      if (faltaDetalles)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: const [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.redAccent,
                                size: 18,
                              ),
                              SizedBox(width: 4),
                              Text(
                                "Faltan detalles de esta crisis",
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (expanded)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Divider(),
                              Text('Preictal: ${crisis.preictal ?? "-"}'),
                              Text('Ictal: ${crisis.ictal ?? "-"}'),
                              Text(
                                'Postictal - Sentimiento: ${crisis.postictalSentimiento ?? "-"}',
                              ),
                              Text(
                                'Postictal - Tiempo recuperación: ${crisis.postictalTiempoRecuperacion ?? "-"}',
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.edit_rounded,
                          color: Color(0xFF1E3A8A),
                        ),
                        onPressed: () => _abrirFormulario(crisis),
                      ),
                      IconButton(
                        icon: Icon(
                          expanded ? Icons.expand_less : Icons.expand_more,
                        ),
                        onPressed: () =>
                            setState(() => _expandedMap[index] = !expanded),
                      ),
                    ],
                  ),
                  onTap: () => setState(() => _expandedMap[index] = !expanded),
                ),
              );
            }).toList(),
            const SizedBox(height: 30),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1E3A8A),
        onPressed: () => _abrirFormulario(null),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildFiltroButton(String label) {
    final isSelected = filtroRango == label;
    return GestureDetector(
      onTap: () => setState(() => filtroRango = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E3A8A) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF1E3A8A) : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class CrisisData {
  final DateTime fecha;
  final int count;
  CrisisData(this.fecha, this.count);
}
