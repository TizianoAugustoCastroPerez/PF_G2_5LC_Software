#define PIN_LED 18
#define PIN_BOTON 19

void setup() {
  Serial.begin(115200);
  pinMode(PIN_LED, OUTPUT);
  pinMode(PIN_BOTON, INPUT_PULLUP);
}

void loop() {
  if (digitalRead(PIN_BOTON) == LOW) {
    digitalWrite(PIN_LED, HIGH);
  } else {
    digitalWrite(PIN_LED, LOW);
  }
}
// Código TOTALMENTE necesario
