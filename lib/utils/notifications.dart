import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/Medicamento.dart';
import '../models/TomaMedicamento.dart';
import '../utils/alarm_overlay.dart';
import '../utils/overlay_route.dart';
import 'navigation.dart';
import 'hive_boxes.dart';

// Helper: produce a stable notification id for a medication at a given hour:minute
int stableNotificationId(int medKey, int hour, int minute) {
  // medKey * 10000 keeps space for hour*100+minute
  return medKey * 10000 + hour * 100 + minute;
}

/// Cancela y descarta las notificaciones relacionadas a una toma (estable y puntal)
Future<void> clearNotificationFor(int medKey, DateTime fechaProgramada) async {
  final stableId = stableNotificationId(
    medKey,
    fechaProgramada.hour,
    fechaProgramada.minute,
  );
  final millisId = fechaProgramada.millisecondsSinceEpoch ~/ 1000;

  try {
    await AwesomeNotifications().cancel(stableId);
  } catch (_) {}
  try {
    await AwesomeNotifications().cancel(millisId);
  } catch (_) {}
  try {
    await AwesomeNotifications().dismiss(stableId);
  } catch (_) {}
  try {
    await AwesomeNotifications().dismiss(millisId);
  } catch (_) {}
}

/// Inicialización de notificaciones
Future<void> initNotifications() async {
  await AwesomeNotifications().initialize(null, [
    NotificationChannel(
      channelKey: 'med_channel',
      channelName: 'Medicamentos',
      channelDescription: 'Recordatorios de medicación',
      importance: NotificationImportance.Max,
      defaultRingtoneType: DefaultRingtoneType.Alarm,
      playSound: true,
      enableVibration: true,
      locked: true,
      criticalAlerts: true,
    ),
  ], debug: true);

  // Configurar listeners
  AwesomeNotifications().setListeners(
    onActionReceivedMethod: onActionReceived,
    onNotificationDisplayedMethod: onNotificationDisplayed,
    onNotificationCreatedMethod: onNotificationCreated,
  );
}

/// Cuando se crea una notificación
@pragma('vm:entry-point')
Future<void> onNotificationCreated(ReceivedNotification notification) async {
  // Ensure Hive adapters are registered in this isolate (background handlers
  // may run in a different isolate where `main()` wasn't executed).
  try {
    if (!Hive.isAdapterRegistered(2))
      Hive.registerAdapter(TomaMedicamentoAdapter());
  } catch (e) {
    debugPrint('onNotificationCreated: error registering Hive adapters: $e');
  }
  // No action needed on creation
  return;
}

