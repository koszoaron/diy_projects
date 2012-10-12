// Do not remove the include below
#include "OrionHT550.h"

const byte numbers[10] = { SSEG_0, SSEG_1, SSEG_2, SSEG_3, SSEG_4, SSEG_5, SSEG_6, SSEG_7, SSEG_8, SSEG_9 };

byte paramPower = DEFAULT_POWER;
byte paramInput = DEFAULT_INPUT;
byte paramMute = DEFAULT_MUTE;
byte paramEnhancement = DEFAULT_ENHANCEMENT;
byte paramMixChBoost = DEFAULT_MIXCH_BOOST;
byte paramMainVolume = DEFAULT_VOLUME;
byte paramVolumeOffsets[6] = {DEFAULT_OFFSET, DEFAULT_OFFSET, DEFAULT_OFFSET, DEFAULT_OFFSET, DEFAULT_OFFSET, DEFAULT_OFFSET};

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
    pinMode(ONBOARD_LED, OUTPUT);

    displayChar();
    delay(1000);
    initAmp();
}

void initAmp() {
    /* mute all channels */
    setMute(ON);

    /* wait 2 seconds for the amp to settle
     * meanwhile load all parameters from EEPROM */
    restoreParameters();
    delay(2000);

    /* set the states defined in the parameters */
    setInput(paramInput);
    setSurroundEnhancement(paramEnhancement);
    setMixerChannel6Db(paramMixChBoost);
    setMute(paramMute);

    applyGlobalVolume();
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
            increaseVolume();
        } else if (encNew < encPosition && encNew % 4 != 0) {
            decreaseVolume();
        }
        encPosition = encNew;
    }

    if (irReceiver.decode(&results)) {
        handleInfrared(results.value);
        irReceiver.resume();
    }

    displayNumber(paramMainVolume);

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

void setSurroundEnhancement(byte enhancement) {
    if (enhancement) {
        pt2323(PT2323_SURRENH_ON);
    } else {
        pt2323(PT2323_SURRENH_OFF);
    }
}

void setMixerChannel6Db(byte mix6db) {
    if (mix6db) {
        pt2323(PT2323_MIXCHAN_6DB);
    } else {
        pt2323(PT2323_MIXCHAN_0DB);
    }
}

void setMute(byte mute) {
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
    if (paramMainVolume < MAX_ATTENUATION) {
        paramMainVolume++;
        applyGlobalVolume();
    }
}

void decreaseVolume() {
    if (paramMainVolume > MIN_ATTENUATION) {
        paramMainVolume--;
        applyGlobalVolume();
    }
}

void applyGlobalVolume() {
    for (byte i = OFFSET_FL; i <= OFFSET_SW; i++) {
        int channelVolume = paramMainVolume + paramVolumeOffsets[i] - VOLUME_OFFSET_HALF;
        if (channelVolume < MIN_ATTENUATION) {
            channelVolume = MIN_ATTENUATION;
        }
        if (channelVolume > MAX_ATTENUATION) {
            channelVolume = MAX_ATTENUATION;
        }
        setChannelVolume(i+1, channelVolume);
    }
}

void setChannelVolume(byte channel, byte volume) {
    if (volume >= MIN_ATTENUATION && volume <= MAX_ATTENUATION) {
        byte attenuation = MAX_ATTENUATION - volume;
        pt2258(channel, attenuation);
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
            x10 += PT2258_RR_10DB;
            break;
        case CHAN_MUTE:
            if (value == 0) {
                x10 = x1 = PT2258_ALLCH_MUTE;
            } else {
                x10 = x1 = PT2258_ALLCH_UNMUTE;
            }
            break;
    }

    Wire.beginTransmission(PT2258_ADDRESS);
    Wire.write(x10);
    Wire.write(x1);
    Wire.endTransmission();
}

