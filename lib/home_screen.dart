import 'package:flutter/material.dart';
import 'package:aura3/widgets/common_appbar.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:aura3/crisis/HistorialCrisis.dart';
import 'package:aura3/crisis/RegistrarCrisis.dart';
import 'package:aura3/medicacion/AnadirMedicamentoScreen.dart';
import 'package:aura3/models/TomaMedicamento.dart';
import 'package:aura3/medicacion/HistorialFarmacologicoScreen.dart';
import 'package:aura3/medicacion/ListadoMedicamentos.dart';
import 'package:aura3/models/Medicamento.dart';
import 'package:aura3/models/Crisis.dart';
import 'package:aura3/animo/RegistrarAnimo.dart';
import 'package:aura3/animo/HistorialAnimo.dart';
import 'package:aura3/utils/notifications.dart';
import 'package:aura3/reportes/pantallareportes.dart';
import 'package:aura3/utils/hive_boxes.dart';
// Asegurar que tenemos las funciones de marcar medicamentos

class HomeScreen extends StatefulWidget {
  final String nombreUsuario;
  const HomeScreen({super.key, required this.nombreUsuario});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final Map<int, bool> _loadedTabs = {};
  final List<Widget> _screenCache = [];
  bool _showDebugButton = false;

  var _crisisListenable;
  int _lastNotifiedPendingCrisisCount = 0;

  @override
  void initState() {
    super.initState();
    _loadedTabs[0] = true;
    _initializeScreens();

    _screens.addAll([
      _HomeContent(),
      const HistorialCrisisScreen(),
      const ReportesPage(),
    ]);

    Future.microtask(() async {
      await _preloadEssentialData();

      try {
        // Ensure we're using the constant and the box is actually open
        if (Hive.isBoxOpen(crisisBoxName)) {
          _crisisListenable = Hive.box<Crisis>(crisisBoxName).listenable();
          _crisisListenable?.addListener(_crisisBoxListener);
          _lastNotifiedPendingCrisisCount = getPendingCrisisCount();
        } else {
          print('Crisis box not yet open, skipping listener initialization');
        }
      } catch (e) {
        print('No se pudo iniciar listener de crisis: $e');
      }

      assert(() {
        setState(() => _showDebugButton = true);
        return true;
      }());
    });
  }

  void _initializeScreens() {
    _screenCache.addAll(List.generate(5, (index) => _buildLazyScreen(index)));
  }

  Future<void> _preloadEssentialData() async {
    try {
      // **ACTUALIZACIÓN:** Esperamos a que la caja de Tomas Medicamentos también esté abierta.
      while (!Hive.isBoxOpen(medicamentosBoxName) ||
          !Hive.isBoxOpen(crisisBoxName) ||
          !Hive.isBoxOpen(tomasMedicamentosBoxName)) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } catch (e) {
      print('Error precargando datos esenciales: $e');
    }
  }

  Widget _buildLazyScreen(int index) {
    // Minimal lazy loader placeholder: real implementation may replace this
    return FutureBuilder<Box?>(
      future: _getBoxForIndex(index),
      builder: (context, snapshot) {
        // Do not show blocking loading indicators here; always render the
        // target screen. Individual screens should guard against missing
        // Hive boxes if needed.
        return _buildScreenForIndex(index);
      },
    );
  }

  Future<Box?> _getBoxForIndex(int index) async {
    if (index == 1 && Hive.isBoxOpen(crisisBoxName)) {
      return Hive.box<Crisis>(crisisBoxName);
    } else if (index == 2 && Hive.isBoxOpen(medicamentosBoxName)) {
      return Hive.box<Medicamento>(medicamentosBoxName);
    }
    return null;
  }

  Widget _buildScreenForIndex(int index) {
    switch (index) {
      case 0:
        return Stack(
          children: [
            Center(child: Text('Bienvenido ${widget.nombreUsuario}')),
            if (_showDebugButton) _buildDebugButton(),
          ],
        );
      case 1:
        return const HistorialCrisisScreen();
      case 2:
        return const ListarMedicamentosScreen();
      default:
        return const Center(child: Text('Pantalla no implementada'));
    }
  }

