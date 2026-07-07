// Este código tiene pocos comentarios, serían repetitivos
#include <Wire.h>
#include <MPU6050.h>
#include <math.h>
#include <HardwareSerial.h>

TaskHandle_t tarea1;  // Va en el core 0
TaskHandle_t tarea2;  // Va en el core 1

#define PIN_LED 18
#define PIN_BOTON 19
#define CAIDA_LIBRE 0.4
#define IMPACTO 2
#define TIEMPO_VERIFICAR_IMPACTO 2000
#define TIEMPO_ESPERA 20
#define RXD2 16
#define TXD2 17
#define INTERVALO_TOTAL 3000
#define INTERVALO_COMANDO 500
HardwareSerial sim800(2);
unsigned long ultimoCambio = 0;
unsigned long ultimoComando = 0;
int estado = 0;
MPU6050 mpu;         // Nombre del módulo
int16_t ax, ay, az;  // Ejes de aceleración
bool posibleCaida = false;
unsigned long tiempoCaida = 0;  // contador
unsigned long espera = 20;
void setup() {
  Serial.begin(115200);
  pinMode(PIN_LED, OUTPUT);
  pinMode(PIN_BOTON, INPUT_PULLUP);

  xTaskCreatePinnedToCore(
    Loop1,     // función que ejecuta la tarea
    "Tarea1",  // nombre interno
    8192,      // tamaño de stack (Es suficiente)
    NULL,      // parámetros (no tiene)
    1,         // prioridad (es la misma en ambas tareas ya que ambas tienen la misma importancia)
    &tarea1,   // handle/referencia (nombre definido arriba)
    0          // core donde correrá
  );           // la lógica es la misma en la otra tarea

  xTaskCreatePinnedToCore(
    Loop2,
    "Tarea2",
    8192,
    NULL,
    1,
    &tarea2,
    1);
  Wire.begin();
  mpu.initialize();
  while (!mpu.testConnection()) {}
  sim800.begin(9600, SERIAL_8N1, RXD2, TXD2);
  delay(3000);  // Tiempo de arranque del módulo
  sim800.println("AT");
  Serial.println("Sistema listo");
}

void Loop1(void* pvParameters) {
  for (;;) {
    if (millis() - espera >= TIEMPO_ESPERA) {  // para dar un tiempo de espera entre lecturas

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
        digitalWrite(PIN_LED, LOW);
      }

      // IMPACTO
      if (posibleCaida == true && millis() - tiempoCaida <= TIEMPO_VERIFICAR_IMPACTO && fuerzaCaida > IMPACTO) {
        Serial.println("Caída confirmada");
        posibleCaida = false;
        digitalWrite(PIN_LED, HIGH);
      }

      // SIN IMPACTO
      if (posibleCaida && millis() - tiempoCaida > TIEMPO_VERIFICAR_IMPACTO) {
        Serial.println("No se cayó nadie");
        posibleCaida = false;
        espera = millis();
        digitalWrite(PIN_LED, LOW);
      }

      // PRESIONA BOTÓN
      if (digitalRead(PIN_BOTON) == LOW) {
        digitalWrite(PIN_LED, HIGH);
      }
    }
  }
}

void Loop2(void* pvParameters) {
  for (;;) {
    // SIM, Y LOS CASOS
    while (sim800.available()) {
      Serial.write(sim800.read());
    }

    if (millis() - ultimoCambio >= INTERVALO_TOTAL) {
      ultimoCambio = millis();
      estado = 0;
    }

    if (millis() - ultimoComando >= INTERVALO_COMANDO) {
      ultimoComando = millis();
      switch (estado) {
        case 0:
          Serial.println("AT:");
          sim800.println("AT");
          break;

        case 1:
          Serial.println("CSQ:");
          sim800.println("AT+CSQ");
          break;

        case 2:
          Serial.println("CREG:");
          sim800.println("AT+CREG?");
          break;

        case 3:
          Serial.println("CCID:");
          sim800.println("AT+CCID");
          break;
      }
      estado++;
      if (estado > 3) {
        estado = 0;
      }
    }
  }
}

void loop() {}
