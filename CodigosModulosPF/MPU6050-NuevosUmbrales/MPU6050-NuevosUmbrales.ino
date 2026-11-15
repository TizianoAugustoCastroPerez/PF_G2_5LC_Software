#include <Wire.h>
#include <MPU6050.h>
#include <math.h>
#include "BluetoothSerial.h"

#define CAIDA_LIBRE 0.4
#define IMPACTO 2.0
#define TIEMPO_VERIFICAR_IMPACTO 2000
#define TIEMPO_ESPERA 100 // 100 ms = 10 datos por segundo (10 Hz)
#define CONVERSION_A_VALOR_REAL 16384.0

MPU6050 mpu;
BluetoothSerial SerialBT;

int16_t ax, ay, az;
bool posibleCaida = false;
unsigned long tiempoCaida = 0;
unsigned long espera = 0;

void setup() {
  Serial.begin(115200);
  Wire.begin(21, 22); // Pines I2C por defecto en ESP32: SDA = 21, SCL = 22

  SerialBT.begin("ESP32_Caidas"); // Nombre con el que aparecerá en tu celular
  Serial.println("Bluetooth listo. Buscá 'ESP32_Caidas' en tu teléfono.");

  mpu.initialize();
  while (!mpu.testConnection()) {
    delay(500);
  }
  Serial.println("MPU6050 conectado");
  
  // Encabezado de columnas para abrir luego en Excel
  SerialBT.println("Tiempo_ms,Ax,Ay,Az,FuerzaTotal,Evento");
}

void loop() {
  if (millis() - espera >= TIEMPO_ESPERA) {
    espera = millis(); // Actualiza el reloj en cada lectura de 100 ms

    mpu.getAcceleration(&ax, &ay, &az);
    float Ax = ax / CONVERSION_A_VALOR_REAL;
    float Ay = ay / CONVERSION_A_VALOR_REAL;
    float Az = az / CONVERSION_A_VALOR_REAL;
    float fuerzaCaida = sqrt(Ax * Ax + Ay * Ay + Az * Az);

    String evento = "Normal";

    // CAÍDA LIBRE
    if (fuerzaCaida < CAIDA_LIBRE && !posibleCaida) {
      posibleCaida = true;
      tiempoCaida = millis();
      evento = "POSIBLE_CAIDA";
    }

    // IMPACTO
    if (posibleCaida && (millis() - tiempoCaida <= TIEMPO_VERIFICAR_IMPACTO) && fuerzaCaida > IMPACTO) {
      posibleCaida = false;
      evento = "CAIDA_CONFIRMADA";
    }

    // SIN IMPACTO
    if (posibleCaida && (millis() - tiempoCaida > TIEMPO_VERIFICAR_IMPACTO)) {
      posibleCaida = false;
      evento = "FALSA_ALARMA";
    }

    // Envío de la fila CSV por Bluetooth
    SerialBT.print(millis());       SerialBT.print(",");
    SerialBT.print(Ax, 2);          SerialBT.print(",");
    SerialBT.print(Ay, 2);          SerialBT.print(",");
    SerialBT.print(Az, 2);          SerialBT.print(",");
    SerialBT.print(fuerzaCaida, 2); SerialBT.print(",");
    SerialBT.println(evento);
  }
}