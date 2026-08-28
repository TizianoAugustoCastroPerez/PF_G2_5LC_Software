#include <Adafruit_NeoPixel.h>

#define PIN_DATOS   13  // Pin GPIO del ESP32 conectado al DI
#define NUM_LEDS    16  // Número de LEDs del anillo

const int rojo  = 255;  
const int verde = 255; 
const int azul  = 255;
// Con esta combinación de colores se obtiene blanco (la presencia de todos los colores)

// Configuración del NeoPixel
Adafruit_NeoPixel tira = Adafruit_NeoPixel(NUM_LEDS, PIN_DATOS, NEO_GRB + NEO_KHZ800);

void setup() {
  tira.begin();           // Inicializa el anillo
  tira.setBrightness(200); // Brillo alto (va de 0 a 255)
  tira.setPixelColor(NUM_LEDS, tira.Color(rojo, verde, azul)); // Se cambia el valor de los LEDs
  tira.show();  // Se muestra el cambio
}

void loop() {}