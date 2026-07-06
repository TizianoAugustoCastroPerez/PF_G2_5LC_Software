#include <Wire.h>
#include <MPU6050.h>
#include <math.h>

MPU6050 mpu;         // Nombre del módulo
int16_t ax, ay, az;  // Ejes de aceleración

void setup() {
  Serial.begin(115200);
  Wire.begin();
  mpu.initialize();
  while (!mpu.testConnection()) {}
  Serial.println("Sistema listo");
}

void loop() {
  mpu.getAcceleration(&ax, &ay, &az);
  float Ax = ax / 16384.0;
  float Ay = ay / 16384.0;
  float Az = az / 16384.0;                                // Conversión
  float fuerzaCaida = sqrt(Ax * Ax + Ay * Ay + Az * Az);  // calcula aceleración/fuerza total
  Serial.println(fuerzaCaida);
  delay(500);
}
