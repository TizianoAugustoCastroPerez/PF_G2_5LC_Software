import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PantallaNumeros extends StatefulWidget {
  const PantallaNumeros({super.key});

  @override
  State<PantallaNumeros> createState() => _PantallaNumerosState();
}

class _PantallaNumerosState extends State<PantallaNumeros> {
  final TextEditingController numeroController = TextEditingController();

  final List<Map<String, String>> telefonos = [];

  bool numeroValido(String numero) {
    final regex = RegExp(r'^\+?[0-9]{8,15}$');
    return regex.hasMatch(numero);
  }

  void agregarNumero() {
    final numero = numeroController.text.trim();

    if (!numeroValido(numero)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Número telefónico inválido."),
        ),
      );
      return;
    }

    setState(() {
      telefonos.add({
        "numero": numero,
        "pais": "---",
      });

      numeroController.clear();
    });
  }

  @override
  void dispose() {
    numeroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Lista de teléfonos"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: numeroController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: "Número telefónico",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                ElevatedButton(
                  onPressed: agregarNumero,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    minimumSize: const Size(60, 56),
                  ),
                  child: const Icon(Icons.add),
                ),
              ],
            ),

            const SizedBox(height: 25),

            Expanded(
              child: ReorderableListView.builder(
                itemCount: telefonos.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) {
                      newIndex--;
                    }

                    final item = telefonos.removeAt(oldIndex);
                    telefonos.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  return Card(
                    key: ValueKey(telefonos[index]),

                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text("${index + 1}"),
                      ),

                      title: Text(
                        telefonos[index]["numero"]!,
                      ),

                      subtitle: Text(
                        telefonos[index]["pais"]!,
                      ),

                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text("🏳️ ---"),

                          const SizedBox(width: 10),

                          ReorderableDragStartListener(
                            index: index,
                            child: const Icon(Icons.drag_handle),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 15),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      context.go('/principal');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text("Guardar"),
                  ),
                ),

                const SizedBox(width: 20),

                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      context.go('/principal');
                    },
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