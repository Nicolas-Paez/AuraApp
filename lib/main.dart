import 'package:aura3/crisis/HistorialCrisis.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'models/Crisis.dart';
import 'models/Medicamento.dart';
import 'models/TomaMedicamento.dart';
import 'models/HistorialMedicamento.dart';
import 'models/CambioDosis.dart';
import 'home_screen.dart';

// Navigator key (puedes dejarla, no hace daño)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Hive
  await Hive.initFlutter();
  Hive.registerAdapter(MedicamentoAdapter());
  Hive.registerAdapter(CrisisAdapter());
  // Register adapter for TomaMedicamento so Hive can serialize/deserialize
  // instances written by notification handlers and other code paths.
  Hive.registerAdapter(TomaMedicamentoAdapter());
  // Registramos adaptadores para el historial farmacológico y cambios de dosis
  Hive.registerAdapter(HistorialMedicamentoAdapter());
  Hive.registerAdapter(CambioDosisAdapter());

  // Open primary boxes but don't block indefinitely on web/edge cases.
  // If a box fails to open within the timeout, log and continue so the UI
  // can still render and handle missing boxes gracefully.
  const boxOpenTimeout = Duration(seconds: 6);
  try {
    await Hive.openBox<Crisis>('crisisBox').timeout(boxOpenTimeout);
  } catch (e) {
    // Continue even if opening the box timed out or failed.
    debugPrint('⚠️ Timeout/failed opening crisisBox: $e');
  }

  try {
    await Hive.openBox<Medicamento>('medicamentosBox').timeout(boxOpenTimeout);
  } catch (e) {
    debugPrint('⚠️ Timeout/failed opening medicamentosBox: $e');
  }

  // Inicializar formatos de fecha para español
  await initializeDateFormatting('es', null);

  // NOTIFICACIONES comentadas por ahora
  // tz.initializeTimeZones();
  // await flutterLocalNotificationsPlugin.initialize(...);
  // await scheduleDailyPendingCrisisNotification();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aura',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(nombreUsuario: 'Nicolás'),
    );
  }
}
