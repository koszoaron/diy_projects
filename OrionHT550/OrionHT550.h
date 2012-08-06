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
#define PT2323_ADDRESS 74
#define IN_6CH              0xC7
#define IN_ST1              0xCB
#define IN_ST2              0xCA
#define IN_ST3              0xC9
#define IN_ST4              0xC8
#define SURRENH_ON          0xD0
#define SURRENH_OFF         0xD1
#define MIXCHAN_0DB         0x90
#define MIXCHAN_6DB         0x91
#define FRONTLEFT_MUTE      0xF1
#define FRONTLEFT_UNMUTE    0xF0
#define FRONTRIGHT_MUTE     0xF3
#define FRONTRIGHT_UNMUTE   0xF2
#define REARLEFT_MUTE       0xF9
#define REARLEFT_UNMUTE     0xF8
#define REARRIGHT_MUTE      0xFB
#define REARRIGHT_UNMUTE    0xFA
#define CENTER_MUTE         0xF5
#define CENTER_UNMUTE       0xF4
#define SUBWOOFER_MUTE      0xF7
#define SUBWOOFER_UNMUTE    0xF6
#define ALLCH_MUTE          0xFF
#define ALLCH_UNMUTE        0xFE

//pt2258 definitions
#define FRONTLEFT_1DB       0x90
#define FRONTLEFT_10DB      0x80
#define FRONTRIGHT_1DB      0x50
#define FRONTRIGHT_10DB     0x40
#define REARLEFT_1DB        0x70
#define REARLEFT_10DB       0x60
#define REARRIGHT_1DB       0xB0
#define REARRIGHT_10DB      0xA0
#define CENTER_1DB          0x10
#define CENTER_10DB         0x00
#define SUBWOOFER_1DB       0x30
#define SUBWOOFER_10DB      0x20
#define ALLCH_1DB           0xE0
#define ALLCH_10DB          0xD0
#define ALLCH_MUTE2         0xF9
#define ALLCH_UNMUTE2       0xF8

//end of add your includes here
#ifdef __cplusplus
extern "C" {
#endif
    void loop();
    void setup();
#ifdef __cplusplus
} // extern "C"
#endif

//add your function definitions for the project OrionHT550 here

//Do not add code below this line
#endif /* OrionHT550_H_ */
