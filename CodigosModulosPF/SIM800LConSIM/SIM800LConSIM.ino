#include <HardwareSerial.h>

HardwareSerial sim800(2);
#define RXD2 16
#define TXD2 17

// Formato internacional para Claro Argentina: "+549" + área sin 0 + número sin 15 (Celu de Jojo)
String numero = "+5491128550660";

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
  // Revisa si la respuesta contiene 0,1 (red local) o 0,5 (roaming)
  return (resp.indexOf("+CREG: 0,1") != -1 || resp.indexOf("+CREG: 0,5") != -1);
}

void setup() {
  Serial.begin(115200);
  sim800.begin(9600, SERIAL_8N1, RXD2, TXD2);

  Serial.println("Iniciando SIM800L...");
  delay(3000);

  enviarComando("AT");
  enviarComando("AT+CSQ"); // Muestra el nivel de señal

  Serial.println("Esperando registro en la red celular...");
  while (!estaRegistradoEnRed()) {
    Serial.println("-> Sin registro en red aun. Reintentando en 3s...");
    delay(3000);
  }
  
  Serial.println(">>> ¡REGISTRADO CORRECTAMENTE EN LA RED! <<<");
}

void loop() {
  Serial.println("Realizando llamada...");
  enviarComando("ATD" + numero + ";", 3000);

  delay(15000); // 15 segundos sonando/en llamada

  Serial.println("Finalizando llamada...");
  enviarComando("ATH", 2000);

  delay(20000); // Esperar 20 segundos antes del siguiente intento
}
