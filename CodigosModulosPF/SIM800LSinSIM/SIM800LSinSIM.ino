// Sin tarjeta SIM, solo podemos porbar la comunicación entre el SIM800L y el ESP32, para saber que está funcionando y bien alimentado
#include <HardwareSerial.h>

HardwareSerial sim800(2);
#define RXD2 16
#define TXD2 17 // pines TX y RX
#define INTERVALO_TOTAL 3000 // En este tiempo se ejecuta toda la acción
#define INTERVALO_COMANDO 500 // Separación de tiempo entre cada acción

unsigned long ultimoCambio = 0;
unsigned long ultimoComando = 0;
int estado = 0; // Variables de control de las distintas acciones

void setup() {
  Serial.begin(115200);
  sim800.begin(9600, SERIAL_8N1, RXD2, TXD2);
  delay(3000); // Tiempo de arranque del módulo
  sim800.println("AT");
}

void loop() {
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

// Cada caso representa 1 de las 4 mensajes posibles que puede devolver el SIM800L, chequeamos todos para asegurar que todo funciones
