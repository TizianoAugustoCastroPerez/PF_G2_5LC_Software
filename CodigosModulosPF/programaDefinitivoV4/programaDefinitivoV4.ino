#include <Wire.h>
#include <MPU6050.h>
#include <math.h>
#include <HardwareSerial.h>
#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include <addons/TokenHelper.h>
#include <Adafruit_NeoPixel.h>

// Datos Wi-Fi
#define WIFI_SSID "MOVISTAR WIFI2114"
#define WIFI_PASSWORD "gnub6271"

// Red de Casa para detección de presencia
const char* SSID_CASA = WIFI_SSID;
String bssidCasa = "";

// Datos de Firebase
#define API_KEY "AIzaSyBXhosDmHuymixnz3hlY0QEeM4dXKZSsoI"
#define FIREBASE_PROJECT_ID "pf-g2-cuidando"

// Objetos de Firebase
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

// Definiciones de Hardware
HardwareSerial sim800(2);
#define RXD2 16
#define TXD2 17
#define PIN_BOTON 19

// Definiciones Anillo de LEDs NeoPixel
#define PIN_DATOS_LED 27
#define NUM_LEDS 16
Adafruit_NeoPixel tira(NUM_LEDS, PIN_DATOS_LED, NEO_GRB + NEO_KHZ800);

// Constantes de Caída e Impacto
#define CAIDA_LIBRE 0.4
#define IMPACTO 2
#define TIEMPO_VERIFICAR_IMPACTO 2000
#define ESPERA_PULSO 30
#define CONVERSION_A_VALOR_REAL 16384.0
#define DURACION_INTENTO_LLAMADA 25000
#define DURACION_LLAMADA_CONECTADA 5000
#define ESPERA_CONECTAR_LLAMADA 30000 
#define INTERVALO_REFRESCO_90S 90000

// Temporizador para actualización periódica cada 90 segundos
unsigned long tiempoUltimoRefresco90s = 0;

// Estados del Adulto / Ubicación / Datos del Usuario (Firestore)
bool estaCaido = false;
bool estaEnCasa = false;
String tipoAlerta = "NINGUNO"; // Puede ser "NINGUNO", "BOTON" o "CAIDA"
String nombreCompleto = "";
String perfilMedico = "";
String direccion = "";

// Lista para guardar hasta 3 teléfonos
String listaTelefonos[3];
int cantidadTelefonos = 0;

// Variables MPU6050
MPU6050 mpu;
int16_t ax, ay, az;
bool posibleCaida = false;
unsigned long tiempoCaida = 0;
unsigned long espera = 20;

// Variables Botón de Emergencia (Antirrebote no bloqueante)
unsigned long tiempoBoton = 0;
bool posibleBoton = false;

// Máquina de Estados
typedef enum {
  esperaCaida,
  confirmarCaida,
  llamada
} EstadoSistema;
EstadoSistema estadoActual = esperaCaida;
unsigned long tiempoConectarLlamada = 0;

// FUNCIÓN CONTROL LEDS (No bloqueante)
void mantenerLedsEncendidos() {
  tira.fill(tira.Color(255, 255, 255));
  tira.show();
}

// FUNCIONES WI-FI Y UBICACIÓN
bool verificarSiEstaEnCasa() {
  int cantidadEncontradas = WiFi.scanNetworks();
  bool encontrada = false;
  for (int i = 0; i < cantidadEncontradas; i++) {
    String bssidActual = WiFi.BSSIDstr(i);
    if ((bssidCasa.length() > 0 && bssidActual.equalsIgnoreCase(bssidCasa)) || 
        (WiFi.SSID(i) == SSID_CASA)) {
      encontrada = true;
      break;
    }
  }
  WiFi.scanDelete();
  return encontrada;
}

// FUNCIONES FIREBASE
String obtenerMacLimpia() {
  String mac = WiFi.macAddress();
  mac.replace(":", "");
  mac.toUpperCase();
  return mac;
}

