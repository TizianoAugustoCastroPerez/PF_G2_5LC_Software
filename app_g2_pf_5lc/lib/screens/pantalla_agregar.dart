import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../firebase_options.dart';

class PantallaAgregar extends StatefulWidget {
  const PantallaAgregar({super.key});

  @override
  State<PantallaAgregar> createState() => _PantallaAgregarState();
}

class _PantallaAgregarState extends State<PantallaAgregar> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _guardando = false;
  bool _mostrarContrasena = false;
  bool _cargandoCantidad = true;
  int _usuariosAgregados = 0;
  String? _errorCantidad;

  bool get _alcanzoLimite => _usuariosAgregados >= 5;

  @override
  void initState() {
    super.initState();
    _cargarCantidadUsuarios();
  }

  Future<void> _cargarCantidadUsuarios() async {
    final responsable = FirebaseAuth.instance.currentUser;
    if (responsable == null) {
      if (!mounted) return;
      setState(() {
        _cargandoCantidad = false;
        _errorCantidad = 'Debe iniciar sesión como responsable.';
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

      if (!mounted) return;
      setState(() {
        _usuariosAgregados = usuariosACargo is List
            ? usuariosACargo.whereType<String>().toSet().length
            : 0;
        _cargandoCantidad = false;
        _errorCantidad = null;
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _cargandoCantidad = false;
        _errorCantidad =
            'No se pudo consultar la cantidad de usuarios: '
            '${e.message ?? e.code}';
      });
      _mostrarMensaje(_errorCantidad!);
    } on FormatException catch (e) {
      if (!mounted) return;
      setState(() {
        _cargandoCantidad = false;
        _errorCantidad = e.message;
      });
      _mostrarMensaje(_errorCantidad!);
    }
  }

  Future<void> _guardar() async {
    if (_cargandoCantidad) return;
    if (_errorCantidad != null) {
      _mostrarMensaje(_errorCantidad!);
      return;
    }
    if (_alcanzoLimite) {
      _mostrarMensaje("demasiados usuarios agregados");
      return;
    }

    final responsable = FirebaseAuth.instance.currentUser;
    if (responsable == null) {
      _mostrarMensaje("Debe iniciar sesión como responsable.");
      return;
    }

    final email = emailController.text.trim();
    final password = passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _mostrarMensaje("Complete todos los campos.");
      return;
    }

    setState(() => _guardando = true);

    FirebaseApp? appValidacion;
    FirebaseAuth? authValidacion;
    String? error;
    String? errorLimpieza;
    var vinculado = false;

    try {
      final perfilResponsable = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(responsable.uid)
          .get();

      if (perfilResponsable.data()?['tipoUsuario'] != 'responsable') {
        error = 'Esta acción solo está disponible para cuentas responsables.';
      } else {
        final usuariosACargo = perfilResponsable.data()?['usuariosACargo'];
        if (usuariosACargo != null && usuariosACargo is! List) {
          error = 'El listado de usuarios del responsable no es válido.';
        } else if (usuariosACargo is List &&
            usuariosACargo.whereType<String>().toSet().length >= 5) {
          _usuariosAgregados = 5;
          error = "demasiados usuarios agregados";
        }
      }

      if (error == null) {
        appValidacion = await Firebase.initializeApp(
          name: 'validacion-adulto-${DateTime.now().microsecondsSinceEpoch}',
          options: DefaultFirebaseOptions.currentPlatform,
        );
        authValidacion = FirebaseAuth.instanceFor(app: appValidacion);
        final credencial = await authValidacion.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        final adulto = credencial.user;

        if (adulto == null) {
          error = 'No se pudo validar la cuenta del adulto.';
        } else {
          final perfilAdulto = await FirebaseFirestore.instanceFor(
            app: appValidacion,
          ).collection('usuarios').doc(adulto.uid).get();

          if (perfilAdulto.data()?['tipoUsuario'] != 'adulto_mayor') {
            error = 'La cuenta ingresada no está registrada como adulto mayor.';
          } else {
            final perfilResponsableRef = FirebaseFirestore.instance
                .collection('usuarios')
                .doc(responsable.uid);
            await FirebaseFirestore.instance.runTransaction((
              transaction,
            ) async {
              final perfilActual = await transaction.get(perfilResponsableRef);
              final usuariosActuales = perfilActual.data()?['usuariosACargo'];
              if (usuariosActuales != null && usuariosActuales is! List) {
                throw const FormatException(
                  'El listado de usuarios del responsable no es válido.',
                );
              }

              final idsActuales = usuariosActuales is List
                  ? usuariosActuales.whereType<String>().toSet()
                  : <String>{};
              if (idsActuales.contains(adulto.uid)) {
                _usuariosAgregados = idsActuales.length;
                return;
              }
              if (idsActuales.length >= 5) {
                _usuariosAgregados = idsActuales.length;
                throw StateError("demasiados usuarios agregados");
              }

              transaction.set(perfilResponsableRef, {
                'usuariosACargo': FieldValue.arrayUnion([adulto.uid]),
              }, SetOptions(merge: true));
              _usuariosAgregados = idsActuales.length + 1;
            });
            vinculado = true;
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      error = switch (e.code) {
        'invalid-credential' || 'wrong-password' || 'user-not-found' =>
          'El correo o la contraseña del adulto son incorrectos.',
        'invalid-email' => 'El correo electrónico no es válido.',
        'too-many-requests' =>
          'Demasiados intentos. Intente nuevamente más tarde.',
        _ => e.message ?? 'No se pudo validar la cuenta del adulto.',
      };
    } on FirebaseException catch (e) {
      error = 'No se pudo vincular la cuenta: ${e.message ?? e.code}';
    } on FormatException catch (e) {
      error = e.message;
    } on StateError catch (e) {
      error = e.message;
    } finally {
      if (authValidacion != null) {
        try {
          await authValidacion.signOut();
        } on FirebaseException catch (e) {
          errorLimpieza =
              'No se pudo cerrar la sesión temporal: ${e.message ?? e.code}';
        }
      }
      if (appValidacion != null) {
        try {
          await appValidacion.delete();
        } on FirebaseException catch (e) {
          errorLimpieza ??=
              'No se pudo liberar la validación temporal: '
              '${e.message ?? e.code}';
        }
      }
    }

    if (!mounted) return;
    setState(() => _guardando = false);
    passwordController.clear();

    if (vinculado) {
      final mensaje = errorLimpieza == null
          ? "Usuario agregado correctamente."
          : "Usuario agregado. $errorLimpieza";
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mensaje)));
      context.go('/responsable');
      return;
    }

    _mostrarMensaje(error ?? errorLimpieza ?? "No se pudo agregar al usuario.");
  }

  void _mostrarMensaje(String mensaje) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Agregar usuario"), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      "Vincular adulto mayor",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Ingrese las credenciales de su cuenta para agregarla "
                      "a su lista de usuarios.",
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: emailController,
                      enabled: !_guardando,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: "Mail del adulto",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      enabled: !_guardando,
                      obscureText: !_mostrarContrasena,
                      decoration: InputDecoration(
                        labelText: "Contraseña del adulto",
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: _mostrarContrasena
                              ? "Ocultar contraseña"
                              : "Mostrar contraseña",
                          onPressed: () {
                            setState(() {
                              _mostrarContrasena = !_mostrarContrasena;
                            });
                          },
                          icon: Icon(
                            _mostrarContrasena
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _cargandoCantidad || _guardando ? null : _guardar,
                    icon: _guardando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.person_add_alt_1),
                    label: Text(_guardando ? "Agregando..." : "Agregar"),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _guardando
                        ? null
                        : () => context.go('/responsable'),
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
