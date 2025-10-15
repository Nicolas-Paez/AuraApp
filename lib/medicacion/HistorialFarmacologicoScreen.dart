import 'package:flutter/material.dart';

class HistorialFarmacologicoScreen extends StatelessWidget {
  const HistorialFarmacologicoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final medicamentos = [
      {
        'nombre': 'Levetiracetam',
        'dosis': '500 mg',
        'inicio': '12/08/2024',
        'adherencia': '92%',
        'alertas': '2 omisiones, 1 retraso',
      },
      {
        'nombre': 'Ácido Valproico',
        'dosis': '300 mg',
        'inicio': '20/07/2024',
        'adherencia': '95%',
        'alertas': '1 omisión',
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E3A8A),
        title: const Text('Historial Farmacológico'),
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: medicamentos.length,
        itemBuilder: (context, index) {
          final med = medicamentos[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  med['nombre']!,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text('Dosis actual: ${med['dosis']}'),
                Text('Inicio: ${med['inicio']}'),
                const SizedBox(height: 8),
                Text('Adherencia promedio: ${med['adherencia']}'),
                Text('Alertas: ${med['alertas']}'),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    child: const Text(
                      'Ver Detalles',
                      style: TextStyle(color: Color(0xFF1E3A8A)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
