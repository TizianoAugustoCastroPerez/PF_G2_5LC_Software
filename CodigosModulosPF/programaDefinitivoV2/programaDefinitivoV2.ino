#include <Wire.h>
#include <MPU6050.h>
#include <math.h>
#include <HardwareSerial.h>
#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include <addons/TokenHelper.h>

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

// Constantes de Caída e Impacto
#define CAIDA_LIBRE 0.4
#define IMPACTO 2
#define TIEMPO_VERIFICAR_IMPACTO 2000
#define ESPERA_PULSO 30
#define CONVERSION_A_VALOR_REAL 16384.0
#define DURACION_INTENTO_LLAMADA 25000
#define DURACION_LLAMADA_CONECTADA 5000
#define ESPERA_CONECTAR_LLAMADA 30000 
#define INTERVALO_REFRESCO_30S 30000

// Temporizador para actualización periódica cada 30 segundos
unsigned long tiempoUltimoRefresco30s = 0;

// Estados del Adulto / Ubicación / Datos del Usuario (Firestore)
bool estaCaido = false;
bool estaEnCasa = false;
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

      // Obtener nombreCompleto
      payload.get(jsonData, "fields/nombreCompleto/stringValue");
      if (jsonData.success) {
        nombreCompleto = jsonData.to<String>();
      }

      // Obtener perfilMedico
      payload.get(jsonData, "fields/perfilMedico/stringValue");
      if (jsonData.success) {
        perfilMedico = jsonData.to<String>();
      }

      // Obtener direccion
      payload.get(jsonData, "fields/direccion/stringValue");
      if (jsonData.success) {
        direccion = jsonData.to<String>();
      }

      // Obtener lista de teléfonos con sanitizado de prefijos
      cantidadTelefonos = 0;
      for (int i = 0; i < 3; i++) {
        String path = "fields/telefonos/arrayValue/values/[" + String(i) + "]/stringValue";
        payload.get(jsonData, path.c_str());
        if (jsonData.success) {
          String num = jsonData.to<String>();
          num.trim();
          if (!num.startsWith("+")) {
            if (num.startsWith("549")) {
              num = "+" + num;
            } else if (num.startsWith("9")) {
              num = "+54" + num;
            } else {
              num = "+549" + num;
            }
          }
          listaTelefonos[cantidadTelefonos] = num;
          Serial.print("Teléfono prioridad ");
          Serial.print(cantidadTelefonos);
          Serial.print(": ");
          Serial.println(num);
          cantidadTelefonos++;
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

void actualizarEstadoFirestore(bool caido, bool enCasa) {
  if (Firebase.ready()) {
    String userId = obtenerUserIdDesdeFirestore();
    if (userId == "") return;
    String documentPath = "usuarios/" + userId;
    FirebaseJson content;
    content.set("fields/seCayo/booleanValue", caido);
    content.set("fields/enCasa/booleanValue", enCasa);
    Serial.print("Actualizando Firestore -> seCayo: ");
    Serial.print(caido ? "true" : "false");
    Serial.print(" | enCasa: ");
    Serial.println(enCasa ? "true" : "false");
    if (Firebase.Firestore.patchDocument(&fbdo, FIREBASE_PROJECT_ID, "", documentPath.c_str(), content.raw(), "seCayo,enCasa")) {
      Serial.println("Estado enviado a Firestore con éxito.");
    } else {
      Serial.print("Error al parchear documento en Firestore: ");
      Serial.println(fbdo.errorReason());
    }
  }
}

void actualizarCada30s() {
  Serial.println("\n--- [30s] Refrescando dirección MAC, datos de usuario, teléfonos y estado en Firestore ---");
  String macActual = obtenerMacLimpia();
  Serial.print("Dirección MAC: ");
  Serial.println(macActual);
  estaEnCasa = verificarSiEstaEnCasa();
  Serial.print("Ubicación actual: ");
  Serial.println(estaEnCasa ? "EN CASA" : "DESCONOCIDA");
  obtenerDatosUsuarioFirestore();
  actualizarEstadoFirestore(estaCaido, estaEnCasa);
}

// FUNCIONES SIM800L
String enviarComando(String comando, unsigned long tiempoEspera = 2000) {
  while (sim800.available()) sim800.read();
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
  String msj = "ALERTA DE CAIDA DETECTADA!\n";
  msj += "Paciente: " + (nombreCompleto.length() > 0 ? nombreCompleto : "No especificado") + "\n";
  msj += "Perfil Medico: " + (perfilMedico.length() > 0 ? perfilMedico : "No especificado") + "\n";
  msj += "Direccion: " + (direccion.length() > 0 ? direccion : "No especificada") + "\n";
  msj += "Ubicacion: " + String(estaEnCasa ? "En CASA" : "FUERA de casa");
  return msj;
}

void enviarSMS(String numDestino, String textoMensaje) {
  Serial.print("Enviando SMS a: ");
  Serial.println(numDestino);
  unsigned long esperaLocal = millis();
  int casos = 1;
  bool ejecutarUnaVez = true;
  bool ejecutarFuncion = true;
  const int tiempoCaso1 = 300;   
  const int tiempoCaso2 = 600;  
  const int tiempoCaso3 = 1000;  
  const int tiempoCaso4 = 5000;

  while (ejecutarFuncion) {
    if (casos == 1) {
      if (ejecutarUnaVez) {
        sim800.println("AT+CMGF=1");
        ejecutarUnaVez = false;
      }
      if (millis() - esperaLocal >= tiempoCaso1) {
        casos = 2;
        ejecutarUnaVez = true;
        esperaLocal = millis(); 
      }
    }
    else if (casos == 2) {
      if (ejecutarUnaVez) {
        sim800.print("AT+CMGS=\"");
        sim800.print(numDestino);
        sim800.println("\"");
        ejecutarUnaVez = false;
      }
      if (millis() - esperaLocal >= tiempoCaso2) {
        casos = 3;
        ejecutarUnaVez = true;
        esperaLocal = millis();
      }
    }
    else if (casos == 3) {
      if (ejecutarUnaVez) {
        sim800.print(textoMensaje);
        ejecutarUnaVez = false;
      }
      if (millis() - esperaLocal >= tiempoCaso3) {
        casos = 4;
        ejecutarUnaVez = true;
        esperaLocal = millis();
      }
    }  
    else if (casos == 4) {
      if (ejecutarUnaVez) {
        sim800.write(26); // Enviar CTRL+Z
        ejecutarUnaVez = false;
      }
      if (millis() - esperaLocal >= tiempoCaso4) {
        ejecutarFuncion = false; 
      }
    }  
  }
}

bool realizarLlamadaVerificada(String numDestino) {
  Serial.print("\nIniciando llamada a: ");
  Serial.println(numDestino);

  // Guard Time: Libera el canal GSM de llamadas o SMS anteriores
  enviarComando("ATH", 1000);
  delay(2000); 

  // Verificar que el módem responda OK antes de enviar ATD
  String testAT = enviarComando("AT", 1000);
  if (testAT.indexOf("OK") == -1) {
    Serial.println("--> Módem ocupado o sin respuesta. Forzando colgado...");
    enviarComando("ATH", 1000);
    delay(1000);
  }

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
    
    if (respuestaAcumulada.indexOf("+COLP:") != -1) {
      Serial.println("\n--> ¡Llamada ATENDIDA! (Detectado por +COLP)");
      atendio = true;
      break;
    }
    if (respuestaAcumulada.indexOf("BUSY") != -1 || 
        respuestaAcumulada.indexOf("NO ANSWER") != -1 || 
        respuestaAcumulada.indexOf("NO DIALTONE") != -1 ||
        respuestaAcumulada.indexOf("ERROR") != -1) {
      Serial.println("\n--> Llamada rechazada, ocupada o no contestada.");
      atendio = false;
      break;
    }
    if (respuestaAcumulada.indexOf("NO CARRIER") != -1) {
      if (atendio) {
        Serial.println("\n--> El contacto atendió y luego colgó la llamada.");
      } else {
        Serial.println("\n--> El contacto cortó / rechazó la llamada antes de atender.");
      }
      break; 
    }
    
    if (!atendio && (millis() - ultimoCLCC >= 1500)) {
      ultimoCLCC = millis();
      if (respuestaAcumulada.length() > 300) {
        respuestaAcumulada = ""; 
      }
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
      int idxCLCC = respCLCC.indexOf("+CLCC:");
      if (idxCLCC != -1) {
        String sub = respCLCC.substring(idxCLCC);
        int primeraComa = sub.indexOf(',');
        int segundaComa = sub.indexOf(',', primeraComa + 1);
        int terceraComa = sub.indexOf(',', segundaComa + 1);
        if (primeraComa != -1 && segundaComa != -1 && terceraComa != -1) {
          String estadoStr = sub.substring(segundaComa + 1, terceraComa);
          estadoStr.trim();
          int estadoLlamada = estadoStr.toInt();
          if (estadoLlamada == 0) { // 0 = Llamada activa
            Serial.println("\n--> ¡Llamada ATENDIDA! (Detectado por AT+CLCC)");
            atendio = true;
            break;
          }
        }
      }
    }
  }

  if (atendio) {
    Serial.println("Llamada en curso. Comunicando...");
    unsigned long inicioHablada = millis();
    while (millis() - inicioHablada < DURACION_LLAMADA_CONECTADA) {
      while (sim800.available()) {
        char c = sim800.read();
        Serial.write(c);
      }
      delay(50);
    }
  }
  
  enviarComando("ATH", 1000);
  delay(2000); // Pausa de estabilización tras colgar
  return atendio;
}

// SETUP Y LOOP PRINCIPAL

void setup() {
  Serial.begin(115200);
  pinMode(PIN_BOTON, INPUT_PULLUP);
  
  // 1. Inicialización MPU6050
  Wire.begin();
  mpu.initialize();
  while (!mpu.testConnection()) {
    Serial.println("Esperando MPU6050...");
    delay(500);
  }

  // 2. Inicialización SIM800L
  sim800.begin(9600, SERIAL_8N1, RXD2, TXD2);
  delay(3000);
  enviarComando("AT");
  enviarComando("AT+CPIN?"); 
  enviarComando("AT+CSQ");   

  Serial.println("Esperando registro en la red celular...");
  unsigned long inicioReg = millis();
  while (!estaRegistradoEnRed() && (millis() - inicioReg < 30000)) {
    delay(1000);
    Serial.print(".");
  }
  
  if (estaRegistradoEnRed()) {
    Serial.println("\n¡SIM800L registrado en la red celular exitosamente!");
  } else {
    Serial.println("\nADVERTENCIA: No se pudo registrar en la red celular en el arranque.");
  }

  // 3. Conexión Wi-Fi
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Conectando a Wi-Fi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(250);
    Serial.print(".");
  }
  Serial.println("\nWi-Fi Conectado.");

  bssidCasa = WiFi.BSSIDstr();
  Serial.print("BSSID de router de casa registrado: ");
  Serial.println(bssidCasa);

  // 4. Configuración Firebase
  config.api_key = API_KEY;
  auth.user.email = "tizianoacp08@gmail.com";
  auth.user.password = "Tiziano2008";
  config.token_status_callback = tokenStatusCallback;
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  // 5. Carga inicial de datos desde Firestore
  actualizarCada30s();

  Serial.println("Sistema listo.");
}