/// Cuando se muestra una notificación -> reproducir sonido/vibración (sin overlay)
@pragma('vm:entry-point')
Future<void> onNotificationDisplayed(ReceivedNotification notification) async {
  // Make sure the adapter is available if this runs in a different isolate.
  try {
    if (!Hive.isAdapterRegistered(2))
      Hive.registerAdapter(TomaMedicamentoAdapter());
  } catch (e) {
    debugPrint('onNotificationDisplayed: error registering Hive adapters: $e');
  }
  final payload = notification.payload ?? {};
  // Only handle medication reminders which carry our payload keys.
  if (notification.channelKey != 'med_channel' ||
      !(payload.containsKey('medicamentoKey') &&
          payload.containsKey('fechaProgramada'))) {
    debugPrint(
      'onNotificationDisplayed: ignored non-medication notification (channel=${notification.channelKey} title=${notification.title})',
    );
    return;
  }

  // Reproducir sonido y vibración
  try {
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.vibrate();
  } catch (e) {
    debugPrint('Error reproduciendo alerta: $e');
  }

  final medKey = int.tryParse(payload['medicamentoKey'] ?? '');
  final fechaStr = payload['fechaProgramada'];
  if (medKey == null || fechaStr == null) {
    debugPrint('onNotificationDisplayed: payload malformed: $payload');
    return;
  }

  final fechaProgramada = DateTime.parse(fechaStr);

  // Buscar/crear la toma correspondiente
  if (!Hive.isBoxOpen(tomasMedicamentosBoxName)) {
    await Hive.openBox<TomaMedicamento>(tomasMedicamentosBoxName);
  }
  final tomaBox = Hive.box<TomaMedicamento>(tomasMedicamentosBoxName);
  TomaMedicamento? toma;

  try {
    toma = tomaBox.values.firstWhere(
      (t) =>
          t.medicamentoKey == medKey &&
          t.fechaProgramada.isAtSameMomentAs(fechaProgramada),
    );
  } catch (_) {
    // Si no existe, crear la toma
    final nueva = TomaMedicamento(
      medicamentoKey: medKey,
      medicamentoNombre: 'Medicamento', // Se actualizará al cargar
      fechaProgramada: fechaProgramada,
      estado: 'Pendiente',
    );
    final newKey = await tomaBox.add(nueva);
    toma = tomaBox.get(newKey);
  }

  if (toma == null) {
    debugPrint('⚠️ No se pudo crear/encontrar la toma para la notificación');
    return;
  }

  // Intentar mostrar overlay inmediatamente.
  // Preferimos usar navigatorKey.currentState (más robusto) pero también
  // registramos logs para detectar cuándo la app está en background/terminada
  // y no hay contexto disponible.
  final navState = navigatorKey.currentState;
  if (navState != null) {
    // Esperar un momento para que la UI esté lista
    await Future.delayed(const Duration(milliseconds: 500));
    try {
      await navState.push(FullScreenRoute(child: AlarmOverlayPage(toma: toma)));
      debugPrint('onNotificationDisplayed: overlay pushed via navigatorKey');
    } catch (e) {
      debugPrint(
        'onNotificationDisplayed: error pushing overlay via navigatorKey: $e',
      );
    }
  } else {
    debugPrint(
      'onNotificationDisplayed: no NavigatorState available (app likely backgrounded or terminated). Overlay not shown now.',
    );
  }

  // Reproducir sonido y vibración
  try {
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.vibrate();
  } catch (e) {
    debugPrint('Error reproduciendo alerta: $e');
  }
}

