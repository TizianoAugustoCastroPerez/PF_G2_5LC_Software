import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PantallaMac extends StatefulWidget {
  const PantallaMac({super.key});

  @override
  State<PantallaMac> createState() => _PantallaMacState();
}

class _PantallaMacState extends State<PantallaMac> {
  final TextEditingController direccionMacController = TextEditingController();

  bool _cargando = true;
  bool _guardando = false;
  String? _errorCarga;

  @override
  void initState() {
    super.initState();
    _cargarMac();
  }

  Future<void> _cargarMac() async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _errorCarga = 'Debe iniciar sesión para consultar la dirección MAC.';
      });
      return;
    }

    try {
      final documento = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(usuario.uid)
          .get();
      final datos = documento.data();
      final direccionMac = datos?['direccionMac'];

      if (direccionMac != null && direccionMac is! String) {
        if (!mounted) return;
        setState(() {
          _cargando = false;
          _errorCarga = 'La dirección MAC guardada tiene un formato inválido.';
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        direccionMacController.text = direccionMac ?? '';
        _cargando = false;
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _errorCarga =
            'No se pudo cargar la dirección MAC: ${e.message ?? e.code}';
      });
    }
  }

  Future<void> _guardarMac() async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) {
      _mostrarMensaje("Debe iniciar sesión para guardar la dirección MAC.");
      return;
    }
    if (_errorCarga != null) {
      _mostrarMensaje("Vuelva a cargar los datos antes de guardarlos.");
      return;
    }

    final direccionMac = direccionMacController.text.trim();
    if (direccionMac.isEmpty) {
      _mostrarMensaje("Ingrese la dirección MAC.");
      return;
    }

    setState(() => _guardando = true);
    try {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(usuario.uid)
          .set({
            'direccionMac': direccionMac,
          }, SetOptions(merge: true));

      if (!mounted) return;
      _mostrarMensaje("Dirección MAC actualizada correctamente.");
      context.go('/principal');
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      _mostrarMensaje(
        'No se pudo guardar la dirección MAC: ${e.message ?? e.code}',
      );
    }
  }

  void _mostrarMensaje(String mensaje) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  void dispose() {
    direccionMacController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Cambiar dirección MAC"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
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
                              _cargarMac();
                            },
                            child: const Text("Reintentar"),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          TextField(
                            controller: direccionMacController,
                            enabled: !_guardando,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: "Dirección MAC del cuidANDO",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _cargando || _guardando || _errorCarga != null
                        ? null
                        : _guardarMac,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 55),
                    ),
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
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 55),
                    ),
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
