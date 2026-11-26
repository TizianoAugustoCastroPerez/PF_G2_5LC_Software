import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PantallaNumeros extends StatefulWidget {
  const PantallaNumeros({super.key});

  @override
  State<PantallaNumeros> createState() => _PantallaNumerosState();
}

class _PantallaNumerosState extends State<PantallaNumeros> {
  static const int _maxTelefonos = 3;

  final TextEditingController numeroController = TextEditingController();
  final List<String> telefonos = [];

  bool _cargando = true;
  bool _guardando = false;
  String? _errorCarga;

  bool get _puedeAgregarNumero =>
      !_cargando && !_guardando && telefonos.length < _maxTelefonos;

  @override
  void initState() {
    super.initState();
    _cargarTelefonos();
  }

  bool numeroValido(String numero) {
    final regex = RegExp(r'^\+?[0-9]{8,15}$');
    return regex.hasMatch(numero);
  }

  Future<void> _cargarTelefonos() async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) {
      setState(() {
        _cargando = false;
        _errorCarga = 'Debe iniciar sesión para ver sus números guardados.';
      });
      return;
    }

    try {
      final documento = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(usuario.uid)
          .get();
      final numerosGuardados = documento.data()?['telefonos'];

      if (numerosGuardados != null && numerosGuardados is! List) {
        setState(() {
          _cargando = false;
          _errorCarga = 'Los números guardados tienen un formato inválido.';
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        if (numerosGuardados is List) {
          telefonos.addAll(numerosGuardados.whereType<String>());
        }
        _cargando = false;
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _errorCarga =
            'No se pudieron cargar los números: ${e.message ?? e.code}';
      });
    }
  }

  void agregarNumero() {
    if (telefonos.length >= _maxTelefonos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Solo puede agregar hasta 3 números.")),
      );
      return;
    }

    final numero = numeroController.text.trim();

    if (!numeroValido(numero)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Número telefónico inválido.")),
      );
      return;
    }

    setState(() {
      telefonos.add(numero);
      numeroController.clear();
    });
  }

  Future<void> guardarTelefonos() async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Debe iniciar sesión para guardar los números."),
        ),
      );
      return;
    }
    if (_errorCarga != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Vuelva a cargar los números antes de guardarlos."),
        ),
      );
      return;
    }

    setState(() => _guardando = true);
    try {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(usuario.uid)
          .set({'telefonos': telefonos}, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Números guardados correctamente.")),
      );
      context.go('/principal');
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudieron guardar los números: ${e.message ?? e.code}',
          ),
        ),
      );
    }
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
                    enabled: !_cargando && !_guardando,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText:
                          "Número telefónico (poner código de área y los 8 números)",
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => agregarNumero(),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  tooltip: "Agregar número",
                  onPressed: _puedeAgregarNumero ? agregarNumero : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 25),
            Expanded(
              child: _cargando
                  ? const Center(child: CircularProgressIndicator())
                  : _errorCarga != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_errorCarga!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _cargando = true;
                                _errorCarga = null;
                              });
                              _cargarTelefonos();
                            },
                            child: const Text("Reintentar"),
                          ),
                        ],
                      ),
                    )
                  : ReorderableListView.builder(
                      itemCount: telefonos.length,
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) {
                            newIndex--;
                          }
                          final telefono = telefonos.removeAt(oldIndex);
                          telefonos.insert(newIndex, telefono);
                        });
                      },
                      itemBuilder: (context, index) {
                        return Card(
                          key: ValueKey('telefono-$index'),
                          child: ListTile(
                            leading: CircleAvatar(child: Text("${index + 1}")),
                            title: Text(telefonos[index]),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: "Eliminar número",
                                  onPressed: _guardando
                                      ? null
                                      : () {
                                          setState(() {
                                            telefonos.removeAt(index);
                                          });
                                        },
                                  icon: const Icon(Icons.remove),
                                ),
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
                  child: FilledButton.icon(
                    onPressed: _cargando || _guardando
                        ? null
                        : guardarTelefonos,
                    icon: _guardando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_guardando ? "Guardando..." : "Guardar"),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _guardando
                        ? null
                        : () => context.go('/principal'),
                    icon: const Icon(Icons.close),
                    label: const Text("Cancelar"),
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