void loop() {
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
            actualizarEstadoFirestore(estaCaido, estaEnCasa);
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
        actualizarEstadoFirestore(estaCaido, estaEnCasa);
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
          Serial.print("\n=== INTENTO ");
          Serial.print(i + 1);
          Serial.print(" - CONTACTO: ");
          Serial.print(numActual);
          Serial.println(" ===");
          
          // 1. Enviar el SMS con todos los datos
          enviarSMS(numActual, mensajeCompletoSMS);
          
          // 2. Pausa crucial para permitir que el SIM800L termine de enviar los paquetes de datos del SMS a la celda
          delay(3000); 

          // 3. Marcar por llamada
          bool contestado = realizarLlamadaVerificada(numActual);
          if (contestado) {
            alguienAtendio = true;
            Serial.println("Emergencia atendida por un contacto. Finalizando secuencia.");
            break;
          }
          delay(2000); 
        }

        if (!alguienAtendio && cantidadTelefonos > 0) {
          Serial.println("NINGÚN CONTACTO ATENDIÓ. LLAMANDO AL 911...");
          realizarLlamadaVerificada("911");
        }

        estaCaido = false;
        actualizarEstadoFirestore(estaCaido, estaEnCasa);
        estadoActual = esperaCaida;
      } else {
        Serial.println("Sin registro en red...");
        if (millis() - tiempoConectarLlamada >= ESPERA_CONECTAR_LLAMADA) { 
          Serial.println("No se pudo realizar la conexión a tiempo.");
          estaCaido = false;
          actualizarEstadoFirestore(estaCaido, estaEnCasa);
          estadoActual = esperaCaida;
        }
      }
      break;
    }
  }

  if (estadoActual == esperaCaida && (millis() - tiempoUltimoRefresco30s >= INTERVALO_REFRESCO_30S)) {
    tiempoUltimoRefresco30s = millis();
    actualizarCada30s();
  }
}
