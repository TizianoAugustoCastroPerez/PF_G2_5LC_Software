#include <WiFi.h>

void setup() {
  Serial.begin(115200);
  delay(1000);

  // Se configura el modo Wi-Fi en estación para inicializar la interfaz
  WiFi.mode(WIFI_STA);

  Serial.println();
  Serial.print("Dirección MAC del ESP32: ");
  Serial.println(WiFi.macAddress());
}

void loop() {
}