void handleSerial() {
    byte c;
    bool eol = false;

    while (Serial.available() > 0) {
        c = Serial.read();
        if (c == 13 || c == 10 || serialLength >= 16) {
            eol = true;
        } else {
            serialBuffer[serialLength] = c;
            serialLength++;
        }
    }

    if (eol) {
        bool commandOk = false;
        byte chan = UNKNOWN_BYTE;
        if (checkHeader()) {
            switch (serialBuffer[SERIAL_COMMAND_POS]) {
                case 'P':
                    paramPower = (isOn() ? ON : OFF);
                    commandOk = true;
                    break;
                case 'V':
                    chan = getChannel();
                    if (chan == CHAN_ALL) {  //mainVolume is between 0 and 79
                        paramMainVolume = getNumber();
                    } else {  //channel offset is between 0 and 30 - translate this to -15 and 15
                        paramVolumeOffsets[chan-1] = getNumber();
                    }
                    applyGlobalVolume();
                    commandOk = true;
                    break;
                case 'E':
                    paramEnhancement = (isOn() ? ON : OFF);
                    setSurroundEnhancement(paramEnhancement);
                    commandOk = true;
                    break;
                case 'B':
                    paramMixChBoost = (isOn() ? ON : OFF);
                    setMixerChannel6Db(paramMixChBoost);
                    commandOk = true;
                    break;
                case 'M':
                    paramMute = (isOn() ? ON : OFF);
                    setMute(paramMute);
                    commandOk = true;
                    break;
                case 'S':
                    if (isOn()) {
                        Serial.print("Store... ");
                        storeParameters();
                        commandOk = true;
                    }
                    break;
                case 'R':
                    if (isOn()) {
                        Serial.print("Restore... ");
                        restoreParameters();
                        applyGlobalVolume();
                        commandOk = true;
                    }
                    break;
                case 'I':
                    paramInput = (isOn() ? INPUT_SURROUND : INPUT_STEREO);
                    setInput(paramInput);
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
    }
}

void handleInfrared(unsigned long decodedValue) {
    blinkLed();
    switch (decodedValue) {
        case IR_VOLDOWN:
            decreaseVolume();
            break;
        case IR_VOLUP:
            increaseVolume();
            break;
        case IR_POWER:
            paramMute = (paramMute ? OFF : ON);
            setMute(paramMute);
            break;
        case IR_INPUTSEL:
            paramInput = (paramInput ? INPUT_STEREO : INPUT_SURROUND);
            setInput(paramInput);
            break;
        case IR_RESET:  //restore from EEPROM
            restoreParameters();
            break;
        case IR_BASSDOWN:  //toggle enhancement
            paramEnhancement = (paramEnhancement ? OFF : ON);
            setSurroundEnhancement(paramEnhancement);
            break;
        case IR_BASSUP:  //toggle mixchboost
            paramMixChBoost = (paramMixChBoost ? OFF : ON);
            setMixerChannel6Db(paramMixChBoost);
            break;
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
    Serial.print("Main volume: ");
    Serial.println(paramMainVolume);
    Serial.println("Volume offsets [0-30]: ");
    Serial.print("  FL: ");
    Serial.println(paramVolumeOffsets[OFFSET_FL] - VOLUME_OFFSET_HALF);
    Serial.print("  FR: ");
    Serial.println(paramVolumeOffsets[OFFSET_FR] - VOLUME_OFFSET_HALF);
    Serial.print("  RL: ");
    Serial.println(paramVolumeOffsets[OFFSET_RL] - VOLUME_OFFSET_HALF);
    Serial.print("  RR: ");
    Serial.println(paramVolumeOffsets[OFFSET_RR] - VOLUME_OFFSET_HALF);
    Serial.print("  CE: ");
    Serial.println(paramVolumeOffsets[OFFSET_CEN] - VOLUME_OFFSET_HALF);
    Serial.print("  SW: ");
    Serial.println(paramVolumeOffsets[OFFSET_SW] - VOLUME_OFFSET_HALF);
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

void storeParameters() {
    EEPROM.write(ADDR_INPUT, paramInput);
    EEPROM.write(ADDR_MUTE, paramMute);
    EEPROM.write(ADDR_ENHANCEMENT, paramEnhancement);
    EEPROM.write(ADDR_MIXCHBOOST, paramMixChBoost);
    EEPROM.write(ADDR_MAINVOLUME, paramMainVolume);
    EEPROM.write(ADDR_OFFSET_FL, paramVolumeOffsets[OFFSET_FL]);
    EEPROM.write(ADDR_OFFSET_FR, paramVolumeOffsets[OFFSET_FR]);
    EEPROM.write(ADDR_OFFSET_RL, paramVolumeOffsets[OFFSET_RL]);
    EEPROM.write(ADDR_OFFSET_RR, paramVolumeOffsets[OFFSET_RR]);
    EEPROM.write(ADDR_OFFSET_CEN, paramVolumeOffsets[OFFSET_CEN]);
    EEPROM.write(ADDR_OFFSET_SUB, paramVolumeOffsets[OFFSET_SW]);
}

void restoreParameters() {
    paramInput = EEPROM.read(ADDR_INPUT);
    paramMute = EEPROM.read(ADDR_MUTE);
    paramEnhancement = EEPROM.read(ADDR_ENHANCEMENT);
    paramMixChBoost = EEPROM.read(ADDR_MIXCHBOOST);
    paramMainVolume = EEPROM.read(ADDR_MAINVOLUME);
    paramVolumeOffsets[OFFSET_FL] = EEPROM.read(ADDR_OFFSET_FL);
    paramVolumeOffsets[OFFSET_FR] = EEPROM.read(ADDR_OFFSET_FR);
    paramVolumeOffsets[OFFSET_RL] = EEPROM.read(ADDR_OFFSET_RL);
    paramVolumeOffsets[OFFSET_RR] = EEPROM.read(ADDR_OFFSET_RR);
    paramVolumeOffsets[OFFSET_CEN] = EEPROM.read(ADDR_OFFSET_CEN);
    paramVolumeOffsets[OFFSET_SW] = EEPROM.read(ADDR_OFFSET_SUB);
}

void blinkLed() {
    digitalWrite(ONBOARD_LED, HIGH);
    delay(50);
    digitalWrite(ONBOARD_LED, LOW);
}
