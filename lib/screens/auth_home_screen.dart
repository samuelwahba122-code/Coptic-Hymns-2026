import 'package:flutter/material.dart';

class AuthHomeScreen extends StatelessWidget {
  const AuthHomeScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Card(
            elevation: 0,
            color: cs.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // icon container (same style as Groups)
                  Container(
                    width: 140,
                    height: 140,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: cs.primary.withValues(alpha: 0.12),
                    ),
                    child: Image.asset(
                      'assets/icon/icon.png',
                      width: 88,
                      height: 88,
                    ),
                  ),

                  const SizedBox(height: 24),

                  Text(
                    "Learn Coptic Hymns",
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 12),

                  Text(
                    "Coptic hymns with audio and synchronized lyrics",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.75),
                        ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 200),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onContinue,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text("Continue"),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    "© Samuel Wahba 2026",
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
