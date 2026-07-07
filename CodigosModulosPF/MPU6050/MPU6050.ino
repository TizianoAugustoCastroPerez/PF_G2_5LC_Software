#include <Wire.h>
#include <MPU6050.h>
#include <math.h>

#define CAIDA_LIBRE 0.4 // valor esperado de caída
#define IMPACTO 2 // valor esperado de impacto
#define TIEMPO_VERIFICAR_IMPACTO 2000
#define TIEMPO_ESPERA 20
MPU6050 mpu;         // Nombre del módulo
int16_t ax, ay, az;  // Ejes de aceleración
bool posibleCaida = false;
unsigned long tiempoCaida = 0;  // contador
unsigned long espera = 20;
void setup() {
  Serial.begin(115200);
  Wire.begin();
  mpu.initialize();
  while (!mpu.testConnection()) {}
  Serial.println("Sistema listo"); // Se inicializa el MPU6050 y se espera a que se conecte
}

void loop() {
  if (millis() - espera >= TIEMPO_ESPERA) { // para dar un tiempo de espera entre lecturas

    mpu.getAcceleration(&ax, &ay, &az);
    float Ax = ax / 16384.0;
    float Ay = ay / 16384.0;
    float Az = az / 16384.0;                                // Conversión
    float fuerzaCaida = sqrt(Ax * Ax + Ay * Ay + Az * Az);  // calcula aceleración/fuerza total

    // CAÍDA LIBRE
    if (fuerzaCaida < CAIDA_LIBRE && posibleCaida == false) {
      Serial.println("Posible caída, a confirmar");
      posibleCaida = true;
      tiempoCaida = millis();
    }

    // IMPACTO
    if (posibleCaida == true && millis() - tiempoCaida <= TIEMPO_VERIFICAR_IMPACTO && fuerzaCaida > IMPACTO) {
      Serial.println("Caída confirmada");
      posibleCaida = false;
    }

    // SIN IMPACTO
    if (posibleCaida && millis() - tiempoCaida > TIEMPO_VERIFICAR_IMPACTO) {
      Serial.println("No se cayó nadie");
      posibleCaida = false;
      espera = millis();
    }    
  }
}
