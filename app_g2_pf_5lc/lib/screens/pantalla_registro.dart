import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PantallaRegistro extends StatefulWidget {
  const PantallaRegistro({required this.tipoInicial, super.key});

  final String tipoInicial;

  @override
  State<PantallaRegistro> createState() => _PantallaRegistroState();
}

class _PantallaRegistroState extends State<PantallaRegistro> {
  final TextEditingController nombreController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController direccionController = TextEditingController();
  final TextEditingController direccionMacController = TextEditingController();

  late String tipoUsuario;
  bool _mostrarContrasena = false;

  bool get esAdultoMayor => tipoUsuario == 'adulto_mayor';

  @override
  void initState() {
    super.initState();
    tipoUsuario = widget.tipoInicial == 'adulto_mayor'
        ? 'adulto_mayor'
        : 'responsable';
  }

  Future<void> registrarse() async {
    if (nombreController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty ||
        passwordController.text.isEmpty ||
        (esAdultoMayor &&
            (direccionController.text.trim().isEmpty ||
                direccionMacController.text.trim().isEmpty))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Complete todos los campos.")),
      );
      return;
    }

    if (passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("La contraseña debe tener al menos 6 caracteres."),
        ),
      );
      return;
    }

    var cuentaCreada = false;
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passwordController.text,
          );
      cuentaCreada = true;

      final user = credential.user;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No se pudo obtener la cuenta recién creada."),
          ),
        );
        return;
      }

      await user.updateDisplayName(nombreController.text.trim());
      await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).set(
        {
          'nombreCompleto': nombreController.text.trim(),
          'correo': emailController.text.trim(),
          'tipoUsuario': tipoUsuario,
          if (esAdultoMayor) ...{
            'direccion': direccionController.text.trim(),
            'direccionMac': direccionMacController.text.trim(),
          },
          'fechaCreacion': FieldValue.serverTimestamp(),
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cuenta creada correctamente.")),
      );
      context.go(esAdultoMayor ? '/principal' : '/responsable');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String mensaje;

      if (cuentaCreada) {
        mensaje =
            'La cuenta se creó, pero no se pudo completar el perfil: '
            '${e.message ?? e.code}';
      } else {
        switch (e.code) {
          case 'email-already-in-use':
            mensaje = 'Ese correo ya está registrado.';
            break;
          case 'invalid-email':
            mensaje = 'El correo electrónico no es válido.';
            break;
          case 'weak-password':
            mensaje = 'La contraseña es demasiado débil.';
            break;
          default:
            mensaje = e.message ?? 'Ocurrió un error al registrarse.';
        }
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mensaje)));
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'La cuenta se creó, pero no se pudieron guardar los datos '
            'del perfil: ${e.message ?? e.code}',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    nombreController.dispose();
    emailController.dispose();
    passwordController.dispose();
    direccionController.dispose();
    direccionMacController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Registro"), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                "Crear una cuenta",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'responsable',
                    label: Text('Responsable'),
                    icon: Icon(Icons.supervisor_account_outlined),
                  ),
                  ButtonSegment(
                    value: 'adulto_mayor',
                    label: Text('Adulto mayor'),
                    icon: Icon(Icons.elderly_outlined),
                  ),
                ],
                selected: {tipoUsuario},
                showSelectedIcon: false,
                onSelectionChanged: (seleccion) =>
                    setState(() => tipoUsuario = seleccion.first),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: nombreController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: "Nombre completo",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: "Correo electrónico",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: !_mostrarContrasena,
                decoration: InputDecoration(
                  labelText: "Contraseña",
                  border: OutlineInputBorder(),
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
              if (esAdultoMayor) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: direccionController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: "Dirección",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: direccionMacController,
                  decoration: const InputDecoration(
                    labelText: "Dirección MAC del cuidANDO",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: registrarse,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text("Registrarse"),
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => context.go('/login'),
                icon: const Icon(Icons.login),
                label: const Text("¿Ya tiene una cuenta? Inicie sesión"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
