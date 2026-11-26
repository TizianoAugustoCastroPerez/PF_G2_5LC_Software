import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PantallaInicio extends StatelessWidget {
  const PantallaInicio({super.key});

  @override
  Widget build(BuildContext context) {
    final tipoUsuario =
        GoRouterState.of(context).uri.queryParameters['tipo'] ?? 'responsable';

    return Scaffold(
      appBar: AppBar(title: const Text("Proyecto")),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.sizeOf(context).height - 112,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      children: [
                        Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE7F0F8),
                            borderRadius: BorderRadius.circular(56),
                          ),
                          child: const Icon(
                            Icons.health_and_safety_outlined,
                            size: 96,
                            color: Color(0xFF527A9E),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          "Inicie sesión o regístrese",
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Acceda a su cuenta o cree una nueva para continuar.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 28),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.tonalIcon(
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 64),
                                ),
                                onPressed: () => context.go('/login'),
                                icon: const Icon(Icons.login),
                                label: const Text(
                                  "Iniciar sesión",
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.tonalIcon(
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 64),
                                ),
                                onPressed: () =>
                                    context.go('/register?tipo=$tipoUsuario'),
                                icon: const Icon(Icons.person_add_alt_1),
                                label: const Text(
                                  "Registrarse",
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
