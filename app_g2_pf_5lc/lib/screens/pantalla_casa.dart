import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PantallaCasa extends StatefulWidget {
  const PantallaCasa({super.key});

  @override
  State<PantallaCasa> createState() => _PantallaCasaState();
}

class _PantallaCasaState extends State<PantallaCasa> {
  final TextEditingController direccionController = TextEditingController();

  bool _cargando = true;
  bool _guardando = false;
  String? _errorCarga;

  @override
  void initState() {
    super.initState();
    _cargarDireccion();
  }

  Future<void> _cargarDireccion() async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) {
      setState(() {
        _cargando = false;
        _errorCarga = 'Debe iniciar sesión para consultar el domicilio.';
      });
      return;
    }

    try {
      final documento = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(usuario.uid)
          .get();
      final direccion = documento.data()?['direccion'];

      if (direccion != null && direccion is! String) {
        if (!mounted) return;
        setState(() {
          _cargando = false;
          _errorCarga = 'El domicilio guardado tiene un formato inválido.';
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        direccionController.text = direccion ?? '';
        _cargando = false;
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _errorCarga = 'No se pudo cargar el domicilio: ${e.message ?? e.code}';
      });
    }
  }

  Future<void> _guardarDireccion() async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Debe iniciar sesión para guardar el domicilio."),
        ),
      );
      return;
    }

    if (_errorCarga != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Vuelva a cargar el domicilio antes de guardarlo."),
        ),
      );
      return;
    }

    final direccion = direccionController.text.trim();
    if (direccion.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Ingrese un domicilio.")));
      return;
    }

    setState(() => _guardando = true);
    try {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(usuario.uid)
          .set({'direccion': direccion}, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Domicilio actualizado correctamente.")),
      );
      context.go('/principal');
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo guardar el domicilio: ${e.message ?? e.code}',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    direccionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Cambiar domicilio"), centerTitle: true),
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
                              _cargarDireccion();
                            },
                            child: const Text("Reintentar"),
                          ),
                        ],
                      ),
                    )
                  : TextField(
                      controller: direccionController,
                      enabled: !_guardando,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: "Domicilio",
                        hintText: "Ingrese la dirección",
                        border: OutlineInputBorder(),
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
                        : _guardarDireccion,
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