/// Cuando el usuario interactúa con la notificación
@pragma('vm:entry-point')
Future<void> onActionReceived(ReceivedAction action) async {
  // Ensure adapters are registered in notification action isolate.
  try {
    if (!Hive.isAdapterRegistered(2))
      Hive.registerAdapter(TomaMedicamentoAdapter());
  } catch (e) {
    debugPrint('onActionReceived: error registering Hive adapters: $e');
  }
  final payload = action.payload ?? {};

  // Extraer datos del medicamento
  final medKey = int.tryParse(payload['medicamentoKey'] ?? '');
  final fechaStr = payload['fechaProgramada'];
  if (medKey == null || fechaStr == null) return;

  final fechaProgramada = DateTime.parse(fechaStr);

  debugPrint(
    'onActionReceived: medKey=$medKey fechaProgramada=$fechaProgramada action=${action.buttonKeyPressed} input=${action.buttonKeyInput}',
  );

  // Buscar la toma correspondiente
  if (!Hive.isBoxOpen(tomasMedicamentosBoxName)) {
    await Hive.openBox<TomaMedicamento>(tomasMedicamentosBoxName);
  }
  final tomaBox = Hive.box<TomaMedicamento>(tomasMedicamentosBoxName);
  TomaMedicamento? toma;
  try {
    toma = tomaBox.values.firstWhere(
      (t) =>
          t.medicamentoKey == medKey &&
          t.fechaProgramada.isAtSameMomentAs(fechaProgramada),
    );
  } catch (_) {
    toma = null;
  }

  // Si no existe, crear y guardar la toma en la caja para poder persistir cambios
  if (toma == null) {
    final nueva = TomaMedicamento(
      medicamentoKey: medKey,
      medicamentoNombre: 'Medicamento',
      fechaProgramada: fechaProgramada,
      estado: 'Pendiente',
    );
    final newKey = await tomaBox.add(nueva);
    debugPrint(
      'onActionReceived: creada nueva TomaMedicamento key=$newKey medKey=$medKey fecha=$fechaProgramada',
    );
    // Get the properly boxed object
    toma = tomaBox.get(newKey);
    if (toma == null) {
      debugPrint('Error: Could not retrieve newly created TomaMedicamento');
      return;
    }
  }

  // Cancelar y descartar notificaciones relacionadas para evitar múltiples marcas
  final tomaLocal = toma;
  try {
    await clearNotificationFor(
      tomaLocal.medicamentoKey,
      tomaLocal.fechaProgramada,
    );
  } catch (e) {
    debugPrint('Error limpiando notificaciones en onActionReceived: $e');
    // Fallback: try manual cancellation if helper failed
    final stableId = stableNotificationId(
      tomaLocal.medicamentoKey,
      tomaLocal.fechaProgramada.hour,
      tomaLocal.fechaProgramada.minute,
    );
    final millisId = tomaLocal.fechaProgramada.millisecondsSinceEpoch ~/ 1000;
    try {
      await AwesomeNotifications().cancel(stableId);
      await AwesomeNotifications().cancel(millisId);
      await AwesomeNotifications().dismiss(stableId);
      await AwesomeNotifications().dismiss(millisId);
    } catch (_) {}
  }

  // Manejar la acción según el botón presionado
  switch (action.buttonKeyPressed) {
    case 'TAKEN':
      await _handleTakenFromNotification(tomaLocal);
      debugPrint(
        'Notification action: TAKEN for toma key=${tomaLocal.key} med=${tomaLocal.medicamentoKey}',
      );
      // Mostrar confirmación transitoria
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: 9999,
          channelKey: 'med_channel',
          title: '✅ ¡Medicamento tomado!',
          body: 'Has registrado ${tomaLocal.medicamentoNombre} como tomado.',
          autoDismissible: true,
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
      break;

    case 'NOT_TAKEN':
      if (action.buttonKeyInput.isNotEmpty) {
        tomaLocal.estado = 'No tomada';
        tomaLocal.razon = action.buttonKeyInput;
        tomaLocal.fechaReal = DateTime.now();
        try {
          tomaLocal.retraso = tomaLocal.fechaReal!
              .difference(tomaLocal.fechaProgramada)
              .inMinutes;
        } catch (_) {}
        await tomaLocal.save();
        debugPrint(
          'Notification action: NOT_TAKEN saved for toma key=${tomaLocal.key} med=${tomaLocal.medicamentoKey} reason=${tomaLocal.razon}',
        );

        // Mostrar confirmación transitoria
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: 9998,
            channelKey: 'med_channel',
            title: '❌ Medicamento no tomado',
            body:
                'Has registrado ${tomaLocal.medicamentoNombre} como no tomado.\nRazón: ${tomaLocal.razon}',
            autoDismissible: true,
            backgroundColor: const Color(0xFFf44336),
          ),
        );
      }
      break;

    default:
      // Si solo tocó la notificación, no hacer nada
      debugPrint(
        'onActionReceived(default): notification tapped without action',
      );
  }
}

/// Programar recordatorio de medicamento
Future<void> scheduleMedicationReminder(
  Medicamento med,
  DateTime fechaProgramada,
) async {
  final id = stableNotificationId(
    med.key as int,
    fechaProgramada.hour,
    fechaProgramada.minute,
  );

  await AwesomeNotifications().createNotification(
    content: NotificationContent(
      id: id,
      channelKey: 'med_channel',
      title: '💊 Recordatorio de medicamento',
      body: '${med.nombre}\nDosis: ${med.dosis} ${med.unidad}',
      category: NotificationCategory.Alarm,
      fullScreenIntent: true,
      wakeUpScreen: true,
      criticalAlert: true,
      locked: true,
      autoDismissible: false,
      displayOnForeground: true,
      displayOnBackground: true,
      payload: {
        'medicamentoKey': med.key.toString(),
        'fechaProgramada': fechaProgramada.toIso8601String(),
      },
    ),
    schedule: NotificationCalendar(
      hour: fechaProgramada.hour,
      minute: fechaProgramada.minute,
      second: 0,
      millisecond: 0,
      repeats: true,
      preciseAlarm: true,
      allowWhileIdle: true,
    ),
    actionButtons: [
      NotificationActionButton(
        key: 'TAKEN',
        label: 'TOMADO',
        color: Colors.green,
        actionType: ActionType.Default,
      ),
      NotificationActionButton(
        key: 'NOT_TAKEN',
        label: 'NO TOMADO',
        color: Colors.red,
        actionType: ActionType.Default,
        requireInputText: true,
      ),
    ],
  );
}

