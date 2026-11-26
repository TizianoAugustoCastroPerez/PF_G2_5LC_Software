import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PantallaLista extends StatefulWidget {
  const PantallaLista({super.key});

  @override
  State<PantallaLista> createState() => _PantallaListaState();
}

class _UsuarioACargo {
  const _UsuarioACargo({required this.uid, required this.nombre});

  final String uid;
  final String nombre;
}

class _PantallaListaState extends State<PantallaLista> {
  final List<_UsuarioACargo> _usuarios = [];
  bool _cargando = true;
  String? _error;
  String? _uidEliminando;

  @override
  void initState() {
    super.initState();
    _cargarUsuarios();
  }

  Future<void> _cargarUsuarios() async {
    final responsable = FirebaseAuth.instance.currentUser;
    if (responsable == null) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = 'Debe iniciar sesión como responsable.';
      });
      return;
    }

    try {
      final perfil = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(responsable.uid)
          .get();
      final usuariosACargo = perfil.data()?['usuariosACargo'];
      if (usuariosACargo != null && usuariosACargo is! List) {
        throw const FormatException('El listado de usuarios no es válido.');
      }

      final ids = usuariosACargo is List
          ? usuariosACargo.whereType<String>().toSet().toList()
          : <String>[];
      final perfiles = await Future.wait(
        ids.map(
          (uid) =>
              FirebaseFirestore.instance.collection('usuarios').doc(uid).get(),
        ),
      );

      if (!mounted) return;
      setState(() {
        _usuarios
          ..clear()
          ..addAll(
            perfiles.map(
              (perfil) => _UsuarioACargo(
                uid: perfil.id,
                nombre:
                    perfil.data()?['nombreCompleto'] as String? ??
                    'Usuario sin nombre',
              ),
            ),
          );
        _cargando = false;
        _error = null;
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = 'No se pudieron cargar los usuarios: ${e.message ?? e.code}';
      });
    } on FormatException catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = e.message;
      });
    }
  }

  Future<void> _eliminarUsuario(_UsuarioACargo usuario) async {
    final responsable = FirebaseAuth.instance.currentUser;
    if (responsable == null) {
      _mostrarMensaje('Debe iniciar sesión como responsable.');
      return;
    }

    setState(() => _uidEliminando = usuario.uid);
    try {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(responsable.uid)
          .update({
            'usuariosACargo': FieldValue.arrayRemove([usuario.uid]),
          });

      if (!mounted) return;
      setState(() {
        _usuarios.removeWhere((item) => item.uid == usuario.uid);
        _uidEliminando = null;
      });
      _mostrarMensaje('Se quitó a ${usuario.nombre} de la lista.');
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() => _uidEliminando = null);
      _mostrarMensaje('No se pudo quitar al usuario: ${e.message ?? e.code}');
    }
  }

  void _mostrarMensaje(String mensaje) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Usuarios a cargo"), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              child: _cargando
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _cargando = true;
                                _error = null;
                              });
                              _cargarUsuarios();
                            },
                            child: const Text("Reintentar"),
                          ),
                        ],
                      ),
                    )
                  : _usuarios.isEmpty
                  ? const Center(child: Text("Todavía no agregaste usuarios."))
                  : ListView.separated(
                      itemCount: _usuarios.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final usuario = _usuarios[index];
                        final eliminando = _uidEliminando == usuario.uid;
                        return Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.secondaryContainer,
                              child: const Icon(Icons.person_outline),
                            ),
                            title: Text(
                              usuario.nombre,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: const Text("Ver datos y estado"),
                            onTap: () => context.go(
                              '/dashboard/${Uri.encodeComponent(usuario.uid)}',
                            ),
                            trailing: IconButton(
                              tooltip: "Quitar usuario",
                              onPressed: _uidEliminando == null
                                  ? () => _eliminarUsuario(usuario)
                                  : null,
                              icon: eliminando
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.person_remove_outlined),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: OutlinedButton.icon(
                onPressed: () => context.go('/responsable'),
                icon: const Icon(Icons.arrow_back),
                label: const Text("Volver"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