String obtenerUserIdDesdeFirestore() {
  String idUsuarioEncontrado = "";
  if (Firebase.ready()) {
    String mac = obtenerMacLimpia(); 
    Serial.print("Buscando usuario con MAC: ");
    Serial.println(mac);
    FirebaseJson json;
    json.set("from/[0]/collectionId", "usuarios");
    json.set("where/fieldFilter/field/fieldPath", "direccionMac");
    json.set("where/fieldFilter/op", "EQUAL");
    json.set("where/fieldFilter/value/stringValue", mac);
    if (Firebase.Firestore.runQuery(&fbdo, FIREBASE_PROJECT_ID, "", "", &json)) {
      FirebaseJson payload;
      payload.setJsonData(fbdo.payload().c_str());
      FirebaseJsonData jsonData;
      payload.get(jsonData, "[0]/document/name");
      if (jsonData.success) {
        String docPath = jsonData.to<String>();
        int lastSlash = docPath.lastIndexOf('/');
        if (lastSlash != -1) {
          idUsuarioEncontrado = docPath.substring(lastSlash + 1);
          Serial.print("Usuario encontrado: ");
          Serial.println(idUsuarioEncontrado);
        }
      } else {
        Serial.println("No se encontró ningún usuario vinculado a esta MAC.");
      }
    } else {
      Serial.print("Error al ejecutar query en Firestore: ");
      Serial.println(fbdo.errorReason());
    }
  }
  return idUsuarioEncontrado;
}

void obtenerDatosUsuarioFirestore() {
  if (Firebase.ready()) {
    String userId = obtenerUserIdDesdeFirestore();
    if (userId == "") return;
    Serial.println("Consultando Firestore para obtener datos de usuario y teléfonos...");
    String documentPath = "usuarios/" + userId;
    if (Firebase.Firestore.getDocument(&fbdo, FIREBASE_PROJECT_ID, "", documentPath.c_str(), "")) {
      FirebaseJson payload;
      payload.setJsonData(fbdo.payload().c_str());
      FirebaseJsonData jsonData;

      payload.get(jsonData, "fields/nombreCompleto/stringValue");
      if (jsonData.success) nombreCompleto = jsonData.to<String>();

      payload.get(jsonData, "fields/perfilMedico/stringValue");
      if (jsonData.success) perfilMedico = jsonData.to<String>();

      payload.get(jsonData, "fields/direccion/stringValue");
      if (jsonData.success) direccion = jsonData.to<String>();

      cantidadTelefonos = 0;
      for (int i = 0; i < 3; i++) {
        String path = "fields/telefonos/arrayValue/values/[" + String(i) + "]/stringValue";
        payload.get(jsonData, path.c_str());
        if (jsonData.success) {
          String num = jsonData.to<String>();
          num.trim();
          if (num.length() > 0) { // Toma solo teléfonos válidos/existentes
            if (!num.startsWith("+")) {
              if (num.startsWith("549")) num = "+" + num;
              else if (num.startsWith("9")) num = "+54" + num;
              else num = "+549" + num;
            }
            listaTelefonos[cantidadTelefonos] = num;
            Serial.print("Teléfono prioridad ");
            Serial.print(cantidadTelefonos);
            Serial.print(": ");
            Serial.println(num);
            cantidadTelefonos++;
          }
        } else {
          break;
        }
      }
      Serial.print("Total de teléfonos registrados: ");
      Serial.println(cantidadTelefonos);
    } else {
      Serial.print("Error al leer documento en Firestore: ");
      Serial.println(fbdo.errorReason());
    }
  }
}

void actualizarEstadoFirestore(bool caido, bool enCasa, String origen) {
  if (Firebase.ready()) {
    String userId = obtenerUserIdDesdeFirestore();
    if (userId == "") return;
    String documentPath = "usuarios/" + userId;
    FirebaseJson content;
    content.set("fields/seCayo/booleanValue", caido);
    content.set("fields/enCasa/booleanValue", enCasa);
    content.set("fields/tipoAlerta/stringValue", origen);
    
    if (Firebase.Firestore.patchDocument(&fbdo, FIREBASE_PROJECT_ID, "", documentPath.c_str(), content.raw(), "seCayo,enCasa,tipoAlerta")) {
      Serial.println("Estado enviado a Firestore con éxito.");
    }
  }
}

void actualizarCada90s() {
  Serial.println("\n--- Refrescando datos en Firestore (Cada 90s) ---");
  estaEnCasa = verificarSiEstaEnCasa();
  obtenerDatosUsuarioFirestore();
  actualizarEstadoFirestore(estaCaido, estaEnCasa, tipoAlerta);
}

// FUNCIONES SIM800L
void limpiarBufferSerial() {
  while (sim800.available()) sim800.read();
}

String enviarComando(String comando, unsigned long tiempoEspera = 2000) {
  limpiarBufferSerial();
  Serial.print("Enviando: ");
  Serial.println(comando);
  sim800.println(comando);
  unsigned long inicio = millis();
  String respuesta = "";
  while (millis() - inicio < tiempoEspera) {
    while (sim800.available()) {
      char c = sim800.read();
      respuesta += c;
      Serial.write(c);
    }
  }
  return respuesta;
}

