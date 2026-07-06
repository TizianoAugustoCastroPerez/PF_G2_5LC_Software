import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PantallaInicio extends StatelessWidget {
  const PantallaInicio({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Proyecto"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              "assets/logo.png",
              height: 180,
            ),

            const SizedBox(height: 30),

            const Text(
              "Inicie sesión o regístrese",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 40),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      minimumSize: const Size(0, 80),
                    ),
                    onPressed: () {
                      context.go('/login');
                    },
                    child: const Text(
                      "Iniciar\nSesión",
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                const SizedBox(width: 20),

                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      minimumSize: const Size(0, 80),
                    ),
                    onPressed: () {
                      context.go('/register');
                    },
                    child: const Text(
                      "Registrarse",
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}