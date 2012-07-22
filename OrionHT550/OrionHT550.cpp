// Do not remove the include below
#include "OrionHT550.h"

#define ENC_A 2
#define ENC_B 3
#define LED_CLK 5
#define LED_DATA 6
#define IR 7
#define LED_EN1 8
#define LED_EN2 9
#define BTN_COM 11
#define IR_VOLDOWN 0x1FE50AF
#define IR_VOLUP 0x1FEF807
#define IR_REPEAT 0xFFFFFFFF

const byte numbers[10] = { B01000001, B11100111, B01010010, B01100010, B11100100, B01101000, B01001000, B11100011, B01000000, B01100000 };
uint8_t value = 50;
long encPosition = -999;

Encoder encMain(ENC_A, ENC_B);

IRrecv irReceiver(IR);
decode_results results;

//The setup function is called once at startup of the sketch
void setup() {
    Serial.begin(9600);
    irReceiver.enableIRIn();

    pinMode(LED_CLK, OUTPUT);
    pinMode(LED_DATA, OUTPUT);
    pinMode(LED_EN1, OUTPUT);
    pinMode(LED_EN2, OUTPUT);
}

void lightSegments(byte num) {
    shiftOut(LED_DATA, LED_CLK, LSBFIRST, numbers[num]);
}

void lightTens(byte num) {
    digitalWrite(LED_EN2, LOW);
    digitalWrite(LED_EN1, HIGH);
    lightSegments(num);
}

void lightOnes(byte num) {
    digitalWrite(LED_EN1, LOW);
    digitalWrite(LED_EN2, HIGH);
    lightSegments(num);
}

void displayNumber(uint8_t num) {
    uint8_t tens = num / 10;
    uint8_t ones = num % 10;
    lightTens(tens);
    delay(10);
    lightOnes(ones);
    delay(10);
}

// The loop function is called in an endless loop
void loop() {
    long encNew = encMain.read();
    if (encNew != encPosition) {
        if (encNew > encPosition && encNew%4 != 0) {
            value++;
        } else if (encNew < encPosition && encNew%4 != 0) {
            value--;
        }

        encPosition = encNew;
        Serial.print("ENCODER: ");
        Serial.println(encNew);
    }

    if (irReceiver.decode(&results)) {
        Serial.print("IR: ");
        Serial.println(results.value, HEX);

        if (results.value == IR_VOLDOWN) {
            value--;
        } else if (results.value == IR_VOLUP) {
            value++;
        }

        irReceiver.resume();
    }

    displayNumber(value);
}
