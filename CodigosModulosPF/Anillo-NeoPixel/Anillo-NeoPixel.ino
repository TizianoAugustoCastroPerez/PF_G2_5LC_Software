#include <Adafruit_NeoPixel.h>

#define PIN_DATOS 27
#define NUM_LEDS 16

Adafruit_NeoPixel tira(NUM_LEDS, PIN_DATOS, NEO_GRB + NEO_KHZ800);

void setup() {
  tira.begin();
  tira.setBrightness(100);
  tira.fill(tira.Color(255, 255, 255));
  tira.show();
}

void loop() {}