  Widget _buildDebugButton() {
    return Positioned(
      right: 16,
      bottom: 80,
      child: FloatingActionButton(
        heroTag: 'debugButton',
        onPressed: () async {
          final now = DateTime.now();
          await showMedicationDialogForKeyAndTime(1, now);
        },
        backgroundColor: Colors.red.withAlpha(179),
        mini: true,
        child: const Icon(Icons.bug_report),
      ),
    );
  }

  int getPendingCrisisCount() {
    if (!Hive.isBoxOpen(crisisBoxName)) return 0;
    final box = Hive.box<Crisis>(crisisBoxName);

    return box.values.where((crisis) {
      return crisis.preictal == null ||
          crisis.ictal == null ||
          crisis.postictalSentimiento == null ||
          crisis.postictalTiempoRecuperacion == null ||
          crisis.estadoAnimoAntes == null ||
          crisis.estadoAnimoDespues == null;
    }).length;
  }

  // **ACTUALIZACIÓN:** Lógica modificada para excluir las tomas ya registradas
  int getPendingNotificationsCount() {
    final now = TimeOfDay.now();
    final nowDateTime = DateTime.now();
    int count = 0;

    // Check if boxes are open (they should be after _preloadEssentialData)
    if (!Hive.isBoxOpen(medicamentosBoxName)) return getPendingCrisisCount();
    final bool isTomasBoxOpen = Hive.isBoxOpen(tomasMedicamentosBoxName);
    final tomaBox = isTomasBoxOpen
        ? Hive.box<TomaMedicamento>(tomasMedicamentosBoxName)
        : null;
    final medBox = Hive.box<Medicamento>(medicamentosBoxName);

    // 1. Pending Medications (upcoming and not yet registered)
    for (var med in medBox.values) {
      if (!med.activo || med.horarios.isEmpty) continue;

      for (var h in med.horarios) {
        final parts = h.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);

        // Check for today's schedule that is *not* in the past
        if (hour < now.hour || (hour == now.hour && minute < now.minute))
          continue;

        final fechaProgramada = DateTime(
          nowDateTime.year,
          nowDateTime.month,
          nowDateTime.day,
          hour,
          minute,
        );

        // Check if already registered (Tomada or No tomada)
        bool yaRegistrada = false;
        if (isTomasBoxOpen && tomaBox != null) {
          for (var toma in tomaBox.values) {
            if (toma.medicamentoKey == med.key &&
                toma.fechaProgramada.year == fechaProgramada.year &&
                toma.fechaProgramada.month == fechaProgramada.month &&
                toma.fechaProgramada.day == fechaProgramada.day &&
                toma.fechaProgramada.hour == fechaProgramada.hour &&
                toma.fechaProgramada.minute == fechaProgramada.minute &&
                (toma.estado == 'Tomada' || toma.estado == 'No tomada')) {
              yaRegistrada = true;
              break;
            }
          }
        }

        if (!yaRegistrada) {
          count++;
        }
      }
    }

