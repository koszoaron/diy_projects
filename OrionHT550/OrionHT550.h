// Only modify this file to include
// - function definitions (prototypes)
// - include files
// - extern variable definitions
// In the appropriate section

#ifndef OrionHT550_H_
#define OrionHT550_H_
#include "Arduino.h"
//add your includes for the project OrionHT550 here
#include "Encoder.h"
#include "IRremote.h"
#include "Wire.h"
#include "twi.h"

//pt2323 definitions
#define PT2323_ADDRESS      74
#define PT2323_IN6CH        0xC7
#define PT2323_INST1        0xCB
#define PT2323_INST2        0xCA
#define PT2323_INST3        0xC9
#define PT2323_INST4        0xC8
#define PT2323_SURRENH_ON   0xD0
#define PT2323_SURRENH_OFF  0xD1
#define PT2323_MIXCHAN_0DB  0x90
#define PT2323_MIXCHAN_6DB  0x91
#define PT2323_FL_MUTE      0xF1
#define PT2323_FL_UNMUTE    0xF0
#define PT2323_FR_MUTE      0xF3
#define PT2323_FR_UNMUTE    0xF2
#define PT2323_RL_MUTE      0xF9
#define PT2323_RL_UNMUTE    0xF8
#define PT2323_RR_MUTE      0xFB
#define PT2323_RR_UNMUTE    0xFA
#define PT2323_CEN_MUTE     0xF5
#define PT2323_CEN_UNMUTE   0xF4
#define PT2323_SW_MUTE      0xF7
#define PT2323_SW_UNMUTE    0xF6
#define PT2323_ALL_MUTE     0xFF
#define PT2323_ALL_UNMUTE   0xFE

//pt2258 definitions
#define PT2258_ADDRESS      68
#define PT2258_FL_1DB       0x90
#define PT2258_FL_10DB      0x80
#define PT2258_FR_1DB       0x50
#define PT2258_FR_10DB      0x40
#define PT2258_RL_1DB       0x70
#define PT2258_RL_10DB      0x60
#define PT2258_RR_1DB       0xB0
#define PT2258_RR_10DB      0xA0
#define PT2258_CEN_1DB      0x10
#define PT2258_CEN_10DB     0x00
#define PT2258_SW_1DB       0x30
#define PT2258_SW_10DB      0x20
#define PT2258_ALLCH_1DB    0xE0
#define PT2258_ALLCH_10DB   0xD0
#define PT2258_ALLCH_MUTE   0xF9
#define PT2258_ALLCH_UNMUTE 0xF8

//general constants
#define CHAN_ALL    0
#define CHAN_FL     1
#define CHAN_FR     2
#define CHAN_RL     3
#define CHAN_RR     4
#define CHAN_CEN    5
#define CHAN_SW     6
#define CHAN_MUTE   7
#define INPUT_STEREO    0
#define INPUT_SURROUND  1
#define MIN_ATTENUATION         0
#define MAX_ATTENUATION         79
#define SERIAL_SPEED            9600
#define INITIAL_ENCODER_POS     -999
#define UNKNOWN_VALUE           -1
#define UNKNOWN_BYTE            99
#define ON  1
#define OFF 0

//defaults
#define DEFAULT_POWER       0
#define DEFAULT_VOLUME      40
#define DEFAULT_INPUT       0
#define DEFAULT_MUTE        0
#define DEFAULT_ENHANCEMENT 0
#define DEFAULT_MIXCH_BOOST 0

//serial constants
#define SERIAL_HEADER_LENGTH    5
#define SERIAL_COMMAND_POS      5
#define SERIAL_VALUE_POS        6

//Arduino pins
#define ENC_A       2
#define ENC_B       3
#define LED_CLK     5
#define LED_DATA    6
#define IR          7
#define LED_EN1     8
#define LED_EN2     9
#define BTN_COM     11
#define MUTE_NEG    12

//Infrared codes
#define IR_VOLDOWN  0x1FE50AF
#define IR_VOLUP    0x1FEF807
#define IR_POWER    0x1FE48B7
#define IR_INPUTSEL 0x1FE609F
#define IR_RESET    0x1FE7887
#define IR_BASSDOWN 0x1FEE01F
#define IR_BASSUP   0x1FE906F
#define IR_REPEAT   0xFFFFFFFF

//7-Segment codes
#define SSEG_0      B01000001
#define SSEG_1      B11100111
#define SSEG_2      B01010010
#define SSEG_3      B01100010
#define SSEG_4      B11100100
#define SSEG_5      B01101000
#define SSEG_6      B01001000
#define SSEG_7      B11100011
#define SSEG_8      B01000000
#define SSEG_9      B01100000
#define SSEG_DASH   B11111110
#define SSEG_DOT    B01000000

//end of add your includes here
#ifdef __cplusplus
extern "C" {
#endif
    void loop();
    void setup();
    void initAmp();
    void displayChar();
    void displayNumber(uint8_t num);
    void setInput(byte input);
    void setSurroundEnhancement(bool enhancement);
    void setMixerChannel6Db(bool mix6db);
    void setMute(bool mute);
    void increaseVolume();
    void decreaseVolume();
    void setGlobalVolume(byte volume);
    void setChannelVolume(byte channel, byte volume);
    void pt2323(byte command);
    void pt2258(byte channel, byte value);
    void handleSerial();
    bool checkHeader();
    bool isOn();
    byte getChannel();
    byte getNumber();
    void printStatus();
    void clearSerialConsole();
    void clearSerialBuffer();
#ifdef __cplusplus
} // extern "C"
#endif

//add your function definitions for the project OrionHT550 here

//Do not add code below this line
#endif /* OrionHT550_H_ */
