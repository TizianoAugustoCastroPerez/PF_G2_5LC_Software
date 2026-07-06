#include <HardwareSerial.h>

HardwareSerial sim800(2);
#define RXD2 16
#define TXD2 17
String numero = "XXXXXXXXXX";

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

  sim800.begin(9600, SERIAL_8N1, RXD2, TXD2);
  Serial.println("Esperando inicio del SIM800...");
  delay(3000);

  
}

void loop() {
  if (!enviarComando("AT")) {
    Serial.println("Error de comunicacion con SIM800.");
    return;
  }
  if (!enviarComando("AT+CSQ")) {
    Serial.println("No se pudo leer la intensidad de señal.");
    return;
  }
  if (!enviarComando("AT+CREG?")) {
    Serial.println("No se pudo verificar el registro en la red.");
    return;
  }

  Serial.println("Realizando llamada..."); // Se realizaron exitosamente los 3 chequeos
  sim800.print("ATD");
  sim800.print(numero);
  sim800.println(";"); // El SIM arranca la llamada
  delay(15000);
  Serial.println("Finalizando llamada...");
  sim800.println("ATH");
  delay(20000);
}