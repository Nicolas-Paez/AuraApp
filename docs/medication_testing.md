Pruebas manuales — Flujos de medicación

Objetivo: verificar que al añadir un medicamento se creen las tomas, se programen notificaciones diarias y que las acciones (Tomado/No tomado/Posponer) queden registradas para el cálculo de adherencia.

Requisitos previos
- App compilada y corriendo.
- Conexión de depuración para ver logs (flutter run).

Pasos de prueba
1. Añadir medicamento
   - Ir a Añadir Medicamento
   - Rellenar nombre, dosis, unidad y al menos un horario (ej: 2 minutos en el futuro o una hora próxima)
   - Guardar
   - Ver logs: "Medicamento añadido correctamente"

2. Verificar creación de tomas
   - Abrir `tomasMedicamentosBox` (desde la app o con logs). Debe existir una entrada TomaMedicamento para la próxima ocurrencia de cada horario con estado 'Pendiente'.

3. Verificar programación de notificaciones
   - Confirmar en logs que se llamó a `scheduleMedicationReminder`.
   - Esperar a la hora programada y verificar que: la notificación aparece y el overlay (AlarmOverlay) se muestra.

4. Interacción con la notificación
   - Pulsar 'Tomado' en la notificación: la TomaMedicamento correspondiente debe cambiar a estado 'Tomada' y `fechaReal` debe llenarse.
   - Pulsar 'No tomado' (y escribir razón): la TomaMedicamento debe actualizar `estado='No tomada'`, `razon` y `fechaReal`.
   - Pulsar 'Posponer': debe crearse una nueva TomaMedicamento con `fechaProgramada = ahora + 10 minutos` y programarse la notificación.

5. Comprobar cálculo de adherencia
   - Abrir Historial Farmacológico y Detalle del medicamento.
   - Verificar % de adherencia (historial: último 30 días). Debe reflejar las tomas marcadas como 'Tomada' / totales en el período.

Notas adicionales
- Si las notificaciones no llegan, comprobar permisos de notificación del SO.
- Si las tomas aparecen duplicadas, revisar la lógica que evita duplicados por fecha/hora exacta.

Checklist de verificación
- [ ] Creación de TomaMedicamento al añadir medicamento
- [ ] Notificación programada a la hora correcta
- [ ] Acciones en notificación actualizan TomaMedicamento
- [ ] Calculo de adherencia acorde a tomas registradas

Logs útiles
- Buscar en la consola mensajes con:
  - "Medicamento añadido correctamente"
  - "Error programando alarmas/tomas iniciales"
  - Mensajes de _handleTakenFromNotification / _handleSnoozeFromNotification en `notifications.dart`