/// Programar todas las notificaciones de medicamentos
Future<void> scheduleAllMedicationNotifications() async {
  if (!Hive.isBoxOpen(medicamentosBoxName) ||
      !Hive.isBoxOpen(tomasMedicamentosBoxName)) {
    debugPrint(
      '❌ Las cajas necesarias no están abiertas, abortando programación.',
    );
    return;
  }

  final medBox = Hive.box<Medicamento>(medicamentosBoxName);
  final tomaBox = Hive.box<TomaMedicamento>(tomasMedicamentosBoxName);

  // Cancelar todas las notificaciones existentes de forma no bloqueante.
  // La API de AwesomeNotifications puede ejecutar trabajo en el hilo UI,
  // así que la estrategia aquí es procesar las tareas en pequeños lotes
  // y ceder la ejecución ocasionalmente para evitar jank en el frame.
  await AwesomeNotifications().cancelAllSchedules();

  final meds = medBox.values.toList(growable: false);
  const int batchSize = 5; // cuantos medicamentos programar antes de ceder
  const Duration pauseBetweenBatches = Duration(milliseconds: 120);

  for (var i = 0; i < meds.length; i++) {
    final med = meds[i];
    if (med.activo == false) continue;

    for (var h in med.horarios) {
      final parts = h.split(':');
      if (parts.length != 2) continue;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) continue;

      final now = DateTime.now();
      var fechaProgramada = DateTime(
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      if (fechaProgramada.isBefore(now)) {
        fechaProgramada = fechaProgramada.add(const Duration(days: 1));
      }

      final existingToma = tomaBox.values.where(
        (t) =>
            t.medicamentoKey == med.key &&
            t.fechaProgramada.year == fechaProgramada.year &&
            t.fechaProgramada.month == fechaProgramada.month &&
            t.fechaProgramada.day == fechaProgramada.day &&
            t.fechaProgramada.hour == fechaProgramada.hour &&
            t.fechaProgramada.minute == fechaProgramada.minute,
      );

      if (existingToma.isEmpty) {
        // Esperamos la llamada, pero programamos en lotes para no bloquear
        // el hilo de UI por mucho tiempo.
        await scheduleMedicationReminder(med, fechaProgramada);
      }
    }

    // Cada batchSize medicamentos, cedemos con una pequeña pausa para
    // permitir que el renderizador procese frames y eventos.
    if ((i + 1) % batchSize == 0) {
      await Future.delayed(pauseBetweenBatches);
    }
  }
}

/// Programar todas las notificaciones inteligentes.
///
/// Este método es idempotente por día: guarda en la caja `appMetaBox`
/// la última fecha en la que se realizaron las programaciones y evita
/// repetir el trabajo en cada arranque frío salvo que se solicite
/// `force=true` (por ejemplo después de crear/editar medicamentos).
Future<void> scheduleAllSmartNotifications({bool force = false}) async {
  // Asegurarnos de que exista la caja de metas de aplicación
  if (!Hive.isBoxOpen(appMetaBoxName)) {
    await Hive.openBox(appMetaBoxName);
  }

  final meta = Hive.box(appMetaBoxName);
  final todayKey = DateTime.now().toIso8601String().split('T').first;
  final last = meta.get('lastScheduledDate') as String?;

  if (!force && last == todayKey) {
    debugPrint('⏭️ Schedule skipped: already scheduled for today ($todayKey)');
    return;
  }

  await scheduleAllMedicationNotifications();
  await meta.put('lastScheduledDate', todayKey);
  debugPrint('✅ Notificaciones inteligentes programadas (for date: $todayKey)');
}

