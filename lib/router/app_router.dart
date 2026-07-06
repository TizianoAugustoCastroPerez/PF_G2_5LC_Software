import 'package:go_router/go_router.dart';

import '../screens/pantalla_inicio.dart';
import '../screens/pantalla_login.dart';
import '../screens/pantalla_registro.dart';
import '../screens/pantalla_principal.dart';
import '../screens/pantalla_numeros.dart';
import '../screens/pantalla_perfilmedico.dart';
import '../screens/pantalla_guia.dart';

final GoRouter router = GoRouter(
  routes: [

    GoRoute(
      path: '/',
      builder: (context, state) => const PantallaInicio(),
    ),

    GoRoute(
      path: '/login',
      builder: (context, state) => const PantallaLogin(),
    ),

    GoRoute(
      path: '/register',
      builder: (context, state) => const PantallaRegistro(),
    ),

    GoRoute(
      path: '/principal',
      builder: (context, state) => const PantallaPrincipal(),
    ),

    GoRoute(
      path: '/numeros',
      builder: (context, state) => const PantallaNumeros(),
    ),

    GoRoute(
      path: '/perfil_medico',
      builder: (context, state) => const PantallaPerfilMedico(),
    ),

    GoRoute(
      path: '/guia',
      builder: (context, state) => const PantallaGuia(),
    ),

  ],
);