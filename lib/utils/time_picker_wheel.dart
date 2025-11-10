import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

/// Muestra un selector de tiempo con estilo de rueda vertical.
/// Permite seleccionar hora (1-12), minutos (00-59) y AM/PM.
Future<TimeOfDay?> showWheelTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
}) async {
  TimeOfDay? selectedTime = await showModalBottomSheet<TimeOfDay>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (BuildContext context) {
      return TimePickerWheel(initialTime: initialTime);
    },
  );

  return selectedTime;
}

class TimePickerWheel extends StatefulWidget {
  final TimeOfDay initialTime;

  const TimePickerWheel({super.key, required this.initialTime});

  @override
  State<TimePickerWheel> createState() => _TimePickerWheelState();
}

class _TimePickerWheelState extends State<TimePickerWheel> {
  late int selectedHour;
  late int selectedMinute;
  late bool isAM;

  late FixedExtentScrollController hourController;
  late FixedExtentScrollController minuteController;
  late FixedExtentScrollController ampmController;

  @override
  void initState() {
    super.initState();

    // Convertir hora de 24h a 12h
    int hour24 = widget.initialTime.hour;
    selectedHour = hour24 > 12 ? hour24 - 12 : (hour24 == 0 ? 12 : hour24);
    selectedMinute = widget.initialTime.minute;
    isAM = hour24 < 12;

    // Inicializar controladores con posición inicial
    hourController = FixedExtentScrollController(initialItem: selectedHour - 1);
    minuteController = FixedExtentScrollController(initialItem: selectedMinute);
    ampmController = FixedExtentScrollController(initialItem: isAM ? 0 : 1);
  }

  @override
  void dispose() {
    hourController.dispose();
    minuteController.dispose();
    ampmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Barra superior con botones
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: Color(0xFF1E3A8A)),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Convertir de 12h a 24h
                    int hour24 = selectedHour;
                    if (!isAM) {
                      if (selectedHour != 12) hour24 += 12;
                    } else if (selectedHour == 12) {
                      hour24 = 0;
                    }

                    Navigator.pop(
                      context,
                      TimeOfDay(hour: hour24, minute: selectedMinute),
                    );
                  },
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      color: Color(0xFF1E3A8A),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(),

          // Ruedas de selección
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Selector de hora (1-12)
                Expanded(
                  child: CupertinoPicker(
                    scrollController: hourController,
                    magnification: 1.2,
                    squeeze: 1.0,
                    useMagnifier: true,
                    itemExtent: 40,
                    onSelectedItemChanged: (index) {
                      setState(() => selectedHour = index + 1);
                    },
                    children: List<Widget>.generate(12, (index) {
                      return Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 20,
                            color: selectedHour == index + 1
                                ? const Color(0xFF1E3A8A)
                                : Colors.black87,
                            fontWeight: selectedHour == index + 1
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                // Selector de minutos (00-59)
                Expanded(
                  child: CupertinoPicker(
                    scrollController: minuteController,
                    magnification: 1.2,
                    squeeze: 1.0,
                    useMagnifier: true,
                    itemExtent: 40,
                    onSelectedItemChanged: (index) {
                      setState(() => selectedMinute = index);
                    },
                    children: List<Widget>.generate(60, (index) {
                      return Center(
                        child: Text(
                          index.toString().padLeft(2, '0'),
                          style: TextStyle(
                            fontSize: 20,
                            color: selectedMinute == index
                                ? const Color(0xFF1E3A8A)
                                : Colors.black87,
                            fontWeight: selectedMinute == index
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                // Selector AM/PM
                Expanded(
                  child: CupertinoPicker(
                    scrollController: ampmController,
                    magnification: 1.2,
                    squeeze: 1.0,
                    useMagnifier: true,
                    itemExtent: 40,
                    onSelectedItemChanged: (index) {
                      setState(() => isAM = index == 0);
                    },
                    children: ['AM', 'PM'].map((text) {
                      bool isSelected =
                          (text == 'AM' && isAM) || (text == 'PM' && !isAM);
                      return Center(
                        child: Text(
                          text,
                          style: TextStyle(
                            fontSize: 20,
                            color: isSelected
                                ? const Color(0xFF1E3A8A)
                                : Colors.black87,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
