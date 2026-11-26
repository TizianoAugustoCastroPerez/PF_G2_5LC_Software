import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PantallaResponsable extends StatelessWidget {
  const PantallaResponsable({super.key});

  Future<void> _cerrarSesion(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        context.go('/');
      }
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo cerrar la sesión: ${e.message ?? e.code}'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Panel de responsable"),
        centerTitle: true,
      ),
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
                      Icons.supervisor_account_outlined,
                      size: 32,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Panel de responsable',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "En esta pantalla se regula a los usuarios de los que "
                      "eres responsable.",
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.tonalIcon(
              onPressed: () => context.go('/agregar'),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text("Agregar usuarios de cuidando"),
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: () => context.go('/lista'),
              icon: const Icon(Icons.monitor_heart_outlined),
              label: const Text("Ver estado de usuarios"),
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: () => context.go('/guia'),
              icon: const Icon(Icons.menu_book_outlined),
              label: const Text("Guía de la aplicación"),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => _cerrarSesion(context),
              icon: const Icon(Icons.logout),
              label: const Text("Cerrar sesión"),
            ),
          ],
        ),
      ),
    );
  }
}
