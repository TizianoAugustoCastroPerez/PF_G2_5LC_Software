// Esta es la primera versión del código definitivo del proyecto, de ahora en adelante va a ser el único código que reciba cambios
#include <Wire.h>
#include <MPU6050.h>
#include <math.h>
#include <HardwareSerial.h>
#include <Adafruit_NeoPixel.h>

HardwareSerial sim800(2);
#define RXD2 16
#define TXD2 17
#define PIN_LED 18
#define PIN_BOTON 19
#define PIN_DATOS_ANILLO 13  
#define NUM_LEDS 16
#define CAIDA_LIBRE 0.4
#define IMPACTO 2
#define TIEMPO_VERIFICAR_IMPACTO 2000
#define ESPERA_PULSO 30
#define CONVERSION_A_VALOR_REAL 16384.0
#define ESPERA_CONECTAR_LLAMADA 10000
String numero = "+54911...";

unsigned long ultimoCambio = 0;
unsigned long ultimoComando = 0;
unsigned long tiempoConectarLlamada = 0;
int estado = 0;
MPU6050 mpu;         // Nombre del módulo
int16_t ax, ay, az;  // Ejes de aceleración
bool posibleCaida = false;
unsigned long tiempoCaida = 0;  // contador
unsigned long espera = 20;
bool condicion1 = false;
bool condicion2 = false;
bool condicion3 = false;

const int rojo  = 255;  
const int verde = 255; 
const int azul  = 255;
Adafruit_NeoPixel tira = Adafruit_NeoPixel(NUM_LEDS, PIN_DATOS, NEO_GRB + NEO_KHZ800);

typedef enum {
  esperaCaida,
  confirmarCaida,
  llamada,
} estado;
estado estadoActual = esperaCaida;

// Esta es la función que se usa para confirmar que el SIM800L esté bien conectado, se ejecutan 3 comandos
bool enviarComando(String comando, unsigned long tiempoEspera = 2000) {

  while (sim800.available()) {
    sim800.read();
  }

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
    if (respuesta.indexOf("OK") != -1) {
      return true;
    }
  }
  return false;
}

void setup() {
  Serial.begin(115200);
  pinMode(PIN_LED, OUTPUT);
  pinMode(PIN_BOTON, INPUT_PULLUP);
  Wire.begin();
  mpu.initialize();
  while (!mpu.testConnection()) {}
  sim800.begin(9600, SERIAL_8N1, RXD2, TXD2);
  delay(3000);  // Tiempo de arranque del módulo
  sim800.println("AT");
  Serial.println("Sistema listo");
  tira.begin();      
  tira.setBrightness(200);
  tira.setPixelColor(NUM_LEDS, tira.Color(rojo, verde, azul));
  tira.show();
}

void loop() {

  switch (estadoActual) {
    case (esperaCaida):
      mpu.getAcceleration(&ax, &ay, &az);
      float Ax = ax / CONVERSION_A_VALOR_REAL;
      float Ay = ay / CONVERSION_A_VALOR_REAL;
      float Az = az / CONVERSION_A_VALOR_REAL;                // Conversión
      float fuerzaCaida = sqrt(Ax * Ax + Ay * Ay + Az * Az);  // Calcula aceleración/fuerza total

      // CAÍDA LIBRE
      if (fuerzaCaida < CAIDA_LIBRE && posibleCaida == false) {
        Serial.println("Posible caída, a confirmar");
        posibleCaida = true;
        tiempoCaida = millis();
        estadoActual = confirmarCaida;
      }
    break;

    case (confirmarCaida):
      // IMPACTO
      if (posibleCaida == true && millis() - tiempoCaida <= TIEMPO_VERIFICAR_IMPACTO && fuerzaCaida > IMPACTO) {
        Serial.println("Caída confirmada");
        posibleCaida = false;
        tiempoConectarLlamada = millis();
        estadoActual = llamada;
      }
      // SIN IMPACTO
      if (posibleCaida && millis() - tiempoCaida > TIEMPO_VERIFICAR_IMPACTO) {
        Serial.println("No se cayó nadie, esperando a detectar otra caída");
        posibleCaida = false;
        espera = millis();
        estadoActual = esperaCaida;
      }
    break;

    case (llamada):
      if (condicion1 == false || condicion2 == false || condicion3 == false) {
        if (!enviarComando("AT")) {
          Serial.println("Error de comunicacion con SIM800.");
          condicion1 = false;
        } else {
          condicion1 = true;
        }
        if (!enviarComando("AT+CSQ")) {
          Serial.println("No se pudo leer la intensidad de señal.");
          condicion2 = false;
        } else {
          condicion2 = true;
        }
        if (!enviarComando("AT+CREG?")) {
          Serial.println("No se pudo verificar el registro en la red.");
          condicion3 = false;
        } else {
          condicion3 = true;
        }
      }
      if (condicion1 == true && condicion2 == true && condicion3 == true && millis() - tiempoConectarLlamada <= ESPERA_CONECTAR_LLAMADA) {
        Serial.println("Enviando los mensajes primero...")
        enviarSMS();
        Serial.println("Realizando llamada..."); // Se realizaron exitosamente los 3 chequeos
        sim800.print("ATD");
        sim800.print(numero);
        sim800.println(";"); // El SIM arranca la llamada
        delay(15000);
        Serial.println("Finalizando llamada...");
        sim800.println("ATH");
        delay(20000);
        estadoActual = esperaCaida;
      }
      if (millis() - tiempoConectarLlamada >= ESPERA_CONECTAR_LLAMADA) { 
        // Aún tengo que  definir que pasa en este caso, dependiendo de que si la conexión del SIM800L es estable o no, que aún se debe probar
        Serial.println("No se pudo realizar la conexión");
        estadoActual = esperaCaida;
      }
    break;
  }

}

void enviarSMS() {
  unsigned long espera;
  int casos = 1;
  bool ejecutarUnaVez = true;
  bool ejecutarFuncion = true;
  int tiempoCaso1 = 300;
  int tiempoCaso2 = 600;
  int tiempoCaso3 = 1000;
  int tiempoCaso4 = 6000;
  espera = millis();

  while (ejecutarFuncion) {
    if (casos == 1) {
      if (ejecutarUnaVez == true) {
        // Cambiar a texto
        sim800.println("AT+CMGF=1");
        ejecutarUnaVez = false;
      }
      if (millis() - espera >= tiempoCaso1) {
        casos = 2;
        ejecutarUnaVez = true;
      }
    }
    if (casos == 2) {
      if (ejecutarUnaVez == true) {
        // Número de contacto
        sim800.print("AT+CMGS=\"");
        sim800.print(numero);
        sim800.println("\"");
        ejecutarUnaVez = false;
      }
      if (millis() - espera >= tiempoCaso2) {
        casos = 3;
        ejecutarUnaVez = true;
      }
    }
    if (casos == 3) {
      if (ejecutarUnaVez == true) {
        // Mensaje
        sim800.print("Se detectó una caída.");
        ejecutarUnaVez = false;
      }
      if (millis() - espera >= tiempoCaso3) {
        casos = 4;
        ejecutarUnaVez = true;
      }
    }  
    if (casos == 4) {
      if (ejecutarUnaVez == true) {
        // Enviado
        sim800.write(26);
        ejecutarUnaVez = false;
      }
      if (millis() - espera >= tiempoCaso4) {
        ejecutarFuncion = false;
      }
    }  
  }
}