bool estaRegistradoEnRed() {
  String resp = enviarComando("AT+CREG?", 2000);
  return (resp.indexOf("+CREG: 0,1") != -1 || resp.indexOf("+CREG: 0,5") != -1);
}

String construirMensajeSMS() {
  String msj = "ALERTA CAIDA! Paciente: ";
  msj += (nombreCompleto.length() > 0 ? nombreCompleto : "Sin nombre");
  msj += " | Perfil: " + (perfilMedico.length() > 0 ? perfilMedico : "N/A");
  msj += " | Dir: " + (direccion.length() > 0 ? direccion : "N/A");
  msj += " | Ubicacion: " + String(estaEnCasa ? "En CASA" : "FUERA de casa");
  return msj;
}

// ENVÍO DE SMS ADAPTADO A REDES ARGENTINAS
bool enviarSMS(String numDestino, String textoMensaje) {
  String numSms = numDestino;
  if (numSms.startsWith("+549")) {
    numSms = "+54" + numSms.substring(4);
  }

  Serial.print("\n--- [SMS] Número para llamada: ");
  Serial.println(numDestino);
  Serial.print("--- [SMS] Número adaptado para SMS: ");
  Serial.println(numSms);

  limpiarBufferSerial();
  
  enviarComando("AT+CMEE=2", 1000);
  enviarComando("AT+CSCS=\"GSM\"", 1000);
  enviarComando("AT+CMGF=1", 1000);
  enviarComando("AT+CSCA?", 1000);

  limpiarBufferSerial();
  sim800.print("AT+CMGS=\"");
  sim800.print(numSms);
  sim800.println("\"");

  unsigned long inicio = millis();
  bool promptRecibido = false;
  while (millis() - inicio < 5000) {
    if (sim800.available()) {
      char c = sim800.read();
      Serial.write(c);
      if (c == '>') {
        promptRecibido = true;
        break;
      }
    }
  }

  if (!promptRecibido) {
    Serial.println("\n[ERROR SMS] Sin respuesta del prompt '>'. Cancelando.");
    sim800.write(27);
    delay(1000);
    return false;
  }

  sim800.print(textoMensaje);
  delay(500);
  sim800.write(26);

  inicio = millis();
  String respuesta = "";
  bool enviado = false;
  while (millis() - inicio < 15000) {
    while (sim800.available()) {
      char c = sim800.read();
      respuesta += c;
      Serial.write(c);
    }
    if (respuesta.indexOf("+CMGS:") != -1 && respuesta.indexOf("OK") != -1) {
      enviado = true;
      break;
    }
    if (respuesta.indexOf("ERROR") != -1 || respuesta.indexOf("+CMS ERROR") != -1) {
      enviado = false;
      break;
    }
  }

  if (enviado) {
    Serial.println("\n[ÉXITO SMS] SMS enviado correctamente.");
  } else {
    Serial.println("\n[FALLO SMS] SMS rechazado por la red.");
  }

  delay(2000);
  return enviado;
}

