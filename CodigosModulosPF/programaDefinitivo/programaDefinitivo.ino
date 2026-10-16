#include <Wire.h>
#include <MPU6050.h>
#include <math.h>
#include <HardwareSerial.h>
#include <Adafruit_NeoPixel.h>
#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include <addons/TokenHelper.h>

// datos Wi-Fi (a futuro obtenerlos)
#define WIFI_SSID "TU_RED_WIFI"
#define WIFI_PASSWORD "TU_CONTRASEÑA_WIFI"

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
#define PIN_LED 18
#define PIN_BOTON 19
#define PIN_DATOS_ANILLO 13  
#define NUM_LEDS 16

// Constantes de Caída e Impacto
#define CAIDA_LIBRE 0.4
#define IMPACTO 2
#define TIEMPO_VERIFICAR_IMPACTO 2000
#define ESPERA_PULSO 30
#define CONVERSION_A_VALOR_REAL 16384.0
#define DURACION_INTENTO_LLAMADA 25000
#define DURACION_LLAMADA_CONECTADA 5000
#define ESPERA_CONECTAR_LLAMADA 10000

// Lista para guardar hasta 3 teléfonos
String listaTelefonos[3];
int cantidadTelefonos = 0;

// Variables MPU6050
MPU6050 mpu;
int16_t ax, ay, az;
bool posibleCaida = false;
unsigned long tiempoCaida = 0;
unsigned long espera = 20;

// Variables NeoPixel
Adafruit_NeoPixel tira(NUM_LEDS, PIN_DATOS_ANILLO, NEO_GRB + NEO_KHZ800);

// Máquina de Estados
typedef enum {
  esperaCaida,
  confirmarCaida,
  llamada
} EstadoSistema;

EstadoSistema estadoActual = esperaCaida;
unsigned long tiempoConectarLlamada = 0;

