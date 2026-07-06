import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PantallaPerfilMedico extends StatefulWidget {
  const PantallaPerfilMedico({super.key});

  @override
  State<PantallaPerfilMedico> createState() => _PantallaPerfilMedicoState();
}

class _PantallaPerfilMedicoState extends State<PantallaPerfilMedico> {
  final TextEditingController perfilController = TextEditingController();

  @override
  void dispose() {
    perfilController.dispose();
    super.dispose();
  }

  void guardarPerfil() {
    // Más adelante se guardará en Firebase.
    context.go('/principal');
  }

  void cancelar() {
    context.go('/principal');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Perfil médico"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Ingrese el perfil médico del paciente:",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 15),

            Expanded(
              child: TextField(
                controller: perfilController,
                keyboardType: TextInputType.multiline,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText:
                      "Escriba aquí toda la información médica relevante...",
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: guardarPerfil,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text("Guardar"),
                  ),
                ),

                const SizedBox(width: 20),

                Expanded(
                  child: ElevatedButton(
                    onPressed: cancelar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text("Cancelar"),
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