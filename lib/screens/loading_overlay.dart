import 'package:flutter/material.dart';
import '../utils/initialization_state.dart';

class LoadingOverlay extends StatelessWidget {
  static final _state = InitializationState();
  final Widget child;

  const LoadingOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _state.isInitialized,
      builder: (context, initialized, _) {
        if (initialized) {
          return child;
        }

        // Mostrar pantalla de carga con progreso
        return Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A8A).withAlpha(25),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.flash_on_rounded,
                    size: 64,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'AURA',
                  style: TextStyle(
                    fontSize: 24,
                    color: Color(0xFF1E3A8A),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 32),
                ValueListenableBuilder<double>(
                  valueListenable: _state.progress,
                  builder: (context, progress, _) => SizedBox(
                    width: 200,
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: const Color(0xFF1E3A8A).withOpacity(0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF1E3A8A),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ValueListenableBuilder<String>(
                  valueListenable: _state.currentStep,
                  builder: (context, step, _) => Text(
                    step,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF1E3A8A),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                ValueListenableBuilder<Map<String, bool>>(
                  valueListenable: _state.boxesStatus,
                  builder: (context, status, _) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: status.entries
                        .map(
                          (entry) => Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 32,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  entry.key,
                                  style: TextStyle(
                                    color: const Color(
                                      0xFF1E3A8A,
                                    ).withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                ),
                                Icon(
                                  entry.value
                                      ? Icons.check_circle_outline
                                      : Icons.hourglass_empty,
                                  color: entry.value
                                      ? Colors.green
                                      : const Color(
                                          0xFF1E3A8A,
                                        ).withOpacity(0.4),
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
