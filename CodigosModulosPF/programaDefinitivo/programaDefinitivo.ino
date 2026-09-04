// Código principal (falta trabajar la conexión con Firebase)
#include <Wire.h>
#include <MPU6050.h>
#include <math.h>
#include <HardwareSerial.h>
#include <Adafruit_NeoPixel.h>

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
#define ESPERA_CONECTAR_LLAMADA 10000

// Configuración de contacto
String numero = "+5491128550660";

// Variables MPU6050
MPU6050 mpu;
int16_t ax, ay, az;
bool posibleCaida = false;
unsigned long tiempoCaida = 0;
unsigned long espera = 20;

// Variables NeoPixel
const int rojo  = 255;  
const int verde = 255; 
const int azul  = 255;
Adafruit_NeoPixel tira = Adafruit_NeoPixel(NUM_LEDS, PIN_DATOS_ANILLO, NEO_GRB + NEO_KHZ800);

// Máquina de Estados
typedef enum {
  esperaCaida,
  confirmarCaida,
  llamada
} EstadoSistema;

EstadoSistema estadoActual = esperaCaida;
unsigned long tiempoConectarLlamada = 0;

// --- FUNCIONES DEL MODULO SIM800L (VERSIÓN PROBADA) ---

String enviarComando(String comando, unsigned long tiempoEspera = 2000) {
  while (sim800.available()) sim800.read(); // Limpiar buffer de entrada

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
  // Evalúa si la respuesta contiene registro en red local (0,1) o roaming (0,5)
  return (resp.indexOf("+CREG: 0,1") != -1 || resp.indexOf("+CREG: 0,5") != -1);
}

void enviarSMS() {
  unsigned long esperaLocal = millis();
  int casos = 1;
  bool ejecutarUnaVez = true;
  bool ejecutarFuncion = true;
  int tiempoCaso1 = 300;
  int tiempoCaso2 = 600;
  int tiempoCaso3 = 1000;
  int tiempoCaso4 = 6000;

  while (ejecutarFuncion) {
    if (casos == 1) {
      if (ejecutarUnaVez) {
        sim800.println("AT+CMGF=1"); // Modo texto
        ejecutarUnaVez = false;
      }
      if (millis() - esperaLocal >= tiempoCaso1) {
        casos = 2;
        ejecutarUnaVez = true;
      }
    }
    if (casos == 2) {
      if (ejecutarUnaVez) {
        sim800.print("AT+CMGS=\"");
        sim800.print(numero);
        sim800.println("\"");
        ejecutarUnaVez = false;
      }
      if (millis() - esperaLocal >= tiempoCaso2) {
        casos = 3;
        ejecutarUnaVez = true;
      }
    }
    if (casos == 3) {
      if (ejecutarUnaVez) {
        sim800.print("Se detectó una caída.");
        ejecutarUnaVez = false;
      }
      if (millis() - esperaLocal >= tiempoCaso3) {
        casos = 4;
        ejecutarUnaVez = true;
      }
    }  
    if (casos == 4) {
      if (ejecutarUnaVez) {
        sim800.write(26); // CTRL+Z para enviar
        ejecutarUnaVez = false;
      }
      if (millis() - esperaLocal >= tiempoCaso4) {
        ejecutarFuncion = false;
      }
    }  
  }
}

// --- SETUP ---

void setup() {
  Serial.begin(115200);
  pinMode(PIN_LED, OUTPUT);
  pinMode(PIN_BOTON, INPUT_PULLUP);
  
  // Inicialización I2C / MPU6050
  Wire.begin();
  mpu.initialize();
  while (!mpu.testConnection()) {}

  // Inicialización NeoPixel
  tira.begin();      
  tira.setBrightness(200);
  tira.setPixelColor(0, tira.Color(rojo, verde, azul));
  tira.show();

  // Inicialización SIM800L
  sim800.begin(9600, SERIAL_8N1, RXD2, TXD2);
  delay(3000);
  enviarComando("AT");
  enviarComando("AT+CSQ");

  Serial.println("Sistema listo");
}

// --- BUCLE PRINCIPAL ---

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
        Serial.println("Enviando los mensajes primero...");
        enviarSMS();

        Serial.println("Realizando llamada...");
        enviarComando("ATD" + numero + ";", 3000);
        delay(15000);

        Serial.println("Finalizando llamada...");
        enviarComando("ATH", 2000);

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
}