bool realizarLlamadaVerificada(String numDestino) {
  Serial.print("\nIniciando llamada a: ");
  Serial.println(numDestino);

  limpiarBufferSerial();
  enviarComando("ATH", 1000);
  delay(1000); 

  String testAT = enviarComando("AT", 1000);
  if (testAT.indexOf("OK") == -1) {
    Serial.println("--> Módem no responde. Forzando colgado...");
    enviarComando("ATH", 1000);
    delay(1000);
  }

  limpiarBufferSerial();
  sim800.println("ATD" + numDestino + ";");
  
  unsigned long inicio = millis();
  unsigned long ultimoCLCC = millis();
  bool atendio = false;
  String respuestaAcumulada = "";

  while (millis() - inicio <= DURACION_INTENTO_LLAMADA) {
    while (sim800.available()) {
      char c = sim800.read();
      respuestaAcumulada += c;
      Serial.write(c);
    }
    
    // 1. Si la llamada es rechazada, colgada, ocupada o falla la red:
    // Se toma como NO ATENDIDA (atendio = false) y se cancela el intento.
    if (respuestaAcumulada.indexOf("BUSY") != -1 || 
        respuestaAcumulada.indexOf("NO CARRIER") != -1 || 
        respuestaAcumulada.indexOf("NO ANSWER") != -1 || 
        respuestaAcumulada.indexOf("NO DIALTONE") != -1 ||
        respuestaAcumulada.indexOf("ERROR") != -1) {
      Serial.println("\n--> Llamada rechazada, colgada u ocupada. Se toma como NO ATENDIDA.");
      atendio = false;
      break;
    }

    // 2. Si la llamada es efectivamente contestada
    if (respuestaAcumulada.indexOf("+COLP:") != -1) {
      Serial.println("\n--> ¡Llamada ATENDIDA! (Detectado por +COLP)");
      atendio = true;
      break;
    }
    
    // Consulta periódica del estado de la llamada vía AT+CLCC
    if (millis() - ultimoCLCC >= 1500) {
      ultimoCLCC = millis();
      if (respuestaAcumulada.length() > 300) respuestaAcumulada = ""; 
      
      sim800.println("AT+CLCC");
      unsigned long tCLCC = millis();
      String respCLCC = "";
      while (millis() - tCLCC < 300) {
        while (sim800.available()) {
          char c = sim800.read();
          respCLCC += c;
          respuestaAcumulada += c;
          Serial.write(c);
        }
      }

      // Si durante la consulta CLCC se detecta colgado/rechazo
      if (respCLCC.indexOf("BUSY") != -1 || respCLCC.indexOf("NO CARRIER") != -1) {
        Serial.println("\n--> Rechazo/colgado detectado por CLCC. Se toma como NO ATENDIDA.");
        atendio = false;
        break;
      }

      int idxCLCC = respCLCC.indexOf("+CLCC:");
      if (idxCLCC != -1) {
        String sub = respCLCC.substring(idxCLCC);
        int primeraComa = sub.indexOf(',');
        int segundaComa = sub.indexOf(',', primeraComa + 1);
        int terceraComa = sub.indexOf(',', segundaComa + 1);
        if (primeraComa != -1 && segundaComa != -1 && terceraComa != -1) {
          String estadoStr = sub.substring(segundaComa + 1, terceraComa);
          estadoStr.trim();
          if (estadoStr.toInt() == 0) { // Estado 0: Llamada activa/atendida
            Serial.println("\n--> ¡Llamada ATENDIDA! (Detectado por AT+CLCC)");
            atendio = true;
            break;
          }
        }
      }
    }
  }

  if (atendio) {
    Serial.println("Llamada en curso...");
    unsigned long inicioHablada = millis();
    while (millis() - inicioHablada < DURACION_LLAMADA_CONECTADA) {
      while (sim800.available()) Serial.write(sim800.read());
      delay(50);
    }
  }
  
  enviarComando("ATH", 1000);
  delay(2000);
  return atendio;
}

// SETUP Y LOOP

void setup() {
  Serial.begin(115200);
  pinMode(PIN_BOTON, INPUT_PULLUP);
  
  // Inicialización Anillo NeoPixel
  tira.begin();
  tira.setBrightness(255);
  mantenerLedsEncendidos();
  
  Wire.begin();
  mpu.initialize();
  while (!mpu.testConnection()) {
    Serial.println("Esperando MPU6050...");
    delay(500);
  }

  sim800.begin(9600, SERIAL_8N1, RXD2, TXD2);
  Serial.println("Iniciando SIM800L...");
  delay(3000);

  enviarComando("AT");
  enviarComando("AT+CSQ");

  Serial.println("Esperando registro en la red celular...");
  while (!estaRegistradoEnRed()) {
    Serial.println("-> Sin registro en red aun. Reintentando en 3s...");
    delay(3000);
  }
  Serial.println(">>> ¡REGISTRADO CORRECTAMENTE EN LA RED! <<<");

  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Conectando a Wi-Fi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(250);
    Serial.print(".");
  }
  Serial.println("\nWi-Fi Conectado.");

  bssidCasa = WiFi.BSSIDstr();

  config.api_key = API_KEY;
  auth.user.email = "tizianoacp08@gmail.com";
  auth.user.password = "Tiziano2008";
  config.token_status_callback = tokenStatusCallback;
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  actualizarCada90s();
  Serial.println("Sistema listo.");
}