/// Mostrar overlay de medicamento
Future<void> showMedicationDialog(TomaMedicamento toma) async {
  final navState = navigatorKey.currentState;
  if (navState == null) {
    debugPrint(
      'showMedicationDialog: no NavigatorState available (app backgrounded/terminated).',
    );
    return;
  }

  // Asegurar que estemos sobre la pantalla de bloqueo
  if (Platform.isAndroid) {
    try {
      final methodChannel = MethodChannel('com.example.aura3/screen_state');
      await methodChannel.invokeMethod('showOverLockscreen');
    } catch (e) {
      debugPrint(
        'Error al configurar visualización sobre pantalla de bloqueo: $e',
      );
    }
  }

  // Reproducir sonido de alarma
  try {
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.vibrate();
  } catch (e) {
    debugPrint('Error reproduciendo alerta: $e');
  }

  // Mostrar overlay mediante navigatorKey (más robusto que usar contexts sueltos)
  try {
    await navState.push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        pageBuilder: (_, __, ___) =>
            PopScope(canPop: false, child: AlarmOverlayPage(toma: toma)),
      ),
    );
  } catch (e) {
    debugPrint('showMedicationDialog: error al mostrar overlay: $e');
  }
}

Future<void> _handleTakenFromNotification(TomaMedicamento toma) async {
  toma.estado = 'Tomada';
  toma.fechaReal = DateTime.now();
  await toma.save();

  // Cancelar tanto la notificación diaria como cualquier otra (snooze)
  final stableId = stableNotificationId(
    toma.medicamentoKey,
    toma.fechaProgramada.hour,
    toma.fechaProgramada.minute,
  );
  final millisId = toma.fechaProgramada.millisecondsSinceEpoch ~/ 1000;

  // Asegurar que se cancelen/limpien todas las notificaciones
  try {
    await AwesomeNotifications().cancel(stableId);
    await AwesomeNotifications().cancel(millisId);
    await AwesomeNotifications().dismiss(stableId);
    await AwesomeNotifications().dismiss(millisId);
  } catch (e) {
    debugPrint('Error al limpiar notificaciones: $e');
  }
}

/// Marca como tomada desde código (overlay o UI manual)
Future<void> markAsTaken(Medicamento med, DateTime fechaProgramada) async {
  if (!Hive.isBoxOpen(tomasMedicamentosBoxName)) {
    await Hive.openBox<TomaMedicamento>(tomasMedicamentosBoxName);
  }
  final tomaBox = Hive.box<TomaMedicamento>(tomasMedicamentosBoxName);

  TomaMedicamento? toma;
  try {
    toma = tomaBox.values.firstWhere(
      (t) =>
          t.medicamentoKey == med.key &&
          t.fechaProgramada.isAtSameMomentAs(fechaProgramada),
    );
  } catch (_) {
    final nueva = TomaMedicamento(
      medicamentoKey: med.key as int,
      medicamentoNombre: med.nombre,
      fechaProgramada: fechaProgramada,
      estado: 'Pendiente',
    );
    final newKey = await tomaBox.add(nueva);
    toma = tomaBox.get(newKey);
  }

  if (toma == null) return;

  toma.estado = 'Tomada';
  toma.fechaReal = DateTime.now();
  try {
    toma.retraso = toma.fechaReal!.difference(toma.fechaProgramada).inMinutes;
  } catch (_) {}
  await toma.save();

  // Ensure related notifications are cleared so the reminder disappears
  try {
    await clearNotificationFor(toma.medicamentoKey, toma.fechaProgramada);
  } catch (e) {
    debugPrint('Error limpiando notificaciones tras marcar tomada: $e');
    // Fallback to manual cancellation
    final stableId = stableNotificationId(
      toma.medicamentoKey,
      toma.fechaProgramada.hour,
      toma.fechaProgramada.minute,
    );
    final millisId = toma.fechaProgramada.millisecondsSinceEpoch ~/ 1000;
    try {
      await AwesomeNotifications().cancel(stableId);
      await AwesomeNotifications().cancel(millisId);
      await AwesomeNotifications().dismiss(stableId);
      await AwesomeNotifications().dismiss(millisId);
    } catch (_) {}
  }

  // Show short confirmation
  try {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        channelKey: 'med_channel',
        title: '✅ Medicamento tomado',
        body: '${toma.medicamentoNombre} registrado como tomado',
        autoDismissible: true,
      ),
    );
  } catch (_) {}
}

