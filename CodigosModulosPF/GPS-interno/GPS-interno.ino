#include <WiFi.h>

const char* SSID_CASA = "NOMBRE_RED_WIFI";
String BSSID_CASA = "";

void setup() {
  Serial.begin(115200);
  WiFi.mode(WIFI_STA);
  WiFi.disconnect();
  delay(1000);
  int cantidadEncontradas = WiFi.scanNetworks();
  for (int i = 0; i < cantidadEncontradas; i++) {
    if (WiFi.SSID(i) == SSID_CASA) {
      BSSID_CASA = WiFi.BSSIDstr(i);
      break;
    }
  }
  WiFi.scanDelete();
  if (BSSID_CASA == "") {
    Serial.println("ERROR: No se encontro la red de casa.");
  } 
}

void loop() {
  int cantidadEncontradas = WiFi.scanNetworks();
  bool casaEncontrada = false;
  for (int i = 0; i < cantidadEncontradas; i++) {
    String bssidActual = WiFi.BSSIDstr(i);
    if (bssidActual.equalsIgnoreCase(BSSID_CASA)) {
      casaEncontrada = true;
      break;
    }
  }
  WiFi.scanDelete();
  delay(5000);
}
