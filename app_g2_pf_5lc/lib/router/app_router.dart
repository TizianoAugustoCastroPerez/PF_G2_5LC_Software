import 'package:go_router/go_router.dart';

import '../screens/pantalla_inicio.dart';
import '../screens/pantalla_tipo.dart';
import '../screens/pantalla_login.dart';
import '../screens/pantalla_registro.dart';
import '../screens/pantalla_principal.dart';
import '../screens/pantalla_numeros.dart';
import '../screens/pantalla_perfilmedico.dart';
import '../screens/pantalla_guia.dart';
import '../screens/pantalla_casa.dart';
import '../screens/pantalla_responsable.dart';
import '../screens/pantalla_agregar.dart';
import '../screens/pantalla_lista.dart';
import '../screens/pantalla_mac.dart';
import '../screens/pantalla_dashboard.dart';

final GoRouter router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const PantallaTipo()),

    GoRoute(
      path: '/inicio',
      builder: (context, state) => const PantallaInicio(),
    ),

    GoRoute(path: '/login', builder: (context, state) => const PantallaLogin()),

    GoRoute(
      path: '/register',
      builder: (context, state) => PantallaRegistro(
        tipoInicial: state.uri.queryParameters['tipo'] ?? 'responsable',
      ),
    ),

    GoRoute(
      path: '/principal',
      builder: (context, state) => const PantallaPrincipal(),
    ),

    GoRoute(
      path: '/responsable',
      builder: (context, state) => const PantallaResponsable(),
    ),

    GoRoute(
      path: '/agregar',
      builder: (context, state) => const PantallaAgregar(),
    ),

    GoRoute(path: '/lista', builder: (context, state) => const PantallaLista()),

    GoRoute(
      path: '/dashboard/:usuarioId',
      builder: (context, state) =>
          PantallaDashboard(usuarioId: state.pathParameters['usuarioId']!),
    ),

    GoRoute(
      path: '/numeros',
      builder: (context, state) => const PantallaNumeros(),
    ),

    GoRoute(
      path: '/perfil_medico',
      builder: (context, state) => const PantallaPerfilMedico(),
    ),

    GoRoute(path: '/guia', builder: (context, state) => const PantallaGuia()),

    GoRoute(path: '/casa', builder: (context, state) => const PantallaCasa()),

    GoRoute(path: '/mac', builder: (context, state) => const PantallaMac()),
  ],
);