/// Marca como no tomada desde código (overlay o UI manual)
Future<void> markAsNotTaken(
  Medicamento med,
  DateTime fechaProgramada, {
  String? razon,
}) async {
  if (!Hive.isBoxOpen(tomasMedicamentosBoxName)) {
    await Hive.openBox<TomaMedicamento>(tomasMedicamentosBoxName);
  }
  final tomaBox = Hive.box<TomaMedicamento>(tomasMedicamentosBoxName);

  TomaMedicamento? toma;
  try {
    toma = tomaBox.values.firstWhere(
      (t) =>
          t.medicamentoKey == med.key &&
          t.fechaProgramada.isAtSameMomentAs(fechaProgramada),
    );
  } catch (_) {
    final nueva = TomaMedicamento(
      medicamentoKey: med.key as int,
      medicamentoNombre: med.nombre,
      fechaProgramada: fechaProgramada,
      estado: 'Pendiente',
    );
    final newKey = await tomaBox.add(nueva);
    toma = tomaBox.get(newKey);
  }

  if (toma == null) return;

  toma.estado = 'No tomada';
  toma.razon = razon;
  toma.fechaReal = DateTime.now();
  await toma.save();

  // Ensure related notifications are cleared so the reminder disappears
  try {
    await clearNotificationFor(toma.medicamentoKey, toma.fechaProgramada);
  } catch (e) {
    debugPrint('Error limpiando notificaciones tras marcar no tomada: $e');
    // Fallback to manual cancellation
    final stableId = stableNotificationId(
      toma.medicamentoKey,
      toma.fechaProgramada.hour,
      toma.fechaProgramada.minute,
    );
    final millisId = toma.fechaProgramada.millisecondsSinceEpoch ~/ 1000;
    try {
      await AwesomeNotifications().cancel(stableId);
      await AwesomeNotifications().cancel(millisId);
      await AwesomeNotifications().dismiss(stableId);
      await AwesomeNotifications().dismiss(millisId);
    } catch (_) {}
  }

  try {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        channelKey: 'med_channel',
        title: '❌ Medicamento no tomado',
        body: '${toma.medicamentoNombre} marcado como no tomado',
        autoDismissible: true,
      ),
    );
  } catch (_) {}
}

/// Posponer notificación +10 minutos
Future<void> snoozeNotification(
  Medicamento med,
  DateTime fechaProgramada,
) async {
  if (!Hive.isBoxOpen(tomasMedicamentosBoxName)) {
    await Hive.openBox<TomaMedicamento>(tomasMedicamentosBoxName);
  }
  final tomaBox = Hive.box<TomaMedicamento>(tomasMedicamentosBoxName);

  TomaMedicamento? toma;
  try {
    toma = tomaBox.values.firstWhere(
      (t) =>
          t.medicamentoKey == med.key &&
          t.fechaProgramada.isAtSameMomentAs(fechaProgramada),
    );
  } catch (_) {
    final nueva = TomaMedicamento(
      medicamentoKey: med.key as int,
      medicamentoNombre: med.nombre,
      fechaProgramada: fechaProgramada,
      estado: 'Pendiente',
    );
    final newKey = await tomaBox.add(nueva);
    toma = tomaBox.get(newKey);
  }

  if (toma == null) return;

  final nuevaFecha = DateTime.now().add(const Duration(minutes: 10));
  toma.estado = 'Pospuesta';
  toma.fechaProgramada = nuevaFecha;
  await toma.save();

  // Schedule new one-off notification
  final newId = nuevaFecha.millisecondsSinceEpoch ~/ 1000;
  try {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: newId,
        channelKey: 'med_channel',
        title: '⏰ Recordatorio pospuesto',
        body: '${toma.medicamentoNombre} (pospuesto 10 min)',
        category: NotificationCategory.Alarm,
        wakeUpScreen: true,
        fullScreenIntent: true,
        locked: true,
        autoDismissible: false,
        payload: {
          'medicamentoKey': toma.medicamentoKey.toString(),
          'fechaProgramada': nuevaFecha.toIso8601String(),
        },
      ),
      schedule: NotificationCalendar.fromDate(date: nuevaFecha),
      actionButtons: [
        NotificationActionButton(key: 'TAKEN', label: 'Tomado'),
        NotificationActionButton(
          key: 'NOT_TAKEN',
          label: 'No tomado',
          requireInputText: true,
        ),
      ],
    );
  } catch (e) {
    debugPrint('Error programando snooze: $e');
  }
}