// Funciones Firebase
String obtenerMacLimpia() {
  String mac = WiFi.macAddress();
  mac.replace(":", "");
  return mac;
}
String obtenerUserIdDesdeFirestore() {
  String idUsuarioEncontrado = "";
  if (Firebase.ready()) {
    String mac = obtenerMacLimpia();
    String documentPath = "dispositivos/" + mac;
    Serial.print("Consultando dispositivo con MAC: ");
    Serial.println(mac);
    if (Firebase.Firestore.getDocument(&fbdo, FIREBASE_PROJECT_ID, "", documentPath.c_str(), "")) {
      FirebaseJson payload;
      payload.setJsonData(fbdo.payload().c_str());
      FirebaseJsonData jsonData;
      payload.get(jsonData, "fields/userId/stringValue");
      if (jsonData.success) {
        idUsuarioEncontrado = jsonData.to<String>();
        Serial.print("Dispositivo vinculado al usuario: ");
        Serial.println(idUsuarioEncontrado);
      }
    } else {
      Serial.println("Este dispositivo aún no está vinculado a ningún usuario.");
    }
  }
  return idUsuarioEncontrado;
}
void obtenerTelefonosFirestore() {
  if (Firebase.ready()) {
    String userId = obtenerUserIdDesdeFirestore();
    if (userId == "") return;
    Serial.println("Consultando Firestore para obtener los teléfonos de emergencia...");
    String documentPath = "usuarios/";
    documentPath += userId;
    if (Firebase.Firestore.getDocument(&fbdo, FIREBASE_PROJECT_ID, "", documentPath.c_str(), "")) {
      FirebaseJson payload;
      payload.setJsonData(fbdo.payload().c_str());
      cantidadTelefonos = 0;
      for (int i = 0; i < 3; i++) {
        FirebaseJsonData jsonData;
        String path = "fields/telefonos/arrayValue/values/[" + String(i) + "]/stringValue";
        payload.get(jsonData, path.c_str());
        if (jsonData.success) {
          String num = jsonData.to<String>();
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

// Funciones SIM800L
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

void enviarSMS(String numDestino) {
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
        sim800.print("ALERTA: Se ha detectado una caida de emergencia.");
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
        sim800.write(26); 
        ejecutarUnaVez = false;
      }
      if (millis() - esperaLocal >= tiempoCaso4) {
        ejecutarFuncion = false; 
      }
    }  
  }
}

bool realizarLlamadaVerificada(String numDestino) {
  Serial.print("Llamando a: ");
  Serial.println(numDestino);
  sim800.println("AT+COLP=1");
  delay(200);
  sim800.println("ATD" + numDestino + ";");
  unsigned long inicio = millis();
  bool atendio = false;
  while (millis() - inicio < DURACION_INTENTO_LLAMADA) {
    if (sim800.available()) {
      String respuesta = sim800.readString();
      Serial.print(respuesta);
      if (respuesta.indexOf("+COLP:") != -1) {
        Serial.println("\n--> ¡Llamada ATENDIDA!");
        atendio = true;
        break;
      }
      if (respuesta.indexOf("BUSY") != -1 || 
          respuesta.indexOf("NO CARRIER") != -1 || 
          respuesta.indexOf("NO ANSWER") != -1) {
        Serial.println("\n--> Llamada rechazada o no contestada.");
        break;
      }
    }
  }
  if (atendio) {
    delay(DURACION_LLAMADA_CONECTADA);
  }
  enviarComando("ATH", 1000);
  return atendio;
}


void setup() {
  Serial.begin(115200);
  pinMode(PIN_LED, OUTPUT);
  pinMode(PIN_BOTON, INPUT_PULLUP);
  
  // Inicialización MPU6050
  Wire.begin();
  mpu.initialize();
  while (!mpu.testConnection()) {}

  // Inicialización NeoPixel
  tira.begin();      
  tira.setBrightness(255);
  tira.fill(tira.Color(255, 255, 255));
  tira.show();

  // Conexión Wi-Fi
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Conectando a Wi-Fi");
  while (WiFi.status() != WL_CONNECTED) {}
  Serial.println("\nWi-Fi Conectado.");

  // Configuración Firebase
  config.api_key = API_KEY;
  auth.user.email = "tizianoacp08@gmail.com";
  auth.user.password = "Tiziano2008";
  config.token_status_callback = tokenStatusCallback;

  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  // Obtener lista de contactos desde Firestore
  obtenerTelefonosFirestore();

  // Inicialización SIM800L
  sim800.begin(9600, SERIAL_8N1, RXD2, TXD2);
  delay(3000);
  enviarComando("AT");
  enviarComando("AT+CSQ");
  Serial.println("Sistema listo");
}


void loop() {
  switch (estadoActual) {
    case esperaCaida: {
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
      if (posibleCaida && millis() - tiempoCaida <= TIEMPO_VERIFICAR_IMPACTO && fuerzaImpacto > IMPACTO) {
        Serial.println("Caída confirmada");
        posibleCaida = false;
        tiempoConectarLlamada = millis();
        estadoActual = llamada;
      }
      if (posibleCaida && millis() - tiempoCaida > TIEMPO_VERIFICAR_IMPACTO) {
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
        for (int i = 0; i < cantidadTelefonos; i++) {
          String numActual = listaTelefonos[i];
          Serial.print("\n=== INTENTO ");
          Serial.print(i + 1);
          Serial.print(" - CONTACTO: ");
          Serial.print(numActual);
          Serial.println(" ===");
          enviarSMS(numActual);
          bool contestado = realizarLlamadaVerificada(numActual);
          if (contestado) {
            alguienAtendio = true;
            Serial.println("Emergencia atendida por un contacto. Finalizando secuencia.");
            break;
          }
          delay(2000); 
        }
        if (!alguienAtendio) {
          Serial.println("NINGÚN CONTACTO ATENDIÓ. LLAMANDO AL 911...");
          realizarLlamadaVerificada("911");
        }
        estadoActual = esperaCaida;
      } else {
        Serial.println("Sin registro en red...");
        if (millis() - tiempoConectarLlamada >= ESPERA_CONECTAR_LLAMADA) { 
          Serial.println("No se pudo realizar la conexión a tiempo.");
          estadoActual = esperaCaida;
        }
      }
      break;
    }
  }

  tira.fill(tira.Color(255, 255, 255));
  tira.show();
}
