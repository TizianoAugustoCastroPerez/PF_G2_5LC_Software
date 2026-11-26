import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PantallaPerfilMedico extends StatefulWidget {
  const PantallaPerfilMedico({super.key});

  @override
  State<PantallaPerfilMedico> createState() => _PantallaPerfilMedicoState();
}

class _PantallaPerfilMedicoState extends State<PantallaPerfilMedico> {
  final TextEditingController perfilController = TextEditingController();

  bool _cargando = true;
  bool _guardando = false;
  String? _errorCarga;

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
  }

  Future<void> _cargarPerfil() async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) {
      setState(() {
        _cargando = false;
        _errorCarga = 'Debe iniciar sesión para ver el perfil médico.';
      });
      return;
    }

    try {
      final documento = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(usuario.uid)
          .get();
      final perfilGuardado = documento.data()?['perfilMedico'];

      if (perfilGuardado != null && perfilGuardado is! String) {
        if (!mounted) return;
        setState(() {
          _cargando = false;
          _errorCarga = 'El perfil médico guardado tiene un formato inválido.';
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        perfilController.text = perfilGuardado ?? '';
        _cargando = false;
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _errorCarga =
            'No se pudo cargar el perfil médico: ${e.message ?? e.code}';
      });
    }
  }

  @override
  void dispose() {
    perfilController.dispose();
    super.dispose();
  }

  Future<void> guardarPerfil() async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Debe iniciar sesión para guardar el perfil médico."),
        ),
      );
      return;
    }
    if (_errorCarga != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Vuelva a cargar el perfil antes de guardarlo."),
        ),
      );
      return;
    }

    setState(() => _guardando = true);
    try {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(usuario.uid)
          .set({
            'perfilMedico': perfilController.text.trim(),
          }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Perfil médico guardado correctamente.")),
      );
      context.go('/principal');
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo guardar el perfil médico: ${e.message ?? e.code}',
          ),
        ),
      );
    }
  }

  void cancelar() {
    context.go('/principal');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Perfil médico"), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Ingrese el perfil médico del paciente:",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 15),

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
                              _cargarPerfil();
                            },
                            child: const Text("Reintentar"),
                          ),
                        ],
                      ),
                    )
                  : TextField(
                      controller: perfilController,
                      enabled: !_guardando,
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
                  child: FilledButton.icon(
                    onPressed: _cargando || _guardando || _errorCarga != null
                        ? null
                        : guardarPerfil,
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
                    onPressed: _guardando ? null : cancelar,
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
