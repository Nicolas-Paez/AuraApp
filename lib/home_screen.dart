import 'package:aura3/crisis/HistorialCrisis';
import 'package:aura3/medicacion/AnadirMedicamentoScreen.dart';
import 'package:aura3/medicacion/HistorialFarmacologicoScreen.dart';
import 'package:flutter/material.dart';
import 'package:aura3/crisis/registrarCrisis';

// --------------------------------------------------
// PANTALLA PRINCIPAL DEL MÓDULO CENTRAL DE AURA
// --------------------------------------------------

class HomeScreen extends StatefulWidget {
  final String nombreUsuario;
  const HomeScreen({super.key, required this.nombreUsuario});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool crisisExpanded = false;
  bool medicacionExpanded = false;
  bool animoExpanded = false;

  void toggleExpand(String section) {
    setState(() {
      if (section == 'crisis') {
        crisisExpanded = !crisisExpanded;
        medicacionExpanded = false;
        animoExpanded = false;
      } else if (section == 'medicacion') {
        medicacionExpanded = !medicacionExpanded;
        crisisExpanded = false;
        animoExpanded = false;
      } else if (section == 'animo') {
        animoExpanded = !animoExpanded;
        crisisExpanded = false;
        medicacionExpanded = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hola, ${widget.nombreUsuario}',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 24),

                // ---- Cards principales ----
                _buildExpandableTile(
                  title: 'Crisis',
                  color: const Color(0xFF60A5FA),
                  icon: Icons.warning_amber_rounded,
                  expanded: crisisExpanded,
                  onTap: () => toggleExpand('crisis'),
                  children: [
                    _SubOption(
                      label: 'Registrar crisis',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PantallaRegistrarCrisis(),
                          ),
                        );
                      },
                    ),
                    _SubOption(
                      label: 'Historial de crisis',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HistorialCrisisScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                _buildExpandableTile(
                  title: 'Medicación',
                  color: const Color(0xFF4ADE80),
                  icon: Icons.medication_rounded,
                  expanded: medicacionExpanded,
                  onTap: () => toggleExpand('medicacion'),
                  children: [
                    _SubOption(
                      label: 'Añadir medicamento',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AnadirMedicamentoScreen(),
                          ),
                        );
                      },
                    ),
                    _SubOption(
                      label: 'Modificar dosis o horario',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AnadirMedicamentoScreen(),
                          ),
                        );
                      },
                    ),
                    _SubOption(
                      label: 'Historial farmacológico',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HistorialFarmacologicoScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                _buildExpandableTile(
                  title: 'Mi Ánimo',
                  color: const Color(0xFF166534),
                  icon: Icons.emoji_emotions_rounded,
                  expanded: animoExpanded,
                  onTap: () => toggleExpand('animo'),
                  children: [
                    _SubOption(label: 'Registrar estado anímico', onTap: () {}),
                    _SubOption(label: 'Historial estado anímico', onTap: () {}),
                  ],
                ),

                _SimpleTile(
                  title: 'Reportes',
                  color: const Color(0xFF6B7280),
                  icon: Icons.bar_chart_rounded,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => PantallaReportes()),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // ---- Botón inferior grande Registrar Crisis ----
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PantallaRegistrarCrisis(),
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A8A),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded, color: Colors.white, size: 36),
                        SizedBox(height: 8),
                        Text(
                          "Registrar Crisis",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableTile({
    required String title,
    required Color color,
    required IconData icon,
    required bool expanded,
    required VoidCallback onTap,
    required List<Widget> children,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
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
        children: [
          ListTile(
            leading: Icon(icon, color: Colors.white, size: 30),
            title: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            trailing: Icon(
              expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: Colors.white,
              size: 30,
            ),
            onTap: onTap,
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: expanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.white.withOpacity(0.1),
              child: Column(children: children),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------
// SUBOPCIONES EXPANDIBLES
// --------------------------------------------------
class _SubOption extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SubOption({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------
// TILE SIMPLE
// --------------------------------------------------
class _SimpleTile extends StatelessWidget {
  final String title;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _SimpleTile({
    required this.title,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ListTile(
          leading: Icon(icon, color: Colors.white, size: 30),
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------
// PANTALLAS PLACEHOLDER (restantes)
// --------------------------------------------------

class PantallaReportes extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reportes')),
      body: const Center(child: Text('Vista de reportes del usuario')),
    );
  }
}
