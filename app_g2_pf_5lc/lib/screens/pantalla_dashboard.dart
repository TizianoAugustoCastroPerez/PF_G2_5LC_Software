import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PantallaDashboard extends StatefulWidget {
  const PantallaDashboard({required this.usuarioId, super.key});

  final String usuarioId;

  @override
  State<PantallaDashboard> createState() => _PantallaDashboardState();
}

class _PantallaDashboardState extends State<PantallaDashboard> {
  static const _emergenciaActivaCampo = 'emergenciaDashboardActiva';
  static const _caidaReconocidaCampo = 'caidaDashboardReconocida';
  static const _ubicacionCongeladaCampo = 'enCasaDuranteEmergencia';
  static const _alertaReconocidaCampo = 'alertaDashboardReconocida';
  static const _tipoAlertaEmergenciaCampo = 'tipoAlertaDashboard';
  static const _tipoAlertaCampo = 'tipoAlerta';
  static const _alertaCaida = 'CAIDA';
  static const _alertaBoton = 'BOTON';
  static const _alertaNinguna = 'NINGUNO';

  late DocumentReference<Map<String, dynamic>> _usuarioRef;
  late Future<bool> _responsableAutorizado;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _suscripcionUsuario;
  Map<String, dynamic>? _datos;
  bool _cargando = true;
  bool _sincronizandoEmergencia = false;
  bool _sincronizacionPendiente = false;
  bool _finalizandoEmergencia = false;
  bool _ubicacionDeCaidaCapturada = false;
  bool? _enCasaPendiente;
  String? _error;

  @override
  void initState() {
    super.initState();
    _usuarioRef = _crearReferenciaUsuario();
    _responsableAutorizado = _verificarResponsable();
    _escucharUsuario();
  }

