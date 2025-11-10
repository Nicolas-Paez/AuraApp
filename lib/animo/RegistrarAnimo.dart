import 'package:flutter/material.dart';
import 'package:aura3/widgets/common_appbar.dart';
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';
import '../models/EstadoAnimico.dart';

class RegistrarAnimoScreen extends StatefulWidget {
  const RegistrarAnimoScreen({super.key});

  @override
  State<RegistrarAnimoScreen> createState() => _RegistrarAnimoScreenState();
}

class _RegistrarAnimoScreenState extends State<RegistrarAnimoScreen> {
  double valencia = 50;
  double activacion = 50;

  final Map<String, bool> sintomasSelected = {
    'Mareo': false,
    'Cansancio / Fatiga': false,
    'Confusión': false,
    'Dolor de cabeza': false,
    'Malestar general': false,
  };

  String _deriveEmotion(int val, int act) {
    // Solo estados anímicos concretos
    const emociones = [
      {'nombre': 'Euforia', 'v': 90, 'a': 90},
      {'nombre': 'Alegría', 'v': 80, 'a': 80},
      {'nombre': 'Serenidad', 'v': 80, 'a': 30},
      {'nombre': 'Relajación', 'v': 75, 'a': 20},
      {'nombre': 'Satisfacción', 'v': 85, 'a': 40},
      {'nombre': 'Ansiedad', 'v': 20, 'a': 85},
      {'nombre': 'Ira', 'v': 10, 'a': 90},
      {'nombre': 'Miedo', 'v': 20, 'a': 80},
      {'nombre': 'Tensión', 'v': 25, 'a': 85},
      {'nombre': 'Tristeza', 'v': 20, 'a': 20},
      {'nombre': 'Abatimiento', 'v': 15, 'a': 10},
      {'nombre': 'Depresión', 'v': 10, 'a': 15},
      {'nombre': 'Aburrimiento', 'v': 30, 'a': 10},
      {'nombre': 'Desinterés', 'v': 40, 'a': 15},
    ];
    double minDist = double.infinity;
    String best = 'Neutral';
    for (final e in emociones) {
      final dv = (val - (e['v'] as int)).toDouble();
      final da = (act - (e['a'] as int)).toDouble();
      final dist = dv * dv + da * da;
      if (dist < minDist) {
        minDist = dist;
        best = e['nombre']! as String;
      }
    }
    return best;
  }

  Future<void> _guardar() async {
    final fecha = DateTime.now();
    // Convert selected symptoms map to a List<String> as expected by the model
    final sintomasList = <String>[];
    sintomasSelected.forEach((k, v) {
      if (v) sintomasList.add(k);
    });

    // Map the 0-100 sliders into 1-5 levels used by EstadoAnimico
    int mapToLevel(double value) {
      // value range 0..100 -> levels 1..5
      return (value / 25).clamp(0, 4).round() + 1;
    }

    final nivelAnimo = mapToLevel(valencia);
    final nivelAnsiedad = mapToLevel(activacion);
    // Use activacion as a proxy for irritability for now
    final nivelIrritabilidad = mapToLevel(activacion);

    final registro = EstadoAnimico(
      fecha: fecha,
      nivelAnimo: nivelAnimo,
      nivelAnsiedad: nivelAnsiedad,
      nivelIrritabilidad: nivelIrritabilidad,
      sintomas: sintomasList,
    );

    final box = await Hive.openBox<EstadoAnimico>('animoBox');
    // Registrar sin borrar: simplemente añadir al final
    await box.add(registro);

    // Mensaje y volver atrás
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Estado ánimo guardado')));
    Navigator.of(context).pop();
  }

  Widget _emojiRow(double value) {
    // 5 emojis mapping to ranges
    final idx = (value / 20).clamp(0, 4).floor();
    final icons = ['😢', '☹️', '😐', '🙂', '😄'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(5, (i) {
        return Opacity(
          opacity: i == idx ? 1.0 : 0.4,
          child: Text(icons[i], style: const TextStyle(fontSize: 28)),
        );
      }),
    );
  }

  Widget _energyRow(double value) {
    final idx = (value / 20).clamp(0, 4).floor();
    // Iconos universales para energía: muy baja, baja, media, alta, muy alta
    final icons = ['😴', '🔋', '😐', '⚡️', '🔥'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(5, (i) {
        return Opacity(
          opacity: i == idx ? 1.0 : 0.4,
          child: Text(icons[i], style: const TextStyle(fontSize: 28)),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(title: 'Registrar Estado Anímico'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            const Text(
              'En este momento, ¿cómo te sientes en general?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Center(child: _emojiRow(valencia)),
            Slider(
              value: valencia,
              min: 0,
              max: 100,
              divisions: 100,
              label: valencia.round().toString(),
              onChanged: (v) => setState(() => valencia = v),
            ),
            const SizedBox(height: 12),
            const Text(
              'En este momento, ¿cómo está tu energía?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Center(child: _energyRow(activacion)),
            Slider(
              value: activacion,
              min: 0,
              max: 100,
              divisions: 100,
              label: activacion.round().toString(),
              onChanged: (v) => setState(() => activacion = v),
            ),
            const SizedBox(height: 18),
            const Text(
              '¿Tienes alguno de estos síntomas ahora?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...sintomasSelected.keys.map((s) {
              final selected = sintomasSelected[s]!;
              return Row(
                children: [
                  Checkbox(
                    value: selected,
                    onChanged: (v) =>
                        setState(() => sintomasSelected[s] = v ?? false),
                  ),
                  Expanded(child: Text(s)),
                ],
              );
            }).toList(),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _guardar,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Guardar',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Ejemplo de registro más abajo:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Fecha: ${DateFormat.yMMMMd().format(DateTime.now())}'),
            Text(
              'Valor vectorizado (0-100): ${((valencia + activacion) / 2).round()}',
            ),
            Text(
              'Emoción (estimada): ${_deriveEmotion(((valencia + activacion) / 2).round(), activacion.round())}',
            ),
          ],
        ),
      ),
    );
  }
}
