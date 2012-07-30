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
    Wire.begin();

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
        if (encNew > encPosition && encNew % 4 != 0) {
            value++;
        } else if (encNew < encPosition && encNew % 4 != 0) {
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

void pt2323(byte command) {
    Wire.beginTransmission(PT2323_ADDRESS);
    Wire.write(command);
    Wire.endTransmission();
}

//------------------------------------------------------------------------------
// Volume controller IC command set
//------------------------------------------------------------------------------
void pt2258(byte command, byte ch)  // send volume level commands
{
    byte x10;
    byte x1;

    if (command >= 10) {
        x10 = command / 10;        // set decade step
        x1 = command % 10;       // set step
    } else                       // set step
    {
        x1 = command;
        x10 = 0;
    }

    switch (ch)                 // which channel to command
    {
        case 0:    // all channels
            x1 = x1 + 0xe0;
            x10 = x10 + 0xd0;
            break;

        case 1:    // channel 1
            x1 = x1 + 0x90;
            x10 = x10 + 0x80;
            break;

        case 2:    // channel 2
            x1 = x1 + 0x50;
            x10 = x10 + 0x40;
            break;

        case 3:    // channel 3
            x1 = x1 + 0x10;
            x10 = x10 + 0x00;
            break;

        case 4:    // channel 4
            x1 = x1 + 0x30;
            x10 = x10 + 0x20;
            break;

        case 5:    // channel 5
            x1 = x1 + 0x70;
            x10 = x10 + 0x60;
            break;

        case 6:    // channel 6
            x1 = x1 + 0xb0;
            x10 = x10 + 0xa0;
            break;

        default:   // mute functions
            if (command == 0)
                x10, x1 = 0xf8;   // mute off
            else
                x10, x1 = 0xf9;               // mute on
            break;
    }

    for (int i = 0; i <= 2; i++)  // repeat 2x (had some unknown issues when transmitted only once)
            {
        Wire.beginTransmission(68); // transmit to device 0x88(hex) -> 136(dec)(addressing is 7-bit) -> 136/2
        Wire.write(x10);             // send decade step
        Wire.write(x1);              // send step
        Wire.endTransmission();     // stop transmitting
    }
}
