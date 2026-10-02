#include <WiFi.h>

struct Red {
  const char* bssid;
};

struct Ubicacion {
  const char* nombre;
  Red redes[5];
  int cantidadRedes;
};

// Redes que pertenecen a CASA
Ubicacion casa = {
  "CASA",
  {
    {"20:B8:2B:2E:59:A8"},
    {"5C:DF:89:49:A7:86"},
    {"5C:DF:89:49:A7:83"},
    {"5C:DF:89:48:40:D2"},
    {"5C:DF:89:48:51:68"}
  },
  5
};

// ========================================
// CONFIGURACION MINIMA PARA CONFIRMAR
// ========================================

const int MINIMO_REDES = 2;


// ========================================
// SETUP
// ========================================

void setup() {

  Serial.begin(115200);

  WiFi.mode(WIFI_STA);
  WiFi.disconnect();

  delay(1000);

  Serial.println("==============================");
  Serial.println("   DETECTOR DE UBICACION");
  Serial.println("==============================");
}


// ========================================
// LOOP
// ========================================

void loop() {

  Serial.println("\nEscaneando redes...");

  int cantidadEncontradas = WiFi.scanNetworks();

  int redesCasaEncontradas = 0;

  // ========================================
  // BUSCAR REDES DE CASA
  // ========================================

  for (int i = 0; i < cantidadEncontradas; i++) {

    String bssid = WiFi.BSSIDstr(i);

    Serial.print("Encontrada: ");
    Serial.print(WiFi.SSID(i));

    Serial.print(" | ");
    Serial.print(bssid);

    Serial.print(" | RSSI: ");
    Serial.println(WiFi.RSSI(i));


    // Comparar contra las redes configuradas
    for (int j = 0; j < casa.cantidadRedes; j++) {

      if (bssid.equalsIgnoreCase(casa.redes[j].bssid)) {

        redesCasaEncontradas++;

        Serial.print(" -> RED DE CASA DETECTADA #");
        Serial.println(redesCasaEncontradas);

        break;
      }
    }
  }


  // ========================================
  // DETERMINAR UBICACION
  // ========================================

  Serial.println();
  Serial.print("Redes de CASA encontradas: ");
  Serial.println(redesCasaEncontradas);


  if (redesCasaEncontradas >= MINIMO_REDES) {

    Serial.println("==============================");
    Serial.println("     UBICACION: CASA");
    Serial.println("==============================");

  } else {

    Serial.println("==============================");
    Serial.println("   UBICACION: DESCONOCIDA");
    Serial.println("==============================");
  }


  WiFi.scanDelete();

  delay(5000);
}