// Do not remove the include below
#include "OrionHT550.h"

const byte numbers[10] = { SSEG_0, SSEG_1, SSEG_2, SSEG_3, SSEG_4, SSEG_5, SSEG_6, SSEG_7, SSEG_8, SSEG_9 };
byte globalVolume = INITIAL_GLOBAL_VOLUME;
long encPosition = INITIAL_ENCODER_POS;

Encoder encMain(ENC_A, ENC_B);
IRrecv irReceiver(IR);
decode_results results;

//The setup function is called once at startup of the sketch
void setup() {
    Serial.begin(SERIAL_SPEED);
    irReceiver.enableIRIn();
    Wire.begin();

    pinMode(LED_CLK, OUTPUT);
    pinMode(LED_DATA, OUTPUT);
    pinMode(LED_EN1, OUTPUT);
    pinMode(LED_EN2, OUTPUT);
    pinMode(MUTE_NEG, OUTPUT);

    displayChar();
    delay(1000);
    //initAmp();
}

void initAmp() {
    setGlobalVolume(MAX_ATTENUATION);  //set the volume to the lowest setting
    setMute(true);  //enable muting


    delay(2000);  //wait 2 secs for the amp to settle
    setInput(INPUT_STEREO);  //enable the stereo input
    setSurroundEnhancement(false);
    setMixerChannel6Db(false);
    setMute(false);  //disable muting
    globalVolume = 39;
    setGlobalVolume(globalVolume);  //set the volume to the half of the max setting
}

void displayChar() {
    digitalWrite(LED_EN1, HIGH);
    digitalWrite(LED_EN2, HIGH);
    shiftOut(LED_DATA, LED_CLK, LSBFIRST, SSEG_DASH);
}

void displayNumber(uint8_t num) {
    digitalWrite(LED_EN2, LOW);
    digitalWrite(LED_EN1, HIGH);
    shiftOut(LED_DATA, LED_CLK, LSBFIRST, numbers[num / 10]);
    delay(10);
    digitalWrite(LED_EN1, LOW);
    digitalWrite(LED_EN2, HIGH);
    shiftOut(LED_DATA, LED_CLK, LSBFIRST, numbers[num % 10]);
    delay(10);
}

// The loop function is called in an endvoid initAmp()less loop
void loop() {
    long encNew = encMain.read();
    if (encNew != encPosition) {
        if (encNew > encPosition && encNew % 4 != 0) {
            //increaseVolume();
        } else if (encNew < encPosition && encNew % 4 != 0) {
            //decreaseVolume();
        }

        encPosition = encNew;
        Serial.print("ENCODER: ");
        Serial.println(encNew);
    }

    if (irReceiver.decode(&results)) {
        Serial.print("IR: ");
        Serial.println(results.value, HEX);

        if (results.value == IR_VOLDOWN) {
            //decreaseVolume();
        } else if (results.value == IR_VOLUP) {
            //increaseVolume();
        }

        irReceiver.resume();
    }

    displayNumber(globalVolume);
}

void setInput(byte input) {
    switch (input) {
        case INPUT_STEREO:
            pt2323(PT2323_INST1);
            break;
        case INPUT_SURROUND:
            pt2323(PT2323_IN6CH);
            break;
    }
}

void setSurroundEnhancement(bool enhancement) {
    if (enhancement) {
        pt2323(PT2323_SURRENH_ON);
    } else {
        pt2323(PT2323_SURRENH_OFF);
    }
}

void setMixerChannel6Db(bool mix6db) {
    if (mix6db) {
        pt2323(PT2323_MIXCHAN_6DB);
    } else {
        pt2323(PT2323_MIXCHAN_0DB);
    }
}

void setMute(bool mute) {
    if (mute) {
        pt2258(CHAN_MUTE, PT2258_ALLCH_MUTE);
        pt2323(PT2323_ALL_MUTE);
        digitalWrite(MUTE_NEG, LOW);
    } else {
        pt2258(CHAN_MUTE, PT2258_ALLCH_UNMUTE);
        pt2323(PT2323_ALL_UNMUTE);
        digitalWrite(MUTE_NEG, HIGH);
    }
}

void increaseVolume() {
    if (globalVolume < MAX_ATTENUATION) {
        globalVolume++;
        setGlobalVolume(globalVolume);
    }
}