    // 2. Pending Crises
    count += getPendingCrisisCount();
    return count;
  }

  Future<void> _showNotificationsModal() async {
    if (!Hive.isBoxOpen(medicamentosBoxName) ||
        !Hive.isBoxOpen(crisisBoxName)) {
      return;
    }
    final medBox = Hive.box<Medicamento>(medicamentosBoxName);
    final crisisBox = Hive.box<Crisis>(crisisBoxName);
    final List<Widget> notifications = [];
    final now = TimeOfDay.now();
    final nowDateTime = DateTime.now();

    // Ensure we can check toma states
    if (!Hive.isBoxOpen(tomasMedicamentosBoxName)) {
      await Hive.openBox<TomaMedicamento>(tomasMedicamentosBoxName);
    }
    final tomaBox = Hive.box<TomaMedicamento>(tomasMedicamentosBoxName);

    // 🔹 Medicamentos próximos y pendientes (no marcados aún)
    for (var med in medBox.values) {
      if (!med.activo || med.horarios.isEmpty) continue;

      for (var h in med.horarios) {
        final parts = h.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);

        // Solo mostrar si es hora futura o la hora actual
        if (hour < now.hour || (hour == now.hour && minute < now.minute))
          continue;

        final fechaProgramada = DateTime(
          nowDateTime.year,
          nowDateTime.month,
          nowDateTime.day,
          hour,
          minute,
        );

        // Verificar si ya está marcada como tomada o no tomada
        bool yaRegistrada = false;
        for (var toma in tomaBox.values) {
          if (toma.medicamentoKey == med.key &&
              toma.fechaProgramada.year == fechaProgramada.year &&
              toma.fechaProgramada.month == fechaProgramada.month &&
              toma.fechaProgramada.day == fechaProgramada.day &&
              toma.fechaProgramada.hour == fechaProgramada.hour &&
              toma.fechaProgramada.minute == fechaProgramada.minute &&
              (toma.estado == 'Tomada' || toma.estado == 'No tomada')) {
            yaRegistrada = true;
            break;
          }
        }

        // Si ya está marcada como tomada o no tomada, no mostrarla
        if (yaRegistrada) continue;
        // Agregar la notificación solo si no está marcada
        if (!yaRegistrada) {
          notifications.add(
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Encabezado con ícono e información del medicamento
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.medication_rounded,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tomar ${med.nombre}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text('Programado para las $h'),
                              Text(
                                'Dosis: ${med.dosis}${med.unidad}',
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // 🔽 Botones de acción (ahora debajo del texto)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          icon: const Icon(
                            Icons.check_circle_outline,
                            color: Colors.green,
                          ),
                          label: const Text(
                            'TOMADO',
                            style: TextStyle(color: Colors.green),
                          ),
                          onPressed: () async {
                            await markAsTaken(med, fechaProgramada);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${med.nombre} marcado como tomado',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              Navigator.pop(context); // Cerrar modal
                            }
                          },
                        ),
                        TextButton.icon(
                          icon: const Icon(
                            Icons.cancel_outlined,
                            color: Colors.red,
                          ),
                          label: const Text(
                            'NO TOMADO',
                            style: TextStyle(color: Colors.red),
                          ),
                          // **CORRECCIÓN:** Manejo de contexto para cerrar el modal y solución de teclado
                          onPressed: () async {
                            final rootContext = context;

                            // Controlador fuera del builder para no perder el texto
                            final controller = TextEditingController();

                            final reason = await showDialog<String>(
                              context: rootContext,
                              barrierDismissible: false,
                              builder: (BuildContext dialogContext) {
                                return StatefulBuilder(
                                  builder: (context, setState) {
                                    return AlertDialog(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      title: const Text(
                                        'Razón por la que no se tomó',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      content: TextField(
                                        controller: controller,
                                        autofocus: true,
                                        textInputAction: TextInputAction.done,
                                        decoration: const InputDecoration(
                                          hintText:
                                              'Ej: se me olvidó, no me sentía bien...',
                                          border: OutlineInputBorder(),
                                        ),
                                        onEditingComplete: () {
                                          FocusScope.of(context).unfocus();
                                        },
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () {
                                            FocusScope.of(
                                              dialogContext,
                                            ).unfocus();
                                            Navigator.of(dialogContext).pop();
                                          },
                                          child: const Text('Cancelar'),
                                        ),
                                        ElevatedButton.icon(
                                          icon: const Icon(
                                            Icons.save,
                                            color: Colors.white,
                                          ),
                                          label: const Text(
                                            'Guardar',
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF1E3A8A,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 20,
                                              vertical: 12,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                          ),
                                          onPressed: () {
                                            final text = controller.text.trim();
                                            if (text.isNotEmpty) {
                                              FocusScope.of(
                                                dialogContext,
                                              ).unfocus();
                                              Navigator.of(
                                                dialogContext,
                                              ).pop(text);
                                            }
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            );

                            if (reason == null || reason.trim().isEmpty) return;

                            await markAsNotTaken(
                              med,
                              fechaProgramada,
                              razon: reason,
                            );

                            try {
                              await clearNotificationFor(
                                med.key as int,
                                fechaProgramada,
                              );
                            } catch (_) {}

                            if (rootContext.mounted) {
                              ScaffoldMessenger.of(rootContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${med.nombre} marcado como no tomado',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }

                            if (rootContext.mounted &&
                                Navigator.canPop(rootContext)) {
                              Navigator.pop(rootContext);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      }
    }

    // 🔹 Crisis incompletas
    for (var crisis in crisisBox.values) {
      if (crisis.preictal == null ||
          crisis.ictal == null ||
          crisis.postictalSentimiento == null ||
          crisis.postictalTiempoRecuperacion == null ||
          crisis.estadoAnimoAntes == null ||
          crisis.estadoAnimoDespues == null) {
        notifications.add(
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.red,
              ),
              title: Text(
                'Crisis del ${crisis.fechaHora.toLocal().toString().substring(0, 16)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: const Text('Completa los detalles pendientes'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PantallaRegistrarCrisis(
                      crisisExistente: crisis,
                      detallesColapsados: false,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }
    }

    if (notifications.isEmpty) {
      notifications.add(
        const ListTile(
          leading: Icon(Icons.check_circle_outline, color: Colors.green),
          title: Text('Todo al día'),
          subtitle: Text('No hay notificaciones pendientes'),
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Notificaciones',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A),
                ),
              ),
            ),
            const Divider(),
            Expanded(child: ListView(children: notifications)),
          ],
        ),
      ),
    );
  }

  // ------------------ IndexedStack para mantener estado ------------------
  final List<Widget> _screens = [];

  void _crisisBoxListener() async {
    try {
      final pending = getPendingCrisisCount();
      if (pending > 0 && pending != _lastNotifiedPendingCrisisCount) {
        _lastNotifiedPendingCrisisCount = pending;
        Crisis? firstPendingCrisis;
        if (!Hive.isBoxOpen(crisisBoxName)) return;
        for (var crisis in Hive.box<Crisis>(crisisBoxName).values) {
          if (crisis.preictal == null ||
              crisis.ictal == null ||
              crisis.postictalSentimiento == null ||
              crisis.postictalTiempoRecuperacion == null ||
              crisis.estadoAnimoAntes == null ||
              crisis.estadoAnimoDespues == null) {
            firstPendingCrisis = crisis;
            break;
          }
        }

        await showLocalNotification(
          id: 1000,
          title: 'Crisis incompletas',
          body:
              'Tienes $pending crisis con datos pendientes. Pulsa para completar.',
          payload: firstPendingCrisis != null
              ? 'crisis:${firstPendingCrisis.key}'
              : null,
        );
      } else if (pending == 0) {
        _lastNotifiedPendingCrisisCount = 0;
      }
    } catch (e) {
      print('Error manejando cambios en crisisBox: $e');
    }
  }

  @override
  void dispose() {
    try {
      _crisisListenable?.removeListener(_crisisBoxListener);
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // NOTE: removed blocking loading screen to avoid runtime issues when
    // Hive boxes are not yet opened. Individual widgets and helpers already
    // check Hive.isBoxOpen(...) before accessing boxes.

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: CommonAppBar(
        title: 'Aura',
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_rounded,
                  color: Colors.white,
                  size: 32,
                ),
                onPressed: _showNotificationsModal,
              ),
              Positioned(
                right: 8,
                top: 8,
                // **ACTUALIZACIÓN:** Listener anidado para actualizar el contador en tiempo real
                child: ValueListenableBuilder(
                  // Listener 1: Escucha la caja de Tomas (cuando se marca un medicamento)
                  valueListenable: Hive.isBoxOpen(tomasMedicamentosBoxName)
                      ? Hive.box<TomaMedicamento>(
                          tomasMedicamentosBoxName,
                        ).listenable()
                      : ValueNotifier(null),
                  builder: (context, tomaBox, _) {
                    // Listener 2: Escucha la caja de Crisis (cuando se registra una crisis)
                    return ValueListenableBuilder(
                      valueListenable: Hive.isBoxOpen(crisisBoxName)
                          ? Hive.box<Crisis>(crisisBoxName).listenable()
                          : ValueNotifier(null),
                      builder: (context, crisisBox, __) {
                        final pending = getPendingNotificationsCount();

                        return pending > 0
                            ? Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  '$pending',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : const SizedBox.shrink();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: const Color(0xFF1E3A8A),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_rounded),
            label: 'Historial',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_rounded),
            label: 'Reportes',
          ),
        ],
      ),
    );
  }
}

// ------------------ Widgets secundarios ------------------
class _HomeContent extends StatefulWidget {
  @override
  State<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<_HomeContent> {
  bool crisisExpanded = false;
  bool medicacionExpanded = false;
  bool animoExpanded = false;

  void toggleExpand(String section) {
    setState(() {
      crisisExpanded = section == 'crisis' ? !crisisExpanded : false;
      medicacionExpanded = section == 'medicacion'
          ? !medicacionExpanded
          : false;
      animoExpanded = section == 'animo' ? !animoExpanded : false;
    });
  }

  Widget _moduleTile({
    required String title,
    required Color color,
    required IconData icon,
    required bool expanded,
    required VoidCallback onTap,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
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
          ClipRect(
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 300),
              heightFactor: expanded ? 1.0 : 0.0,
              alignment: Alignment.topCenter,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                color: Colors.white.withOpacity(0.1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children
                      .map(
                        (child) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: child,
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          _moduleTile(
            title: 'Crisis',
            color: const Color(0xFF3B82F6),
            icon: Icons.warning_amber_rounded,
            expanded: crisisExpanded,
            onTap: () => toggleExpand('crisis'),
            children: [
              _SubOption(
                label: 'Registrar crisis',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PantallaRegistrarCrisis(
                      detallesColapsados: false,
                    ),
                  ),
                ),
              ),
              _SubOption(
                label: 'Historial de crisis',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const HistorialCrisisScreen(),
                  ),
                ),
              ),
            ],
          ),
          _moduleTile(
            title: 'Medicación',
            color: const Color(0xFF059669),
            icon: Icons.medication_rounded,
            expanded: medicacionExpanded,
            onTap: () => toggleExpand('medicacion'),
            children: [
              _SubOption(
                label: 'Añadir medicamento',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AnadirMedicamentoScreen()),
                ),
              ),
              _SubOption(
                label: 'Modificar dosis o horario',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ListarMedicamentosScreen()),
                ),
              ),
              _SubOption(
                label: 'Historial farmacológico',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HistorialFarmacologicoScreen(),
                  ),
                ),
              ),
            ],
          ),
          _moduleTile(
            title: 'Mi Ánimo',
            color: const Color(0xFF16A34A),
            icon: Icons.emoji_emotions_rounded,
            expanded: animoExpanded,
            onTap: () => toggleExpand('animo'),
            children: [
              _SubOption(
                label: 'Registrar estado anímico',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RegistrarAnimoScreen(),
                  ),
                ),
              ),
              _SubOption(
                label: 'Historial estado anímico',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const HistorialAnimoScreen(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReportesPage()),
            ),
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 106, 118, 153),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: ListTile(
                leading: const Icon(
                  Icons.bar_chart_rounded,
                  color: Colors.white,
                  size: 30,
                ),
                title: const Text(
                  'Reportes',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
              padding: const EdgeInsets.symmetric(vertical: 40),
              minimumSize: const Size(double.infinity, 100),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const PantallaRegistrarCrisis(detallesColapsados: true),
              ),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Registrar Crisis',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Icon(Icons.flash_on_rounded, color: Colors.white, size: 28),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubOption extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SubOption({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
