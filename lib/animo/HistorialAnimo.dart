import 'package:flutter/material.dart';
import 'package:aura3/widgets/common_appbar.dart';
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';
import '../models/EstadoAnimico.dart';

class HistorialAnimoScreen extends StatefulWidget {
  const HistorialAnimoScreen({Key? key}) : super(key: key);

  @override
  State<HistorialAnimoScreen> createState() => _HistorialAnimoScreenState();
}

class _HistorialAnimoScreenState extends State<HistorialAnimoScreen> {
  Box<EstadoAnimico>? box;

  // Color scale based on nivelAnimo (1-5)
  Color _colorForNivel(int nivel) {
    switch (nivel) {
      case 5:
        return Colors.green;
      case 4:
        return Colors.lightGreen;
      case 3:
        return Colors.amber;
      case 2:
        return Colors.orange;
      case 1:
      default:
        return Colors.redAccent;
    }
  }

  String _iconForNivel(int nivel) {
    switch (nivel) {
      case 5:
        return '�';
      case 4:
        return '�';
      case 3:
        return '';
      case 2:
        return '�';
      case 1:
      default:
        return '�';
    }
  }

  @override
  void initState() {
    super.initState();
    _openBox();
  }

  Future<void> _openBox() async {
    final b = await Hive.openBox<EstadoAnimico>('animoBox');
    if (mounted) setState(() => box = b);
  }

  @override
  Widget build(BuildContext context) {
    if (box == null || !box!.isOpen) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final items = box!.values.toList().reversed.toList();
    return Scaffold(
      appBar: CommonAppBar(
        title: 'Historial Estado Anímico',
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              // Aquí puedes navegar a la pantalla de registro
            },
          ),
        ],
      ),
      body: items.isEmpty
          ? const Center(child: Text('No hay registros aún'))
          : ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, i) {
                final e = items[i];
                final color = _colorForNivel(e.nivelAnimo);
                final icon = _iconForNivel(e.nivelAnimo);
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color,
                      child: Text(
                        icon, // emoji
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                    title: Text(
                      'Estado (nivel ${e.nivelAnimo})',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${DateFormat.yMMMd().format(e.fecha)} · Promedio ${e.promedioEstado.toStringAsFixed(1)}',
                        ),
                        if (e.sintomas.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              'Síntomas: ' + e.sintomas.join(', '),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        if (e.notas != null && e.notas!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Text(
                              'Notas: ${e.notas}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'N:${e.nivelAnimo}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          'Ans:${e.nivelAnsiedad}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          'Irr:${e.nivelIrritabilidad}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
