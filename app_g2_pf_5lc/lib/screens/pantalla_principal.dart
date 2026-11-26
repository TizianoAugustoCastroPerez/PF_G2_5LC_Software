import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class PantallaPrincipal extends StatelessWidget {
  const PantallaPrincipal({super.key});

  Future<void> cerrarSesion(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Página principal")),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.dashboard_outlined,
                      size: 32,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Datos del adulto mayor',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "En esta pantalla se ingresan todos los datos "
                      "necesarios del adulto mayor para que funcione la "
                      "aplicación correctamente.",
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.tonalIcon(
              onPressed: () => context.go('/numeros'),
              icon: const Icon(Icons.phone_outlined),
              label: const Text("Ingresar lista de números telefónicos"),
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: () => context.go('/perfil_medico'),
              icon: const Icon(Icons.medical_information_outlined),
              label: const Text("Perfil médico"),
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: () => context.go('/guia'),
              icon: const Icon(Icons.menu_book_outlined),
              label: const Text("Guía de la aplicación"),
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: () => context.go('/casa'),
              icon: const Icon(Icons.home_outlined),
              label: const Text("Cambiar domicilio"),
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: () => context.go('/mac'),
              icon: const Icon(Icons.memory_outlined),
              label: const Text("Cambiar dirección MAC"),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => cerrarSesion(context),
              icon: const Icon(Icons.logout),
              label: const Text("Cerrar sesión"),
            ),
          ],
        ),
      ),
    );
  }
}
