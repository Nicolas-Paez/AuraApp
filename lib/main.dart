import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/Crisis.dart';
import 'home_screen.dart';
import 'package:aura3/models/Medicamento.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  Hive.registerAdapter(MedicamentoAdapter());
  Hive.registerAdapter(CrisisAdapter());

  await Hive.openBox<Crisis>('crisisBox');
  await Hive.openBox<Medicamento>('medicamentosBox');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aura',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(nombreUsuario: 'Nicolás'),
    );
  }
}
