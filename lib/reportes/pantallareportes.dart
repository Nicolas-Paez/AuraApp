import 'package:flutter/material.dart';
import 'package:aura3/widgets/common_appbar.dart';
import 'package:flutter/rendering.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:aura3/models/Crisis.dart';
import 'package:aura3/models/TomaMedicamento.dart';
import 'package:aura3/models/EstadoAnimico.dart';
import 'package:aura3/utils/hive_boxes.dart';

class ReportesPage extends StatefulWidget {
  const ReportesPage({super.key});

  @override
  _ReportesPageState createState() => _ReportesPageState();
}

class _ReportesPageState extends State<ReportesPage> {
  DateTime fechaInicio = DateTime.now().subtract(Duration(days: 30));
  DateTime fechaFin = DateTime.now();

  List<Crisis> crisisList = [];
  List<TomaMedicamento> tomasList = [];
  List<EstadoAnimico> estadoList = [];
  // Key to capture the main chart as image for PDF export
  final GlobalKey _chartKey = GlobalKey();
  final GlobalKey _chartKey2 = GlobalKey();
  final GlobalKey _chartKey3 = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Iniciamos la carga de datos de forma asíncrona
    WidgetsBinding.instance.addPostFrameCallback((_) {
      cargarDatos();
    });
  }

  Future<void> cargarDatos() async {
    try {
      // Asegurarnos de que las cajas estén abiertas
      final crisisBox = await Hive.openBox<Crisis>(crisisBoxName);
      final tomasBox = await Hive.openBox<TomaMedicamento>(
        tomasMedicamentosBoxName,
      );
      final estadoBox = await Hive.openBox<EstadoAnimico>(estadoAnimicoBoxName);

      setState(() {
        crisisList = crisisBox.values
            .where(
              (c) =>
                  c.fechaHora.isAfter(fechaInicio) &&
                  c.fechaHora.isBefore(fechaFin),
            )
            .toList();

        tomasList = tomasBox.values
            .where(
              (t) =>
                  t.fechaProgramada.isAfter(fechaInicio) &&
                  t.fechaProgramada.isBefore(fechaFin),
            )
            .toList();

        estadoList = estadoBox.values
            .where(
              (e) => e.fecha.isAfter(fechaInicio) && e.fecha.isBefore(fechaFin),
            )
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar datos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // -------------------- Datos calculados --------------------
  Map<DateTime, int> getCrisisPorDia() {
    final map = <DateTime, int>{};
    for (var c in crisisList) {
      final dia = DateTime(
        c.fechaHora.year,
        c.fechaHora.month,
        c.fechaHora.day,
      );
      map[dia] = (map[dia] ?? 0) + 1;
    }
    return map;
  }

  Map<DateTime, int> tomasPorDia() {
    final map = <DateTime, int>{};
    for (var t in tomasList) {
      if (t.fechaReal != null) {
        final dia = DateTime(
          t.fechaReal!.year,
          t.fechaReal!.month,
          t.fechaReal!.day,
        );
        map[dia] = (map[dia] ?? 0) + 1;
      }
    }
    return map;
  }

  Map<DateTime, double> promedioEstadoAntes() {
    final map = <DateTime, List<int>>{};
    for (var c in crisisList) {
      if (c.estadoAnimoAntes != null) {
        final dia = DateTime(
          c.fechaHora.year,
          c.fechaHora.month,
          c.fechaHora.day,
        );
        map.putIfAbsent(dia, () => []).add(c.estadoAnimoAntes!);
      }
    }
    final promedio = <DateTime, double>{};
    map.forEach((key, list) {
      promedio[key] = list.reduce((a, b) => a + b) / list.length;
    });
    return promedio;
  }

  Map<DateTime, double> promedioEstadoDespues() {
    final map = <DateTime, List<int>>{};
    for (var c in crisisList) {
      if (c.estadoAnimoDespues != null) {
        final dia = DateTime(
          c.fechaHora.year,
          c.fechaHora.month,
          c.fechaHora.day,
        );
        map.putIfAbsent(dia, () => []).add(c.estadoAnimoDespues!);
      }
    }
    final promedio = <DateTime, double>{};
    map.forEach((key, list) {
      promedio[key] = list.reduce((a, b) => a + b) / list.length;
    });
    return promedio;
  }

  // -------------------- Estadísticas adicionales --------------------
  int totalCrisis() => crisisList.length;

  double? averageDurationMinutes() {
    final minutes = <double>[];
    for (var c in crisisList) {
      final m = _parseDurationToMinutes(c.duracion);
      if (m != null) minutes.add(m);
    }
    if (minutes.isEmpty) return null;
    return minutes.reduce((a, b) => a + b) / minutes.length;
  }

  String mostFrequentDuration() {
    if (crisisList.isEmpty) return '-';
    final freq = <String, int>{};
    for (var c in crisisList) {
      freq[c.duracion] = (freq[c.duracion] ?? 0) + 1;
    }
    final sorted = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  DateTime? lastCrisisDate() {
    if (crisisList.isEmpty) return null;
    crisisList.sort((a, b) => b.fechaHora.compareTo(a.fechaHora));
    return crisisList.first.fechaHora;
  }

  double? _parseDurationToMinutes(String dur) {
    // Try to extract numeric value and unit (min, m, s, sec)
    final re = RegExp(
      r"([0-9]+\.?[0-9]*)\s*(h|hr|hrs|m|min|minutes|s|sec|seconds)?",
      caseSensitive: false,
    );
    final match = re.firstMatch(dur);
    if (match == null) return null;
    final numStr = match.group(1);
    final unit = match.group(2)?.toLowerCase();
    if (numStr == null) return null;
    final value = double.tryParse(numStr);
    if (value == null) return null;
    if (unit == null ||
        unit.startsWith('m') ||
        unit == 'min' ||
        unit == 'minutes') {
      return value; // minutes
    } else if (unit.startsWith('h')) {
      return value * 60; // hours to minutes
    } else if (unit.startsWith('s') || unit == 'sec' || unit == 'seconds') {
      return value / 60.0; // seconds to minutes
    }
    return null;
  }

  List<_ChartDataMulti> generarDatosMedicacionVsCrisis() {
    final crisisDia = getCrisisPorDia();
    final tomasDia = tomasPorDia();
    final dias = <DateTime>{};
    dias.addAll(crisisDia.keys);
    dias.addAll(tomasDia.keys);

    final lista = dias.map((dia) {
      return _ChartDataMulti(dia, crisisDia[dia] ?? 0, tomasDia[dia] ?? 0);
    }).toList()..sort((a, b) => a.fecha.compareTo(b.fecha));

    return lista;
  }

  List<_ScatterData> generarDatosCorrelacion() {
    final crisisDia = getCrisisPorDia();
    final tomasDia = tomasPorDia();
    final dias = <DateTime>{};
    dias.addAll(crisisDia.keys);
    dias.addAll(tomasDia.keys);

    return dias.map((dia) {
      final c = crisisDia[dia] ?? 0;
      final t = tomasDia[dia] ?? 0;
      return _ScatterData(t, c);
    }).toList();
  }

  // -------------------- Exportar PDF --------------------
  void exportarPDF() async {
    final pdf = pw.Document();

    final crisisDia = getCrisisPorDia();
    final tomasDia = tomasPorDia();
    final antes = promedioEstadoAntes();
    final despues = promedioEstadoDespues();

    // Try to capture the chart image (if available) from the UI
    Uint8List? chartPng;
    try {
      final boundary =
          _chartKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary != null) {
        final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        chartPng = byteData?.buffer.asUint8List();
      }
    } catch (e) {
      // Non-fatal: we'll still produce the PDF without the chart image
      print('⚠️ No fue posible capturar la imagen del gráfico: $e');
    }

    // Prepare sorted crisis list for PDF details
    final sortedCrises = crisisList.toList()
      ..sort((a, b) => b.fechaHora.compareTo(a.fechaHora));

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(level: 0, text: 'Reporte de Epilepsia'),
          pw.Text(
            'Rango de fechas: ${fechaInicio.toLocal()} - ${fechaFin.toLocal()}',
          ),
          pw.SizedBox(height: 8),

          // Summary stats
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Total crisis: ${totalCrisis()}'),
              pw.Text(
                'Duración promedio (min): ${averageDurationMinutes() != null ? averageDurationMinutes()!.toStringAsFixed(1) : '-'}',
              ),
              pw.Text('Duración más frecuente: ${mostFrequentDuration()}'),
              pw.Text(
                'Última crisis: ${lastCrisisDate() != null ? lastCrisisDate()!.toLocal().toString().split(' ')[0] : '-'}',
              ),
            ],
          ),
          pw.SizedBox(height: 10),

          // Chart image (if captured)
          if (chartPng != null)
            pw.Center(child: pw.Image(pw.MemoryImage(chartPng), width: 450)),
          if (chartPng != null) pw.SizedBox(height: 10),

          // Tables: Crisis por día
          pw.Text('Crisis por día:'),
          pw.TableHelper.fromTextArray(
            data: [
              ['Fecha', 'Cantidad de crisis'],
              ...crisisDia.entries
                  .map(
                    (e) => [e.key.toString().split(' ')[0], e.value.toString()],
                  )
                  .toList(),
            ],
          ),
          pw.SizedBox(height: 8),

          // Tomas por día
          pw.Text('Tomas de medicación por día:'),
          pw.TableHelper.fromTextArray(
            data: [
              ['Fecha', 'Cantidad de tomas'],
              ...tomasDia.entries
                  .map(
                    (e) => [e.key.toString().split(' ')[0], e.value.toString()],
                  )
                  .toList(),
            ],
          ),
          pw.SizedBox(height: 8),

          // Estado anímico promedio
          pw.Text('Promedio estado anímico antes/después:'),
          pw.TableHelper.fromTextArray(
            data: [
              ['Fecha', 'Antes', 'Después'],
              ...antes.entries.map((e) {
                final d = despues[e.key]?.toStringAsFixed(1) ?? '-';
                return [
                  e.key.toString().split(' ')[0],
                  e.value.toStringAsFixed(1),
                  d,
                ];
              }).toList(),
            ],
          ),

          pw.SizedBox(height: 12),
          pw.Header(level: 1, text: 'Detalle de crisis'),

          // Detailed crisis entries
          if (sortedCrises.isEmpty)
            pw.Text('No hay crisis en el rango seleccionado.')
          else
            ...sortedCrises.map((c) {
              final lines = <pw.Widget>[];
              lines.add(
                pw.Text(
                  '${c.fechaHora.toLocal().toString().split(' ')[0]} - ${c.duracion}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              );
              lines.add(pw.Text('Consciente: ${c.consciente}'));
              if (c.preictal != null)
                lines.add(pw.Text('Preictal: ${c.preictal}'));
              if (c.ictal != null) lines.add(pw.Text('Ictal: ${c.ictal}'));
              if (c.postictalSentimiento != null)
                lines.add(
                  pw.Text('Postictal - Sentimiento: ${c.postictalSentimiento}'),
                );
              if (c.postictalTiempoRecuperacion != null)
                lines.add(
                  pw.Text(
                    'Tiempo recuperación: ${c.postictalTiempoRecuperacion}',
                  ),
                );
              if (c.estadoAnimoAntes != null)
                lines.add(
                  pw.Text('Estado anímico antes: ${c.estadoAnimoAntes} / 5'),
                );
              if (c.estadoAnimoDespues != null)
                lines.add(
                  pw.Text(
                    'Estado anímico después: ${c.estadoAnimoDespues} / 5',
                  ),
                );
              if (c.observacionesAdicionales != null)
                lines.add(
                  pw.Text('Observaciones: ${c.observacionesAdicionales}'),
                );
              lines.add(pw.SizedBox(height: 8));
              return pw.Column(children: lines);
            }).toList(),
        ],
      ),
    );

    try {
      final bytes = await pdf.save();
      await Printing.sharePdf(bytes: bytes, filename: 'reporte_epilepsia.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error generando PDF: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final crisisData =
        getCrisisPorDia().entries
            .map((e) => _ChartData(e.key, e.value))
            .toList()
          ..sort((a, b) => a.fecha.compareTo(b.fecha));

    final antesData =
        promedioEstadoAntes().entries
            .map((e) => _ChartDataDouble(e.key, e.value))
            .toList()
          ..sort((a, b) => a.fecha.compareTo(b.fecha));

    final despuesData =
        promedioEstadoDespues().entries
            .map((e) => _ChartDataDouble(e.key, e.value))
            .toList()
          ..sort((a, b) => a.fecha.compareTo(b.fecha));

    final multiData = generarDatosMedicacionVsCrisis();
    final scatterData = generarDatosCorrelacion();

    // Preparar lista de widgets para las crisis (orden descendente por fecha)
    final sortedCrises = crisisList.toList()
      ..sort((a, b) => b.fechaHora.compareTo(a.fechaHora));

    final crisisTiles = sortedCrises
        .map(
          (c) => ExpansionTile(
            title: Text(
              '${c.fechaHora.toLocal().toString().split(' ')[0]} - ${c.duracion}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text('Consciente: ${c.consciente}'),
            children: [
              if (c.preictal != null)
                ListTile(
                  title: const Text('Preictal'),
                  subtitle: Text(c.preictal!),
                ),
              if (c.ictal != null)
                ListTile(title: const Text('Ictal'), subtitle: Text(c.ictal!)),
              if (c.postictalSentimiento != null)
                ListTile(
                  title: const Text('Postictal - Sentimiento'),
                  subtitle: Text(c.postictalSentimiento!),
                ),
              if (c.postictalTiempoRecuperacion != null)
                ListTile(
                  title: const Text('Tiempo recuperación'),
                  subtitle: Text(c.postictalTiempoRecuperacion!),
                ),
              if (c.estadoAnimoAntes != null)
                ListTile(
                  title: const Text('Estado anímico antes'),
                  subtitle: Text('${c.estadoAnimoAntes} / 5'),
                ),
              if (c.estadoAnimoDespues != null)
                ListTile(
                  title: const Text('Estado anímico después'),
                  subtitle: Text('${c.estadoAnimoDespues} / 5'),
                ),
              if (c.observacionesAdicionales != null)
                ListTile(
                  title: const Text('Observaciones'),
                  subtitle: Text(c.observacionesAdicionales!),
                ),
            ],
          ),
        )
        .toList();

    return Scaffold(
      appBar: CommonAppBar(
        title: 'Reportes',
        actions: [
          TextButton.icon(
            onPressed: exportarPDF,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            icon: const Icon(Icons.download),
            label: const Text('Descargar PDF'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    child: Text(
                      'Desde: ${fechaInicio.toLocal().toString().split(' ')[0]}',
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: fechaInicio,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() => fechaInicio = picked);
                        cargarDatos();
                      }
                    },
                  ),
                ),
                Expanded(
                  child: TextButton(
                    child: Text(
                      'Hasta: ${fechaFin.toLocal().toString().split(' ')[0]}',
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: fechaFin,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() => fechaFin = picked);
                        cargarDatos();
                      }
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // -------------------- Resumen rápido --------------------
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatItem(
                        label: 'Total crisis',
                        value: '${totalCrisis()}',
                        color: Colors.redAccent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatItem(
                        label: 'Duración promedio (min)',
                        value: averageDurationMinutes() != null
                            ? averageDurationMinutes()!.toStringAsFixed(1)
                            : '-',
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatItem(
                        label: 'Duración más frecuente',
                        value: mostFrequentDuration(),
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatItem(
                        label: 'Última crisis',
                        value: lastCrisisDate() != null
                            ? lastCrisisDate()!.toLocal().toString().split(
                                ' ',
                              )[0]
                            : '-',
                        color: Colors.blueGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 1️⃣ Crisis y estado anímico
            SizedBox(
              height: 300,
              child: RepaintBoundary(
                key: _chartKey,
                child: SfCartesianChart(
                  primaryXAxis: DateTimeAxis(),
                  title: ChartTitle(text: 'Crisis y estado anímico'),
                  legend: Legend(isVisible: true),
                  tooltipBehavior: TooltipBehavior(enable: true),
                  series: [
                    ColumnSeries<_ChartData, DateTime>(
                      dataSource: crisisData,
                      xValueMapper: (_ChartData d, _) => d.fecha,
                      yValueMapper: (_ChartData d, _) => d.cantidad,
                      name: 'Crisis',
                      color: Colors.redAccent,
                      dataLabelSettings: DataLabelSettings(isVisible: true),
                    ),
                    LineSeries<_ChartDataDouble, DateTime>(
                      dataSource: antesData,
                      xValueMapper: (_ChartDataDouble d, _) => d.fecha,
                      yValueMapper: (_ChartDataDouble d, _) => d.valor,
                      name: 'Estado antes',
                      color: Colors.blue,
                    ),
                    LineSeries<_ChartDataDouble, DateTime>(
                      dataSource: despuesData,
                      xValueMapper: (_ChartDataDouble d, _) => d.fecha,
                      yValueMapper: (_ChartDataDouble d, _) => d.valor,
                      name: 'Estado después',
                      color: Colors.green,
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 32),

            // 2️⃣ Medicación vs crisis
            SizedBox(
              height: 300,
              child: RepaintBoundary(
                key: _chartKey2,
                child: SfCartesianChart(
                  primaryXAxis: DateTimeAxis(),
                  title: ChartTitle(
                    text: 'Crisis vs Medicación tomada por día',
                  ),
                  legend: Legend(isVisible: true),
                  tooltipBehavior: TooltipBehavior(enable: true),
                  series: [
                    ColumnSeries<_ChartDataMulti, DateTime>(
                      dataSource: multiData,
                      xValueMapper: (_ChartDataMulti d, _) => d.fecha,
                      yValueMapper: (_ChartDataMulti d, _) => d.crisis,
                      name: 'Crisis',
                      color: Colors.redAccent,
                      dataLabelSettings: DataLabelSettings(isVisible: true),
                    ),
                    ColumnSeries<_ChartDataMulti, DateTime>(
                      dataSource: multiData,
                      xValueMapper: (_ChartDataMulti d, _) => d.fecha,
                      yValueMapper: (_ChartDataMulti d, _) => d.tomas,
                      name: 'Tomas',
                      color: Colors.green,
                      dataLabelSettings: DataLabelSettings(isVisible: true),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 32),

            // 3️⃣ Scatter plot: correlación medicación vs crisis
            SizedBox(
              height: 300,
              child: RepaintBoundary(
                key: _chartKey3,
                child: SfCartesianChart(
                  primaryXAxis: NumericAxis(
                    title: AxisTitle(text: 'Tomas de medicación'),
                  ),
                  primaryYAxis: NumericAxis(
                    title: AxisTitle(text: 'Número de crisis'),
                  ),
                  title: ChartTitle(text: 'Correlación: Medicación vs Crisis'),
                  tooltipBehavior: TooltipBehavior(enable: true),
                  series: <CartesianSeries<_ScatterData, int>>[
                    ScatterSeries<_ScatterData, int>(
                      dataSource: scatterData,
                      xValueMapper: (_ScatterData d, _) => d.tomas,
                      yValueMapper: (_ScatterData d, _) => d.crisis,
                      name: 'Días',
                      markerSettings: MarkerSettings(
                        isVisible: true,
                        width: 10,
                        height: 10,
                      ),
                      color: Colors.purple,
                      trendlines: [
                        Trendline(
                          type: TrendlineType.linear,
                          color: Colors.black,
                          width: 2,
                          name: 'Tendencia',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 32),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Lista de crisis',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            if (crisisTiles.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text('No hay crisis en el rango seleccionado.'),
              )
            else
              ...crisisTiles,
          ],
        ),
      ),
    );
  }
}

// -------------------- Clases de datos para gráficos --------------------
class _ChartData {
  final DateTime fecha;
  final int cantidad;
  _ChartData(this.fecha, this.cantidad);
}

class _ChartDataDouble {
  final DateTime fecha;
  final double valor;
  _ChartDataDouble(this.fecha, this.valor);
}

class _ChartDataMulti {
  final DateTime fecha;
  final int crisis;
  final int tomas;
  _ChartDataMulti(this.fecha, this.crisis, this.tomas);
}

class _ScatterData {
  final int tomas;
  final int crisis;
  _ScatterData(this.tomas, this.crisis);
}

// -------------------- Small helper widgets --------------------
class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withAlpha((0.12 * 255).round()),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