void decreaseVolume() {
    if (globalVolume > MIN_ATTENUATION) {
        globalVolume--;
        setGlobalVolume(globalVolume);
    }
}

void setGlobalVolume(byte volume) {
    setChannelVolume(CHAN_ALL, volume);
}

void setChannelVolume(byte channel, byte volume) {
    if (volume >= MIN_ATTENUATION && volume <= MAX_ATTENUATION) {
        byte attenuation = MAX_ATTENUATION - volume;
        pt2258(CHAN_ALL, attenuation);
    }
}

void pt2323(byte command) {
    Wire.beginTransmission(PT2323_ADDRESS);
    Wire.write(command);
    Wire.endTransmission();
}

void pt2258(byte channel, byte value) {
    byte x10 = value / 10;
    byte x1 = value % 10;

    switch (channel) {
        case CHAN_ALL:
            x1 += PT2258_ALLCH_1DB;
            x10 += PT2258_ALLCH_10DB;
            break;
        case CHAN_FL:
            x1 += PT2258_FL_1DB;
            x10 += PT2258_FL_10DB;
            break;
        case CHAN_FR:
            x1 += PT2258_FR_1DB;
            x10 += PT2258_FR_10DB;
            break;
        case CHAN_CEN:
            x1 += PT2258_CEN_1DB;
            x10 += PT2258_CEN_10DB;
            break;
        case CHAN_SW:
            x1 += PT2258_SW_1DB;
            x10 += PT2258_SW_10DB;
            break;
        case CHAN_RL:
            x1 += PT2258_RL_1DB;
            x10 += PT2258_RL_10DB;
            break;
        case CHAN_RR:
            x1 += PT2258_RR_1DB;
            x10 += PT2258_RL_10DB;
            break;
        case CHAN_MUTE:
            if (value == 0) {
                x10 = x1 = PT2258_ALLCH_MUTE;
            } else {
                x10 = x1 = PT2258_ALLCH_UNMUTE;
            }
            break;
    }

    for (int i = 0; i <= 2; i++) { // repeat 2x (had some unknown issues when transmitted only once)
        Wire.beginTransmission(PT2258_ADDRESS);
        Wire.write(x10);
        Wire.write(x1);
        Wire.endTransmission();
    }
}

int readSerialInt() {
    int res = UNKNOWN_VALUE;

    if (Serial.available() > 0) {
        char in = Serial.read();
        res = atoi(&in);
    }

    return res;
}

void printSerialPrompt(char* message) {
    Serial.print(message);
    Serial.print(" > ");
}

void printMainMenu() {
    Serial.println("Orion HT550 serial menu");
    Serial.println("  1. Input selection");
    Serial.println("  2. Global volume");
    Serial.println("  3. Per-speaker volume");
    Serial.println("  4. Muting");
    Serial.println("  5. Enhanced surround");
    Serial.println("  6. Mixed channel boost");
    Serial.println("  7. EEPROM operations");
    Serial.println("  8. Stand-by mode");
    Serial.println("  9. Status report");
    Serial.println("  0. Quit");
}

void printInputMenu() {
    Serial.println("Select the input source:");
    Serial.println("  1. Stereo");
    Serial.println("  2. Surround");
}

void printSpeakersMenu() {
    Serial.println("Select the speaker:");
    Serial.println("  1. Front left");
    Serial.println("  2. Front right");
    Serial.println("  3. Rear left");
    Serial.println("  4. Rear right");
    Serial.println("  5. Center");
    Serial.println("  6. Subwoofer");
}

void printEepromMenu() {
    Serial.println("Select the EEPROM operation:");
    Serial.println("  1. Store");
    Serial.println("  2. Restore");
}

void printStatusMenu() {
    Serial.print("FL volume: ");
    Serial.println();
    Serial.print("FR volume: ");
    Serial.println();
    Serial.print("RL volume: ");
    Serial.println();
    Serial.print("RR volume: ");
    Serial.println();
    Serial.print("CEN volume: ");
    Serial.println();
    Serial.print("SW volume: ");
    Serial.println();
    Serial.print("Input: ");
    Serial.println();
    Serial.print("Muting: ");
    Serial.println();
    Serial.print("Enhanced surround: ");
    Serial.println();
    Serial.print("Mixed channel boost: ");
    Serial.println();
}
