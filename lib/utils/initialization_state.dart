import 'package:flutter/foundation.dart';

class InitializationState {
  static final InitializationState _instance = InitializationState._internal();
  factory InitializationState() => _instance;
  InitializationState._internal();

  final ValueNotifier<bool> isInitialized = ValueNotifier(false);
  final ValueNotifier<String> currentStep = ValueNotifier('Iniciando...');
  final ValueNotifier<double> progress = ValueNotifier(0.0);
  final ValueNotifier<Map<String, bool>> boxesStatus = ValueNotifier({});

  void updateStep(String step) {
    currentStep.value = step;
    if (kDebugMode) {
      print('${DateTime.now().toIso8601String()} - $step');
    }
  }

  void updateProgress(double value) {
    progress.value = value;
  }

  void updateBoxStatus(String boxName, bool isOpen) {
    final currentStatus = Map<String, bool>.from(boxesStatus.value);
    currentStatus[boxName] = isOpen;
    boxesStatus.value = currentStatus;
  }

  bool get allEssentialBoxesOpen {
    final requiredBoxes = {
      'medicamentos': false,
      'tomas_medicamentos': false,
      'crisis': false,
      'estado_animico': false,
    };

    final currentStatus = boxesStatus.value;
    for (final box in requiredBoxes.keys) {
      if (!currentStatus.containsKey(box) || !currentStatus[box]!) {
        return false;
      }
    }
    return true;
  }
}
