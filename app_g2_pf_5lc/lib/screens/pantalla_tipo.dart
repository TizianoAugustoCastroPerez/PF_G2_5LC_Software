import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PantallaTipo extends StatelessWidget {
  const PantallaTipo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.sizeOf(context).height - 48,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: Image.asset(
                    'assets/cuidando.png',
                    width: 220,
                    height: 220,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 32),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          'Bienvenido a la app oficial de cuidANDO',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Una app diseñada para brindarle seguridad a "
                          "adultos mayores ante caídas e informarlo en el "
                          "menor tiempo posible.",
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          '¿Usted es un adulto mayor o un responsable?',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () => context.go('/inicio?tipo=responsable'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 64),
                        ),
                        icon: const Icon(Icons.supervisor_account_outlined),
                        label: const Text(
                          "Responsable",
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () =>
                            context.go('/inicio?tipo=adulto_mayor'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 64),
                        ),
                        icon: const Icon(Icons.elderly_outlined),
                        label: const Text(
                          "Adulto mayor",
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
