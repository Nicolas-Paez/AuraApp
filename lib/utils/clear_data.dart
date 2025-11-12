import 'package:path_provider/path_provider.dart';
import 'dart:io';

Future<void> clearHiveData() async {
  try {
    final appDir = await getApplicationDocumentsDirectory();
    final hiveDir = Directory('${appDir.path}/hive');
    if (await hiveDir.exists()) {
      await hiveDir.delete(recursive: true);
    }
    print('🧹 Datos de Hive limpiados correctamente');
  } catch (e) {
    print('❌ Error limpiando datos de Hive: $e');
  }
}