void loop() {
  // Mantener actualizado el estado de los LEDs en el loop
  mantenerLedsEncendidos();

  switch (estadoActual) {
    case esperaCaida: {
      if (posibleBoton == false) {
        if (digitalRead(PIN_BOTON) == LOW) {
          posibleBoton = true;
          tiempoBoton = millis();
        }
      } else {
        if (digitalRead(PIN_BOTON) == LOW) {
          if (millis() - tiempoBoton >= ESPERA_PULSO) {
            Serial.println("¡Botón de emergencia presionado! Iniciando secuencia...");
            posibleBoton = false;
            estaCaido = true;
            tipoAlerta = "BOTON";
            actualizarEstadoFirestore(estaCaido, estaEnCasa, tipoAlerta);
            tiempoConectarLlamada = millis();
            estadoActual = llamada;
            break;
          }
        } else {
          posibleBoton = false;
        }
      }
      
      mpu.getAcceleration(&ax, &ay, &az);
      float Ax = ax / CONVERSION_A_VALOR_REAL;
      float Ay = ay / CONVERSION_A_VALOR_REAL;
      float Az = az / CONVERSION_A_VALOR_REAL;
      float fuerzaCaida = sqrt(Ax * Ax + Ay * Ay + Az * Az);
      
      if (fuerzaCaida < CAIDA_LIBRE && !posibleCaida) {
        Serial.println("Posible caída, a confirmar");
        posibleCaida = true;
        tiempoCaida = millis();
        estadoActual = confirmarCaida;
      }
      break;
    }

    case confirmarCaida: {
      mpu.getAcceleration(&ax, &ay, &az);
      float Ax = ax / CONVERSION_A_VALOR_REAL;
      float Ay = ay / CONVERSION_A_VALOR_REAL;
      float Az = az / CONVERSION_A_VALOR_REAL;
      float fuerzaImpacto = sqrt(Ax * Ax + Ay * Ay + Az * Az);
      
      if (posibleCaida && (millis() - tiempoCaida <= TIEMPO_VERIFICAR_IMPACTO) && fuerzaImpacto > IMPACTO) {
        Serial.println("Caída confirmada");
        posibleCaida = false;
        estaCaido = true;
        tipoAlerta = "CAIDA";
        actualizarEstadoFirestore(estaCaido, estaEnCasa, tipoAlerta);
        tiempoConectarLlamada = millis();
        estadoActual = llamada;
      }
      
      if (posibleCaida && (millis() - tiempoCaida > TIEMPO_VERIFICAR_IMPACTO)) {
        Serial.println("No se cayó nadie, esperando a detectar otra caída");
        posibleCaida = false;
        espera = millis();
        estadoActual = esperaCaida;
      }
      break;
    }

    case llamada: {
      Serial.println("Verificando red móvil...");
      if (estaRegistradoEnRed()) {
        bool alguienAtendio = false;
        String mensajeCompletoSMS = construirMensajeSMS();

        for (int i = 0; i < cantidadTelefonos; i++) {
          String numActual = listaTelefonos[i];
          Serial.print("\n==========================================");
          Serial.print("\n INTENTO ");
          Serial.print(i + 1);
          Serial.print(" DE ");
          Serial.print(cantidadTelefonos);
          Serial.print(" - CONTACTO: ");
          Serial.println(numActual);
          Serial.println("==========================================");
          
          enviarSMS(numActual, mensajeCompletoSMS);
          
          bool contestado = realizarLlamadaVerificada(numActual);
          if (contestado) {
            alguienAtendio = true;
            Serial.println("Emergencia atendida por un contacto. Finalizando secuencia.");
            break;
          }
          
          Serial.println("Contacto no atendió o rechazó. Pasando al siguiente número...");
          delay(2000); 
        }

        if (!alguienAtendio && cantidadTelefonos > 0) {
          Serial.println("\nNINGÚN CONTACTO ATENDIÓ. LLAMANDO AL 911...");
          realizarLlamadaVerificada("911");
        }

        estaCaido = false;
        tipoAlerta = "NINGUNO";
        actualizarEstadoFirestore(estaCaido, estaEnCasa, tipoAlerta);
        estadoActual = esperaCaida;
      } else {
        Serial.println("Sin registro en red...");
        if (millis() - tiempoConectarLlamada >= ESPERA_CONECTAR_LLAMADA) { 
          Serial.println("No se pudo realizar la conexión a tiempo.");
          estaCaido = false;
          tipoAlerta = "NINGUNO";
          actualizarEstadoFirestore(estaCaido, estaEnCasa, tipoAlerta);
          estadoActual = esperaCaida;
        }
      }
      break;
    }
  }

  if (estadoActual == esperaCaida && (millis() - tiempoUltimoRefresco90s >= INTERVALO_REFRESCO_90S)) {
    tiempoUltimoRefresco90s = millis();
    actualizarCada90s();
  }
}