  @override
  void didUpdateWidget(covariant PantallaDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.usuarioId != widget.usuarioId) {
      _suscripcionUsuario?.cancel();
      _usuarioRef = _crearReferenciaUsuario();
      _responsableAutorizado = _verificarResponsable();
      _datos = null;
      _enCasaPendiente = null;
      _ubicacionDeCaidaCapturada = false;
      _error = null;
      _cargando = true;
      _escucharUsuario();
    }
  }

  DocumentReference<Map<String, dynamic>> _crearReferenciaUsuario() {
    return FirebaseFirestore.instance
        .collection('usuarios')
        .doc(widget.usuarioId);
  }

  Future<bool> _verificarResponsable() async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) return false;

    final perfil = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(usuario.uid)
        .get();
    final datosResponsable = perfil.data();
    final usuariosACargo = datosResponsable?['usuariosACargo'];
    if (usuariosACargo != null && usuariosACargo is! List) {
      throw const FormatException(
        'El listado de usuarios del responsable no es válido.',
      );
    }

    return datosResponsable?['tipoUsuario'] == 'responsable' &&
        (usuariosACargo is List &&
            usuariosACargo.whereType<String>().contains(widget.usuarioId));
  }

  void _escucharUsuario() {
    _suscripcionUsuario = _usuarioRef.snapshots().listen(
      (snapshot) {
        if (!mounted) return;
        if (!snapshot.exists) {
          setState(() {
            _datos = null;
            _cargando = false;
            _error = 'No se encontró el perfil de este usuario.';
          });
          return;
        }

        final datos = snapshot.data()!;
        if (datos['tipoUsuario'] != 'adulto_mayor') {
          setState(() {
            _datos = null;
            _cargando = false;
            _error = 'El perfil seleccionado no corresponde a un adulto mayor.';
          });
          return;
        }

        setState(() {
          _datos = datos;
          _cargando = false;
          _error = null;
          if (datos['seCayo'] != true &&
              datos[_tipoAlertaCampo] != _alertaCaida &&
              datos[_tipoAlertaCampo] != _alertaBoton &&
              datos[_emergenciaActivaCampo] != true) {
            _enCasaPendiente = null;
            _ubicacionDeCaidaCapturada = false;
          }
        });
        _sincronizarEstado(datos);
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _cargando = false;
          _error = 'No se pudieron cargar los datos: $error';
        });
      },
    );
  }

  bool? _valorEnCasa(Object? valor) => valor is bool ? valor : null;

  void _sincronizarEstado(Map<String, dynamic> datos) {
    final tipoAlerta = datos[_tipoAlertaCampo];
    final botonPendiente =
        tipoAlerta == _alertaBoton && datos[_alertaReconocidaCampo] != true;
    final caidaPendiente =
        (tipoAlerta == _alertaCaida && datos[_alertaReconocidaCampo] != true) ||
        (datos['seCayo'] == true &&
            datos[_alertaReconocidaCampo] != true &&
            datos[_caidaReconocidaCampo] != true);

    if ((tipoAlerta == _alertaNinguna &&
            datos[_alertaReconocidaCampo] == true) ||
        (datos['seCayo'] == false && datos[_caidaReconocidaCampo] == true)) {
      _limpiarAlertasReconocidas();
    }

    if ((botonPendiente || caidaPendiente) &&
        datos[_emergenciaActivaCampo] != true) {
      if (!_ubicacionDeCaidaCapturada) {
        _enCasaPendiente = _valorEnCasa(datos['enCasa']);
        _ubicacionDeCaidaCapturada = true;
      }
      _registrarEmergencia(
        botonPendiente ? _alertaBoton : _alertaCaida,
        _enCasaPendiente,
      );
    }
  }

  void _reintentarSincronizacionPendiente() {
    if (!_sincronizacionPendiente) return;
    _sincronizacionPendiente = false;
    final datos = _datos;
    if (datos != null) _sincronizarEstado(datos);
  }

  Future<void> _registrarEmergencia(
    String tipoAlerta,
    bool? enCasaAlDetectarla,
  ) async {
    if (_sincronizandoEmergencia) {
      _sincronizacionPendiente = true;
      return;
    }
    _sincronizandoEmergencia = true;
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(_usuarioRef);
        final datos = snapshot.data();
        if (datos == null) return;
        final alertaSigueActiva = tipoAlerta == _alertaBoton
            ? datos[_tipoAlertaCampo] == _alertaBoton &&
                  datos[_alertaReconocidaCampo] != true
            : ((datos[_tipoAlertaCampo] == _alertaCaida &&
                      datos[_alertaReconocidaCampo] != true) ||
                  (datos['seCayo'] == true &&
                      datos[_alertaReconocidaCampo] != true &&
                      datos[_caidaReconocidaCampo] != true));
        if (!alertaSigueActiva ||
            datos[_emergenciaActivaCampo] == true ||
            datos[_alertaReconocidaCampo] == true) {
          return;
        }

        transaction.update(_usuarioRef, {
          _emergenciaActivaCampo: true,
          _tipoAlertaEmergenciaCampo: tipoAlerta,
          _ubicacionCongeladaCampo: enCasaAlDetectarla ?? FieldValue.delete(),
        });
      });
    } on FirebaseException catch (error) {
      _mostrarErrorSincronizacion(
        'No se pudo guardar la emergencia: ${error.message ?? error.code}',
      );
    } finally {
      _sincronizandoEmergencia = false;
      _reintentarSincronizacionPendiente();
    }
  }

  Future<void> _limpiarAlertasReconocidas() async {
    if (_sincronizandoEmergencia) {
      _sincronizacionPendiente = true;
      return;
    }
    _sincronizandoEmergencia = true;
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(_usuarioRef);
        final datos = snapshot.data();
        if (datos == null) return;
        final actualizaciones = <String, Object>{};
        if (datos['seCayo'] == false && datos[_caidaReconocidaCampo] == true) {
          actualizaciones[_caidaReconocidaCampo] = FieldValue.delete();
        }
        if (datos[_tipoAlertaCampo] == _alertaNinguna &&
            datos[_alertaReconocidaCampo] == true) {
          actualizaciones[_alertaReconocidaCampo] = FieldValue.delete();
        }
        if (actualizaciones.isNotEmpty) {
          transaction.update(_usuarioRef, actualizaciones);
        }
      });
    } on FirebaseException catch (error) {
      _mostrarErrorSincronizacion(
        'No se pudo actualizar el estado de la alerta: '
        '${error.message ?? error.code}',
      );
    } finally {
      _sincronizandoEmergencia = false;
      _reintentarSincronizacionPendiente();
    }
  }

  Future<void> _confirmarFinalizacion() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finalizar emergencia'),
        content: const Text('¿Está seguro de que desea finalizarla?'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(false),
            icon: const Icon(Icons.close),
            label: const Text('No'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.check),
            label: const Text('Sí, finalizar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    setState(() => _finalizandoEmergencia = true);
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(_usuarioRef);
        final datos = snapshot.data();
        if (datos == null) return;
        final tipoAlerta = datos[_tipoAlertaCampo];
        final alertaPendiente =
            ((tipoAlerta == _alertaBoton || tipoAlerta == _alertaCaida) &&
                datos[_alertaReconocidaCampo] != true) ||
            (datos['seCayo'] == true && datos[_caidaReconocidaCampo] != true);
        if (datos[_emergenciaActivaCampo] != true && !alertaPendiente) {
          return;
        }
        transaction.update(_usuarioRef, {
          _emergenciaActivaCampo: false,
          _tipoAlertaEmergenciaCampo: FieldValue.delete(),
          _caidaReconocidaCampo: datos['seCayo'] == true
              ? true
              : FieldValue.delete(),
          _alertaReconocidaCampo:
              tipoAlerta == _alertaBoton || tipoAlerta == _alertaCaida
              ? true
              : FieldValue.delete(),
          _ubicacionCongeladaCampo: FieldValue.delete(),
        });
      });
    } on FirebaseException catch (error) {
      _mostrarErrorSincronizacion(
        'No se pudo finalizar la emergencia: '
        '${error.message ?? error.code}',
      );
    } finally {
      if (mounted) setState(() => _finalizandoEmergencia = false);
    }
  }

  void _mostrarErrorSincronizacion(String mensaje) {
    if (!mounted) return;
    setState(() => _error = mensaje);
  }

  @override
  void dispose() {
    _suscripcionUsuario?.cancel();
    super.dispose();
  }

  String _valorTexto(Map<String, dynamic> datos, String campo) {
    final valor = datos[campo];
    if (valor is String && valor.trim().isNotEmpty) {
      return valor.trim();
    }
    return 'Sin datos registrados';
  }

  String _valorTelefonos(Map<String, dynamic> datos) {
    final telefonos = datos['telefonos'];
    if (telefonos is! List) return 'Sin datos registrados';

    final numeros = telefonos
        .whereType<String>()
        .map((numero) => numero.trim())
        .where((numero) => numero.isNotEmpty)
        .toList();
    return numeros.isEmpty ? 'Sin datos registrados' : numeros.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Datos del adulto mayor'),
        centerTitle: true,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _datos == null
          ? _mensajeEstado(context, _error!)
          : _datos == null
          ? _mensajeEstado(context, 'No se encontró el perfil de este usuario.')
          : _contenido(context, _datos!),
    );
  }

  Widget _contenido(BuildContext context, Map<String, dynamic> datos) {
    final tipoAlerta = datos[_tipoAlertaCampo];
    final alertaSinReconocer = datos[_alertaReconocidaCampo] != true;
    final caidaSinReconocer = datos[_caidaReconocidaCampo] != true;
    final emergenciaActiva =
        datos[_emergenciaActivaCampo] == true ||
        (tipoAlerta == _alertaBoton && alertaSinReconocer) ||
        (tipoAlerta == _alertaCaida && alertaSinReconocer) ||
        (datos['seCayo'] == true && caidaSinReconocer);
    final alertaFinalizada =
        !emergenciaActiva &&
        (tipoAlerta == _alertaBoton || tipoAlerta == _alertaCaida) &&
        datos[_alertaReconocidaCampo] == true;
    final huboCaidaReconocida =
        datos[_caidaReconocidaCampo] == true && datos['seCayo'] == true;
    final tipoAlertaActiva = emergenciaActiva
        ? datos[_tipoAlertaEmergenciaCampo] == _alertaBoton ||
                  datos[_tipoAlertaEmergenciaCampo] == _alertaCaida
              ? datos[_tipoAlertaEmergenciaCampo]
              : tipoAlerta == _alertaBoton || tipoAlerta == _alertaCaida
              ? tipoAlerta
              : _alertaCaida
        : alertaSinReconocer &&
              (tipoAlerta == _alertaBoton || tipoAlerta == _alertaCaida)
        ? tipoAlerta
        : null;
    final botonPresionado = tipoAlertaActiva == _alertaBoton;
    final caidaDetectada = tipoAlertaActiva == _alertaCaida;
    final sinAlerta = tipoAlerta == _alertaNinguna;
    final enCasa = datos[_emergenciaActivaCampo] == true
        ? _valorEnCasa(datos[_ubicacionCongeladaCampo])
        : emergenciaActiva
        ? _enCasaPendiente
        : _valorEnCasa(datos['enCasa']);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (emergenciaActiva)
          FutureBuilder<bool>(
            future: _responsableAutorizado,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'No se pudo verificar el acceso del responsable: '
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                );
              }
              if (snapshot.data != true) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  height: 68,
                  child: FilledButton.icon(
                    onPressed: _finalizandoEmergencia
                        ? null
                        : _confirmarFinalizacion,
                    icon: _finalizandoEmergencia
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(
                      _finalizandoEmergencia
                          ? 'Finalizando...'
                          : 'FINALIZAR EMERGENCIA',
                    ),
                  ),
                ),
              );
            },
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: _indicadorEstado(
                titulo: botonPresionado
                    ? 'Alerta detectada'
                    : 'Estado de salud',
                valor: botonPresionado
                    ? 'Se apretó el botón'
                    : caidaDetectada
                    ? 'Caída detectada'
                    : alertaFinalizada
                    ? 'Emergencia finalizada'
                    : sinAlerta
                    ? 'No se detectó caída'
                    : huboCaidaReconocida
                    ? 'No se detectó caída'
                    : datos['seCayo'] is bool
                    ? (datos['seCayo'] as bool
                          ? 'Se cayó'
                          : 'No se detectó caída')
                    : 'Sin datos',
                icono: botonPresionado
                    ? Icons.touch_app
                    : caidaDetectada
                    ? Icons.warning_rounded
                    : Icons.health_and_safety,
                color: botonPresionado
                    ? Colors.amber
                    : caidaDetectada
                    ? Colors.red
                    : alertaFinalizada || sinAlerta
                    ? Colors.green
                    : datos['seCayo'] is! bool &&
                          datos[_emergenciaActivaCampo] != true
                    ? Colors.blueGrey
                    : Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _indicadorEstado(
                titulo: 'Ubicación',
                valor: enCasa == null
                    ? 'Sin datos'
                    : enCasa
                    ? 'En casa'
                    : 'Fuera de casa',
                icono: enCasa == true ? Icons.home : Icons.location_on,
                color: enCasa == null
                    ? Colors.blueGrey
                    : enCasa
                    ? Colors.green
                    : Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          _valorTexto(datos, 'nombreCompleto'),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Información guardada en el perfil del usuario',
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 20),
        _datoCard(
          icono: Icons.phone,
          titulo: 'Teléfonos de contacto',
          valor: _valorTelefonos(datos),
          color: const Color.fromARGB(255, 117, 173, 219),
        ),
        _datoCard(
          icono: Icons.medical_information,
          titulo: 'Perfil médico',
          valor: _valorTexto(datos, 'perfilMedico'),
          color: const Color.fromARGB(255, 134, 222, 137),
        ),
        _datoCard(
          icono: Icons.home,
          titulo: 'Domicilio',
          valor: _valorTexto(datos, 'direccion'),
          color: const Color.fromARGB(255, 214, 157, 87),
        ),
        _datoCard(
          icono: Icons.memory,
          titulo: 'Dirección MAC del cuidANDO',
          valor: _valorTexto(datos, 'direccionMac'),
          color: const Color.fromARGB(255, 248, 207, 83),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 55,
          child: OutlinedButton.icon(
            onPressed: () => context.go('/lista'),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Volver'),
          ),
        ),
      ],
    );
  }

  Widget _indicadorEstado({
    required String titulo,
    required String valor,
    required IconData icono,
    required Color color,
  }) {
    return AspectRatio(
      aspectRatio: 1,
      child: Card(
        color: color.withValues(alpha: 0.12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Icon(icono, size: 40, color: color),
              Text(
                valor,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _datoCard({
    required IconData icono,
    required String titulo,
    required String valor,
    required Color color,
  }) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: color,
          foregroundColor: Colors.black,
          child: Icon(icono),
        ),
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(valor),
        ),
        isThreeLine: valor.contains('\n'),
      ),
    );
  }

  Widget _mensajeEstado(BuildContext context, String mensaje) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(mensaje, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.go('/lista'),
              child: const Text('Volver'),
            ),
          ],
        ),
      ),
    );
  }
}