/// Marca automáticamente como no tomada si han pasado más de 3 horas
Future<void> autoMarkExpiredTomas() async {
  if (!Hive.isBoxOpen(tomasMedicamentosBoxName)) {
    await Hive.openBox<TomaMedicamento>(tomasMedicamentosBoxName);
  }
  final tomaBox = Hive.box<TomaMedicamento>(tomasMedicamentosBoxName);
  final now = DateTime.now();

  for (var t in tomaBox.values) {
    if (t.estado == 'Pendiente' || t.estado == 'Pospuesta') {
      final diff = now.difference(t.fechaProgramada).inMinutes;
      if (diff >= 180) {
        t.estado = 'No tomada';
        t.razon = 'Vencimiento automático';
        t.fechaReal = t.fechaProgramada.add(const Duration(hours: 3));
        await t.save();

        // Clean notifications
        final stableId = stableNotificationId(
          t.medicamentoKey,
          t.fechaProgramada.hour,
          t.fechaProgramada.minute,
        );
        final millisId = t.fechaProgramada.millisecondsSinceEpoch ~/ 1000;
        try {
          await AwesomeNotifications().cancel(stableId);
          await AwesomeNotifications().cancel(millisId);
          await AwesomeNotifications().dismiss(stableId);
          await AwesomeNotifications().dismiss(millisId);
        } catch (_) {}
      }
    }
  }
}

/// Backwards-compatible wrapper used by older call-sites
Future<void> initLocalNotifications() async => await initNotifications();

/// Show a simple local notification (used by HomeScreen)
Future<void> showLocalNotification({
  required int id,
  required String title,
  required String body,
  String? payload,
}) async {
  try {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id,
        channelKey: 'med_channel',
        title: title,
        body: body,
        payload: payload != null ? {'payload': payload} : null,
      ),
    );
  } catch (e) {
    debugPrint('Error mostrando notificación local: $e');
  }
}

/// Show medication dialog by medication key and scheduled time.
/// If a matching TomaMedicamento exists, reuse it; otherwise create a temporary one.
Future<void> showMedicationDialogForKeyAndTime(
  int medKey,
  DateTime fechaProgramada,
) async {
  try {
    if (!Hive.isBoxOpen(tomasMedicamentosBoxName)) {
      await Hive.openBox<TomaMedicamento>(tomasMedicamentosBoxName);
    }
    final box = Hive.box<TomaMedicamento>(tomasMedicamentosBoxName);
    TomaMedicamento? toma;
    try {
      toma = box.values.firstWhere(
        (t) =>
            t.medicamentoKey == medKey &&
            t.fechaProgramada.isAtSameMomentAs(fechaProgramada),
      );
    } catch (_) {
      // Not found: create and store in the box so .save() works later
      final nueva = TomaMedicamento(
        medicamentoKey: medKey,
        medicamentoNombre: 'Medicamento',
        fechaProgramada: fechaProgramada,
        estado: 'Pendiente',
      );
      final newKey = await box.add(nueva);
      toma = box.get(newKey);
      debugPrint(
        'showMedicationDialogForKeyAndTime: created boxed TomaMedicamento key=$newKey',
      );
    }

    if (toma == null) {
      debugPrint(
        'showMedicationDialogForKeyAndTime: failed to obtain or create a boxed toma for medKey=$medKey',
      );
      return;
    }

    await showMedicationDialog(toma);
  } catch (e) {
    debugPrint('Error mostrando diálogo de medicamento: $e');
  }
}
