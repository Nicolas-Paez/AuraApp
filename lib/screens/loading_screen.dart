import 'package:flutter/material.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
            const CircularProgressIndicator(
              color: Color(0xFF1E3A8A),
              strokeWidth: 3,
            ),
            const SizedBox(height: 24),
            const Text(
              'Cargando...',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF1E3A8A),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
