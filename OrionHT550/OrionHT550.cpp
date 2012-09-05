// Do not remove the include below
#include "OrionHT550.h"

const byte numbers[10] = { SSEG_0, SSEG_1, SSEG_2, SSEG_3, SSEG_4, SSEG_5, SSEG_6, SSEG_7, SSEG_8, SSEG_9 };

byte paramPower = DEFAULT_POWER;
byte paramVolumes[7] = {DEFAULT_VOLUME, DEFAULT_VOLUME, DEFAULT_VOLUME, DEFAULT_VOLUME, DEFAULT_VOLUME, DEFAULT_VOLUME, DEFAULT_VOLUME};
byte paramInput = DEFAULT_INPUT;
byte paramMute = DEFAULT_MUTE;
byte paramEnhancement = DEFAULT_ENHANCEMENT;
byte paramMixChBoost = DEFAULT_MIXCH_BOOST;
int serialBuffer[16] = {'\0', '\0', '\0', '\0', '\0', '\0', '\0', '\0', '\0', '\0', '\0', '\0', '\0', '\0', '\0', '\0'};
byte serialLength = 0;

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
    setGlobalVolume(paramVolumes[CHAN_ALL]);  //set the volume to the half of the max setting
}

void displayChar() {
    digitalWrite(LED_EN1, HIGH);
    digitalWrite(LED_EN2, HIGH);
    shiftOut(LED_DATA, LED_CLK, LSBFIRST, SSEG_DASH);
}

void displayNumber(byte num) {
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

    displayNumber(paramVolumes[CHAN_ALL]);

    handleSerial();
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
    if (paramVolumes[CHAN_ALL] < MAX_ATTENUATION) {
        paramVolumes[CHAN_ALL]++;
        setGlobalVolume(paramVolumes[CHAN_ALL]);
    }
}

void decreaseVolume() {
    if (paramVolumes[CHAN_ALL] > MIN_ATTENUATION) {
        paramVolumes[CHAN_ALL]--;
        setGlobalVolume(paramVolumes[CHAN_ALL]);
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

    for (byte i = 0; i <= 2; i++) { // repeat 2x (had some unknown issues when transmitted only once)
        Wire.beginTransmission(PT2258_ADDRESS);
        Wire.write(x10);
        Wire.write(x1);
        Wire.endTransmission();
    }
}

void handleSerial() {
    byte c;
    bool eol = false;

    while (Serial.available() > 0) {
        c = Serial.read();
        Serial.print(c);
        if (c == 13 || c == 10 || serialLength >= 16) {
            Serial.println("EOL");
            eol = true;
        } else {
            serialBuffer[serialLength] = c;
            serialLength++;
        }
    }

    if (eol) {
        bool commandOk = false;
        if (checkHeader()) {
            switch (serialBuffer[SERIAL_COMMAND_POS]) {
                case 'P':
                    paramPower = (isOn() ? ON : OFF);
                    commandOk = true;
                    break;
                case 'V':
                    paramVolumes[getChannel()] = getNumber();
                    commandOk = true;
                    break;
                case 'E':
                    paramEnhancement = (isOn() ? ON : OFF);
                    commandOk = true;
                    break;
                case 'B':
                    paramMixChBoost = (isOn() ? ON : OFF);
                    commandOk = true;
                    break;
                case 'M':
                    paramMute = (isOn() ? ON : OFF);
                    commandOk = true;
                    break;
                case 'S':
                    if (isOn()) {
                        Serial.println("Store...");
                        commandOk = true;
                    }
                    break;
                case 'R':
                    if (isOn()) {
                        Serial.println("Restore...");
                        commandOk = true;
                    }
                    break;
                case 'I':
                    paramInput = (isOn() ? INPUT_SURROUND : INPUT_STEREO);
                    commandOk = true;
                    break;
                case 'D':
                    printStatus();
                    commandOk = true;
                    break;
                default:
                    break;
            }

            if (commandOk) {
                Serial.println("OK");
            }
        }

        clearSerialBuffer();
        clearSerialConsole();
    }
}

bool checkHeader() {
    byte header[] = {'H','T','5','5','0'};

    for (byte i = 0; i < SERIAL_HEADER_LENGTH; i++) {
        if (serialBuffer[i] != header[i]) {
            return false;
        }
    }

    return true;
}

bool isOn() {
    if (serialBuffer[SERIAL_VALUE_POS] == '1') {
        return true;
    } else {
        return false;
    }
}

byte getChannel() {
    switch (serialBuffer[SERIAL_VALUE_POS]) {
        case '0':
            return CHAN_ALL;
        case '1':
            return CHAN_FL;
        case '2':
            return CHAN_FR;
        case '3':
            return CHAN_RL;
        case '4':
            return CHAN_RR;
        case '5':
            return CHAN_CEN;
        case '6':
            return CHAN_SW;
    }

    return UNKNOWN_BYTE;
}

byte getNumber() {
    char value[2] = {(char)serialBuffer[SERIAL_VALUE_POS + 1], (char)serialBuffer[SERIAL_VALUE_POS + 2]};
    return atoi(value);
}

void printStatus() {
    Serial.print("Power: ");
    Serial.println(paramPower);
    Serial.print("Input: ");
    Serial.println(paramInput);
    Serial.println("Volumes:");
    Serial.print("  Global: ");
    Serial.println(paramVolumes[CHAN_ALL]);
    Serial.print("  Front-Left: ");
    Serial.println(paramVolumes[CHAN_FL]);
    Serial.print("  Front-Right: ");
    Serial.println(paramVolumes[CHAN_FR]);
    Serial.print("  Rear-Left: ");
    Serial.println(paramVolumes[CHAN_RL]);
    Serial.print("  Rear-Right: ");
    Serial.println(paramVolumes[CHAN_RR]);
    Serial.print("  Center: ");
    Serial.println(paramVolumes[CHAN_CEN]);
    Serial.print("  Subwoofer: ");
    Serial.println(paramVolumes[CHAN_SW]);
    Serial.print("Muting: ");
    Serial.println(paramMute);
    Serial.print("Enhancement: ");
    Serial.println(paramEnhancement);
    Serial.print("Mixed channel boost: ");
    Serial.println(paramMixChBoost);
}

void clearSerialConsole() {
    Serial.write(27);
    Serial.print("[2J");
    Serial.write(27);
    Serial.print("[H");
}

void clearSerialBuffer() {
    for (byte i = 0; i < 16; i++) {
        serialBuffer[i] = '\0';
    }
    serialLength = 0;
}
