#include <Wire.h>
#include <MPU6050.h>
#include <math.h>
#include "BluetoothSerial.h"

#define CAIDA_LIBRE 0.4
#define IMPACTO 2.0
#define TIEMPO_ESPERA 100 // 100 ms = 10 datos por segundo (10 Hz)
#define CONVERSION_A_VALOR_REAL 16384.0

MPU6050 mpu;
BluetoothSerial SerialBT;

int16_t ax, ay, az;
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
}

void loop() {
  if (millis() - espera >= TIEMPO_ESPERA) {
    espera = millis(); // Actualiza el reloj en cada lectura de 100 ms

    mpu.getAcceleration(&ax, &ay, &az);
    float Ax = ax / CONVERSION_A_VALOR_REAL;
    float Ay = ay / CONVERSION_A_VALOR_REAL;
    float Az = az / CONVERSION_A_VALOR_REAL;
    float fuerzaCaida = sqrt(Ax * Ax + Ay * Ay + Az * Az);

    // Envía primero el valor numérico
    SerialBT.print(fuerzaCaida, 2);

    // Agrega la etiqueta a la derecha si supera alguno de los umbrales
    if (fuerzaCaida < CAIDA_LIBRE) {
      SerialBT.print(" inicio caida");
    } else if (fuerzaCaida > IMPACTO) {
      SerialBT.print(" fin caida");
    }

    SerialBT.println(); // Salto de línea para la siguiente lectura
  }
}
