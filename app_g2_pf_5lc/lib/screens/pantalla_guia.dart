import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PantallaGuia extends StatelessWidget {
  const PantallaGuia({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Guía de la aplicación"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "CuidANDO",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    const Text(
                      "CuidANDO es un proyecto desarrollado con el objetivo de brindar una herramienta de asistencia ante situaciones de emergencia. La aplicación permite configurar información importante del usuario y facilitar la comunicación con sus contactos prioritarios.",
                      style: TextStyle(fontSize: 16),
                    ),

                    const SizedBox(height: 30),

                    const Text(
                      "Cuenta",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    const Text(
                      "Para utilizar la aplicación es necesario crear una cuenta utilizando un correo electrónico y una contraseña. Una vez registrada, la información quedará asociada a dicha cuenta para poder acceder a ella en cualquier momento.",
                      style: TextStyle(fontSize: 16),
                    ),

                    const SizedBox(height: 30),

                    const Text(
                      "Contactos",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    const Text(
                      "En esta sección se pueden ingresar los números telefónicos que serán utilizados por la aplicación. Los contactos pueden ordenarse según la prioridad con la que serán utilizados en caso de ser necesario.",
                      style: TextStyle(fontSize: 16),
                    ),

                    const SizedBox(height: 30),

                    const Text(
                      "Perfil médico",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    const Text(
                      "El perfil médico permite almacenar información relevante del usuario, como antecedentes, enfermedades, alergias, medicación u otros datos importantes que puedan ser útiles durante una emergencia.",
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  context.go('/principal');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                child: const Text(
                  "Volver",
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}