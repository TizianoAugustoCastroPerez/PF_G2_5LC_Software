import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PantallaGuia extends StatelessWidget {
  const PantallaGuia({super.key});

  Future<void> _volverSegunTipo(BuildContext context) async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Debe iniciar sesión para volver a su pantalla."),
        ),
      );
      return;
    }

    try {
      final perfil = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(usuario.uid)
          .get();
      if (!context.mounted) return;

      final esResponsable = perfil.data()?['tipoUsuario'] == 'responsable';
      context.go(esResponsable ? '/responsable' : '/principal');
    } on FirebaseException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo consultar el tipo de usuario: ${e.message ?? e.code}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Guía de la aplicación"),
        centerTitle: true,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "CuidANDO",
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "CuidANDO es un proyecto desarrollado con el objetivo de brindar una herramienta de asistencia ante situaciones de emergencia. La aplicación permite configurar información importante del usuario y facilitar la comunicación con sus contactos prioritarios.",
                          style: TextStyle(fontSize: 16, color: Colors.black),
                        ),
                        const SizedBox(height: 30),
                        const Text(
                          "Cuenta",
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "Para utilizar la aplicación es necesario crear una cuenta utilizando un correo electrónico y una contraseña. Una vez registrada, la información quedará asociada a dicha cuenta para poder acceder a ella en cualquier momento.",
                          style: TextStyle(fontSize: 16, color: Colors.black),
                        ),
                        const SizedBox(height: 30),
                        const Text(
                          "Contactos",
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "En esta sección se pueden ingresar los números telefónicos que serán utilizados por la aplicación. Los contactos pueden ordenarse según la prioridad con la que serán utilizados en caso de ser necesario.",
                          style: TextStyle(fontSize: 16, color: Colors.black),
                        ),
                        const SizedBox(height: 30),
                        const Text(
                          "Perfil médico",
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "El perfil médico permite almacenar información relevante del usuario, como antecedentes, enfermedades, alergias, medicación u otros datos importantes que puedan ser útiles durante una emergencia.",
                          style: TextStyle(fontSize: 16, color: Colors.black),
                        ),
                        const SizedBox(height: 30),
                        const Text(
                          "Estado de Usuarios",
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "Los responsables tienen la opción de añadir a usuarios de los cuales son responsables para poder acceder a sus datos en tiempo real.",
                          style: TextStyle(fontSize: 16, color: Colors.black),
                        ),
                        const SizedBox(height: 30),
                        const Text(
                          "Dirección MAC",
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "Cada CuidANDO cuenta con su propia dirección MAC, que aparece pegada en el dispositivo en forma de etiqueta y es obligatoria para el uso del dispositivo.",
                          style: TextStyle(fontSize: 16, color: Colors.black),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: FilledButton.icon(
                onPressed: () => _volverSegunTipo(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 134, 222, 137),
                  foregroundColor: Colors.black,
                ),
                icon: const Icon(Icons.arrow_back),
                label: const Text("Volver", style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
