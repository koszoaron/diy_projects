// 5.1 amplifier system redesign
// by Neoxy <http://www.neoxy-yx.blogspot.com>
// matjaz.behek@gmail.com

// Special thanks to all the authors of included libraries

// Created 20 April 2012

/* Circuit:
 * LCD RS pin to digital pin 10
 * LCD Enable pin to digital pin 9
 * LCD D4 pin to digital pin 8
 * LCD D5 pin to digital pin 7
 * LCD D6 pin to digital pin 6
 * LCD D7 pin to digital pin 5
 
 * I2C SCL to analog pin 5
 * I2C SDA to analog pin 4
 
 * TX to digital pin 0
 * RX to digital pin 1
 
 * IR to digital pin 11
 
 * Relay to digital pin 4
 
 * Mute to analog 3
 
 * LED light and backlight to analog 2
 
 * Volume encoder I pin to digital pin 2  
 * Volume encoder II pin to digital pin 3
 * Button 1 to analog pin 0
 * Button 2 to analog pin 1
 * Button 3 to digital pin 12 
 * Button 4 to digital pin 13
 
 */

//******************************************************************************
// GLOBALS, FLAGS, INCLUDES, INTTERUPT FUNCTIONS  
//******************************************************************************

// includes
#include <Wire.h>                        // I2C library    
#include <LiquidCrystal.h>               // LCD library   
#include <IRremote.h>                    // IR library                   
#include <PinChangeInt.h>                // Interrupt library    
#include <AdaEncoder.h>                  // Encoder library
#include <EEPROM.h>                      // Eeprom library    

// delay defines (these are delays that don't slow down processor)
#define IR_WAIT       3500               // ir wait counts  
#define LCD_WAIT      100000             // lcd wait counts
#define INT_WAIT      3000               // interrupt debounce wait counts
#define TEMP_LCD_WAIT 50000              // temp lcd show wait counts 
#define volDELAY      50                 // this one is used for normal delay(); 

// IR mapped buttons
#define rMUTE  0x68b5f    // IR remote button MUTE (emulate button MUTE)
#define rON    0xa8b5f    // IR remote button ON (emulate button ON)
#define rCH    0xc8b5f    // IR remote button CHANNEL++
#define rMODE  0x28b5f    // IR remote button MODE++
#define rBASSP 0x9ebd0    // IR remote button BASS++
#define rBASSM 0x98bd0    // IR remote button BASS-- 
#define rREARP 0x8cb5f    // IR remote button REAR++
#define rREARM 0xcb5f     // IR remote button REAR-- 
#define rCENP  0x2cb5f    // IR remote button CENTER++
#define rCENM  0xccb5f    // IR remote button CENTER--
#define rVOLP  0x490      // IR remote button VOLUME++ (emulate ENCODER++)
#define rVOLM  0xc90      // IR remote button VOLUME-- (emulate ENCODER--)
#define rLCD   0x2ab5f    // IR remote button LCD ON/OFF
#define rENH   0x18bd0    // IR remote button ENHANCE ACTIVE/DISABLED
#define rBOOST 0x70b5f    // IR remote button BOOST ACTIVE/DISABLED
#define rMENU  0xd8b5f    // IR remote button MENU (emulate button MENU)
#define rOK    0xb0b5f    // IR remote button OK (emulate button OK)

// IR globals
int RECV_PIN = 11;        // Receive pin
IRrecv irrecv(RECV_PIN);  // Set receive
decode_results results;   // Received IR codes   

// Serial communication globals and flags
int bufferX[16] = {'\0','\0','\0','\0','\0','\0','\0','\0','\0','\0','\0','\0','\0','\0','\0','\0'};  // global buffer for received chars
int xyz = 0;                      // BufferX size count    
int kontrolaCMD = 0;              // Control flag for BufferX read
char *code = "AMP1";              // Serial starting code for our Amplifier

// global varaiables for LCD
LiquidCrystal lcd(10, 9, 8, 7, 6, 5);   // LCD pins
byte lcd_flag = 0;                      // flag for lcd update        

// These global values will be red from EEPROM 
byte volume = 0;                  // volume level 0-79
byte FL = 128;                    // front left volume level correct
byte FR = 128;                    // front right volume level correct
byte CE = 128;                    // center volume level correct
byte SU = 128;                    // sub left volume level correct
byte RL = 128;                    // rear left volume level correct    
byte RR = 128;                    // rear right volume level correct
byte CH = 0;                    // Selected channel 
byte enhance = 1;               // enhance select 
byte amp = 0;                   // +6dB boost select
byte mute = 0;                  // mute select
byte unit = 0;                  // unit on/stand-by state
byte mode = 0;                  // speaker mode

byte external_buttons = 1;              // enable external buttons
byte external_remote = 1;               // enable remote
byte enable_lcd = 1;                    // enable LCD (lcd on/off)
//----------------------------------------------------------------------

// other global values and flags
byte int1 = 0;                 // interrupt flag for button 1 (on/off)
byte int2 = 0;                 // interrupt flag for button 2 (mute)
byte int3 = 0;                 // interrupt flag for button 3 (menu)     
byte int4 = 0;                 // interrupt flag for button 4 (ok)
byte button_menus = 0;         // global variable for  main menu
int set_menu = 0;              // global variable for sub_menu 
int temp_menu = 0;             // global temp menu varaiable (for quick status)
int set_corrections_menu = 0;       // global variable for sub_menu of corrections
byte read_value = 0;                // read encoder flag value in menu
byte do_this = 0;                   // select menu flag
byte do_correct = 0;                // select correct flag
int temp1 = external_buttons;               // flag for enable buttons
int temp2 = external_remote;                // flag for enable remote
int temp3 = enable_lcd;                     // flag for enable lcd
int temp4 = unit;                           // flag for unit on/off

unsigned long counter_lcd = LCD_WAIT;       // delay counter for lcd change 
unsigned int ir_counter = IR_WAIT;          // delay counter for ir receive
unsigned int int_counter = INT_WAIT;        // delay counter for interrupt (debounce)
unsigned long temp_lcd_counter = TEMP_LCD_WAIT; // delay counter for temp LCD status show
byte debounce = 1;                          // debounce flag (when 1 debounce over, we can read value again)  

int encoder_value = 0;          // value for encoder
int8_t clicks = 0;              // encoder clicks   
char id = 0;                    // encoder ID       

//------------------------------------------------------------
// button interrupt actions (set flag to 1)
void but1func()         // set interrupt flag on button 1
{
  if(external_buttons == 1) int1 = 1;  // if buttons enabled, set flag (ON/OFF)
}

void but2func()         // set interrupt flag on button 2 (MUTE)
{
  if(external_buttons == 1) int2 = 1;
}

void but3func()         // set interrupt flag on button 3 (MENU)
{
  if(external_buttons == 1) int3 = 1;
}

void but4func()         // set interrupt flag on button 4 (OK)
{
  if(external_buttons == 1) int4 = 1;
}
//------------------------------------------------------------

//******************************************************************************
// SETUP AND POWER ON DEFAULTS
//******************************************************************************
void setup()
{
  if(EEPROM.read(16) != 23)    // very small chance that unknown eeprom value would be 23 :) (lucky gues I would say) 
  {                            // this will be done only once, this is to store default values
     EEPROM.write(16,23);       // on first power up, so we don't get unknown invalid eeprom values
     write_to_eeprom();
  }
    
  read_from_eeprom();   // load values from eeprom 

  pinMode(4, OUTPUT);     // as output (relay for amplifier power)
  pinMode(A3, OUTPUT);    // as output (mute)
  pinMode(A2, OUTPUT);    // as output (led lights) 

  digitalWrite(4, LOW);    // set 0  (relay for amplifier power) 
  digitalWrite(A3, LOW);   // set 0  (mute)
  digitalWrite(A2, LOW);   // set 0  (led lights)

  // attach interrupt, pull-up, on FALLING (from HIGH to LOW) 
  pinMode(A0, INPUT); 
  digitalWrite(A0, HIGH);            // set A0 input intterupt (ON/OFF)
  PCintPort::attachInterrupt(A0, &but1func, FALLING);
  pinMode(A1, INPUT); 
  digitalWrite(A1, HIGH);            // set A1 input intterupt (MUTE)
  PCintPort::attachInterrupt(A1, &but2func, FALLING);
  pinMode(12, INPUT); 
  digitalWrite(12, HIGH);            // set 12 input intterupt (MENU)
  PCintPort::attachInterrupt(12, &but3func, FALLING);
  pinMode(13, INPUT); 
  digitalWrite(13, HIGH);            // set 13 input intterupt (OK)
  PCintPort::attachInterrupt(13, &but4func, FALLING);

  AdaEncoder::addEncoder('a',2 ,3);  // encoder on pins 2 and 3

  delay(1000);          // wait for voltage stabilisation  
  Wire.begin();         // join I2C
  Serial.begin(9600);   // start serial communication
  irrecv.enableIRIn();  // start receiver
  lcd.begin(16, 2);     // start LCD
  lcd.noCursor();       // turn off cursor  
  pt2323(1);            // Stereo input 1 (so we don't leave our PT chip floating)
  pt2258(79, 0);        // -79dB All CH (mute)

  // From here the program begins
  set_unit();            // turn on/off with default settings
}

//******************************************************************************
// MAIN LOOP with timeout operation
//******************************************************************************
void loop()
{
  checkSerial();              // check for serial commands    

  if(external_remote == 1)    // if remote enabled 
  {
    checkIR();                // check for IR commands if enabled 
    if(ir_counter == IR_WAIT)   // just before timeout 
    {
      irrecv.resume();          // listen for new commands
      ir_counter++;             // count +1 to wait in next statement
    }  
    else if(ir_counter == IR_WAIT+1)    // here IR waits for a counter reset and values are checked 
    {
      // Do nothing
    }  
    else
    {
      ir_counter++;             // count to timeout   
    }
  }

  if(external_remote == 1 || external_buttons == 1) checkButtons();     // check for button commands if at least one enabled 

  if(temp_menu >= 3)        // if temporary LCD info is needed
  {
    button_menus = temp_menu;  // display info we need (just for some time)
    temp_menu = 0;          // reset value 
  }

  if(enable_lcd == 1 && lcd_flag == 1 && unit == 1)  // update lcd if unit is on, LCD is enabled and if an update is needed
  {   
    lcd_led_enable(1);        // turn on LCD
    update_lcd();             // update LCD info if enabled and lcd_flag set 
    lcd_flag = 0;             // reset flag 
  }
  if(enable_lcd == 0 && lcd_flag == 1 && unit == 1)    // show lcd for a shord period of time, if unit is on and if update is needed
  { 
    lcd_led_enable(1);        // turn on LCD and LEDs
    counter_lcd = 0;          // reset counter to start again  
    update_lcd();             // update LCD info 
    lcd_flag = 0;             // reset flag for LCD update
  }

  if(counter_lcd == LCD_WAIT && enable_lcd == 0)    // lcd timeout 
  {
    lcd_led_enable(0);                              // turn off display                
    counter_lcd++;                                  // count +1 to go in next statement where we will wait
  }
  else if(counter_lcd == LCD_WAIT+1)               // here counter will be stuck until called again (set to 0)     
  {
    // do nothing
  }
  else counter_lcd++;                               // counter_lcd++


  if(int_counter == INT_WAIT)       // on timeout enable reading of buttons (for debounce)   
  {
    debounce = 1;      // debounce over
    int_counter++;     // go in next statement where we will wait
  }
  else if(int_counter == INT_WAIT + 1)  // here counter is stuck until called again (set to 0)
  {
    // do nothing
  }
  else 
  {
    int_counter++;
  }

  if(temp_lcd_counter == TEMP_LCD_WAIT)       // on timeout show regular INFO on LCD, until then show temp INFO  
  {
    button_menus = 0;         // go in main menu (reset) from temp_menu
    temp_lcd_counter++;       // count +1 
    lcd_flag = 1;             // update LCD info
  }
  else if(temp_lcd_counter == TEMP_LCD_WAIT + 1)  // here we wait for another call
  {
    // do nothing
  }
  else 
  {
    temp_lcd_counter++;
  }
}

//******************************************************************************
// PT2323 AND PT2258 COMMAND SET 
//******************************************************************************
//------------------------------------------------------------------------------
// 2CH to 6CH translator and input selector command set
//------------------------------------------------------------------------------
void pt2323(byte command)
{
  Wire.beginTransmission(74);   // transmit to device 0x94(hex) -> 148(dec)(addressing is 7-bit) -> 148/2
  switch(command)
  {
  case 0:
    Wire.send(0xc7);   // 6-ch input
    break;
  case 4:
    Wire.send(0xc8);   // stereo 4 input
    break;
  case 3:
    Wire.send(0xc9);   // stereo 3 input
    break;
  case 2:
    Wire.send(0xca);   // stereo 2 input
    break;
  case 1:
    Wire.send(0xcb);   // stereo 1 input
    break;
  case 5:
    Wire.send(0xd0);   // enhance active
    break;
  case 6:
    Wire.send(0xd1);   // enhance disable
    break;
  case 7:
    Wire.send(0x90);   // 0dB setup
    break;
  case 8:
    Wire.send(0x91);   // +6dB setup
    break;
  case 9:
    Wire.send(0xf0);   // FL mute disabled
    break;
  case 10:
    Wire.send(0xf1);   // FL mute
    break;
  case 11:
    Wire.send(0xf2);   // FR mute disabled
    break;
  case 12:
    Wire.send(0xf3);   // FR mute
    break;
  case 13:
    Wire.send(0xf4);   // CE mute disabled
    break;
  case 14:
    Wire.send(0xf5);   // CE mute
    break;
  case 15:
    Wire.send(0xf6);   // SU mute disabled
    break;
  case 16:
    Wire.send(0xf7);   // SU mute
    break;
  case 17:
    Wire.send(0xf8);   // SL mute disabled
    break;
  case 18:
    Wire.send(0xf9);   // SL mute
    break;
  case 19:
    Wire.send(0xfa);   // SR mute disabled
    break;
  case 20:
    Wire.send(0xfb);   // SR mute
    break;
  case 21:
    Wire.send(0xfe);   // All CH mute disabled
    break;
  default:
    Wire.send(0xff);   // All CH mute
    break; 
  }
  Wire.endTransmission();     // stop transmitting  
}

//------------------------------------------------------------------------------
// Volume controller IC command set
//------------------------------------------------------------------------------
void pt2258(byte command, byte ch)  // send volume level commands
{
  byte x10;
  byte x1; 

  if(command >= 10)
  {
    x10 = command/10;        // set decade step
    x1 = command % 10;       // set step
  }
  else                       // set step       
  {
    x1 = command;
    x10 = 0;
  }

  switch(ch)                 // which channel to command 
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
    if(command == 0) x10, x1 = 0xf8;   // mute off
    else x10, x1 = 0xf9;               // mute on       
    break;
  }

  for(int i = 0; i <= 2; i++)  // repeat 2x (had some unknown issues when transmitted only once)
  {  
    Wire.beginTransmission(68); // transmit to device 0x88(hex) -> 136(dec)(addressing is 7-bit) -> 136/2
    Wire.send(x10);             // send decade step         
    Wire.send(x1);              // send step
    Wire.endTransmission();     // stop transmitting   
  }  
}

//******************************************************************************
// AUDIO SETTINGS
//******************************************************************************
//------------------------------------------------------------------------------
// Set volume in steps (soft volume change)
//------------------------------------------------------------------------------
void set_volume(byte begin_from, byte to_level)
{ 
  // calculate corrects 
  int var1 = 0;    // FL
  int var2 = 0;    // FR
  int var3 = 0;    // CE
  int var4 = 0;    // SU
  int var5 = 0;    // RR
  int var6 = 0;    // RL

  var1 = FL-128;
  var2 = FR-128;
  var3 = CE-128;
  var4 = SU-128;
  var5 = RR-128;
  var6 = RL-128;

  // set volume + corrects
  int y;

  if(begin_from < to_level)          // increse volume
  {
    for(y = begin_from; y < to_level; y++)
    {  
      if((0 <= (79 - (y + var1))) && (79 >= (79 - (y + var1))))  pt2258(79 - (y + var1), 1);  // send value if in 0-79 range
      if((0 <= (79 - (y + var2))) && (79 >= (79 - (y + var2))))  pt2258(79 - (y + var2), 2);  
      if((0 <= (79 - (y + var3))) && (79 >= (79 - (y + var3))))  pt2258(79 - (y + var3), 3);
      if((0 <= (79 - (y + var4))) && (79 >= (79 - (y + var4))))  pt2258(79 - (y + var4), 4);
      if((0 <= (79 - (y + var5))) && (79 >= (79 - (y + var5))))  pt2258(79 - (y + var5), 5);
      if((0 <= (79 - (y + var6))) && (79 >= (79 - (y + var6))))  pt2258(79 - (y + var6), 6);

      delay(volDELAY);  // delay for a soft transition of volume
    }
  } 
  else if(begin_from > to_level)      // decrease volume
  {
    for(y = begin_from; y > to_level; y--)
    {
      if((0 <= (79 - (y + var1))) && (79 >= (79 - (y + var1))))  pt2258(79 - (y + var1), 1);  // send value if in 0-79 range
      if((0 <= (79 - (y + var2))) && (79 >= (79 - (y + var2))))  pt2258(79 - (y + var2), 2);  
      if((0 <= (79 - (y + var3))) && (79 >= (79 - (y + var3))))  pt2258(79 - (y + var3), 3);
      if((0 <= (79 - (y + var4))) && (79 >= (79 - (y + var4))))  pt2258(79 - (y + var4), 4);
      if((0 <= (79 - (y + var5))) && (79 >= (79 - (y + var5))))  pt2258(79 - (y + var5), 5);
      if((0 <= (79 - (y + var6))) && (79 >= (79 - (y + var6))))  pt2258(79 - (y + var6), 6);

      delay(volDELAY);
    }
  }
  else          // same volume just corrects, here we don't need soft transition
  {
    var1 = var1 + volume;
    if(var1 < 0) var1 = 0;
    if(var1 > 79) var1 = 79;
    var2 = var2 + volume;
    if(var2 < 0) var2 = 0;
    if(var2 > 79) var2 = 79;
    var3 = var3 + volume;
    if(var3 < 0) var3 = 0;
    if(var3 > 79) var3 = 79;
    var4 = var4 + volume;
    if(var4 < 0) var4 = 0;
    if(var4 > 79) var4 = 79;
    var5 = var5 + volume;
    if(var5 < 0) var5 = 0;
    if(var5 > 79) var5 = 79;
    var6 = var6 + volume;
    if(var6 < 0) var6 = 0;
    if(var6 > 79) var6 = 79;

    // send new values for each channel
    pt2258(79 - var1, 1);
    pt2258(79 - var2, 2);
    pt2258(79 - var3, 3);
    pt2258(79 - var4, 4);
    pt2258(79 - var5, 5);
    pt2258(79 - var6, 6);
  }
  if(to_level >= 79) to_level = 79;    // do not exceed 79
  if(to_level <= 0)  to_level = 0;     // do not go in -
  volume = to_level;
  if(volume == 0) pt2258(79,0);        // mute all channels  (otherwise you could hear volume of + correct)
}

//------------------------------------------------------------------------------
// Set speaker mode
//------------------------------------------------------------------------------
void set_mode()    // set speaker mode
{
  switch(mode)
  {
  case 1:                      // 2.1 mode
    pt2323(14);  // disable CE 
    pt2323(18);  // disable RL
    pt2323(20);  // disable RR
    break;
  case 2:                      // 3.1 mode
    pt2323(13);  // enable CE
    pt2323(18);  // disable RL
    pt2323(20);  // disable RR
    break;
  case 3:                      // 4.1 mode
    pt2323(14);  // disable CE
    pt2323(17);  // enable RL
    pt2323(19);  // enable RR
    break;
  default:                     // 5.1 mode
    pt2323(13);  // disable CE
    pt2323(17);  // enable RL
    pt2323(19);  // enable RR 
    break;
  }
}

//------------------------------------------------------------------------------
// Set enhance
//------------------------------------------------------------------------------
void set_enhance()
{
  if(enhance == 1) pt2323(5); // enhance enabled
  else pt2323(6);
}

//------------------------------------------------------------------------------
// Set +6dB setup
//------------------------------------------------------------------------------    
void set_amp()
{
  if(amp == 1) pt2323(8);   // boost enabled
  else pt2323(7);
}

//------------------------------------------------------------------------------
// Select channel
//------------------------------------------------------------------------------
void set_ch()
{
  pt2323(CH);   // set channel
}

//------------------------------------------------------------------------------
// Set mute
//------------------------------------------------------------------------------
void set_mute()
{
  if(mute == 0)
  { 
    amplifier_enable(1);         // enable amplifier
  }
  else
  {
    amplifier_enable(0);         // disable amplifier
  }
}

//------------------------------------------------------------------------------
// Set unit (power)
//------------------------------------------------------------------------------
void set_unit()
{
  if(unit == 1) // power on
  {
    default_flags();           // load default flags on power up 
    lcd_led_enable(1);         // enable lcd and leds
    lcd.setCursor(1, 0);       // cursor at 2nd character, 1 line 
    lcd.print("5.1  Amplifier");
    lcd.setCursor(1, 1);       // cursor at 2nd character, 2 line 
    lcd.print("   by Neoxy   ");
    delay(2500);               // here we can afford a delay like this
    lcd.clear();
    lcd.setCursor(1, 0);       // cursor at 2nd character, 1 line 
    lcd.print("  Turning ON  ");

    set_ch();                      // set channel
    set_mode();                    // set mode      
    set_enhance();                 // set enhance mode 
    set_amp();                     // set +6dB setup
    set_volume(0, volume);         // set volume from level 0 to level volume
    set_mute();                    // set mute
    delay(1500);

    lcd_flag = 1;     // update lcd  
  }
  else
  {
    amplifier_enable(0);       // turn off amplifier 
    lcd.clear();
    lcd_led_enable(1);        // enable lcd and leds
    lcd.setCursor(1, 0);       // cursor at 2nd character, 1 line 
    lcd.print("   Stand-by   ");
    delay(2000); // here we can afford a delay like this
    lcd.clear();    
    lcd_led_enable(0);         // turn off LCD and LED lights
    lcd_flag = 0;              // do not update lcd
  }  
}

//------------------------------------------------------------------------------
// Enable or disable amplifier
//------------------------------------------------------------------------------
void amplifier_enable(byte cmd)    // enable or disable amplifier
{
  if(cmd == 1)                           // turn on amplifier 
  {
    digitalWrite(4, HIGH);   // relay on
    delay(200);                // small delay like this does not influence operation much
    digitalWrite(A3, HIGH);   // mute off
  }
  else                                   // turn off amplifier
  {
    digitalWrite(A3, LOW);   // mute on
    delay(50);
    digitalWrite(4, LOW);   // relay off
  } 
}

//------------------------------------------------------------------------------
// Enable or disable LCD and LED lights
//------------------------------------------------------------------------------
void lcd_led_enable(byte cmd)      // enable or disable lcd
{
  if(cmd == 1)                           // turn on or off LCD and leds 
  {
    digitalWrite(A2, HIGH);    // leds on
    lcd.display();             // turn on display
  }
  else
  {
    digitalWrite(A2, LOW);    // leds off
    lcd.noDisplay();          // turn off display
  }
}

//******************************************************************************
// SERIAL COMMUNICATION
//******************************************************************************
//------------------------------------------------------------------------------
// Check Serial Communication, verify code and execute command
//------------------------------------------------------------------------------
void checkSerial()              // check serial commands
{
  byte temp;    // temp value
  byte c;       // received char 
  if(Serial.available() > 0)     // If something received
  {
    while(Serial.available() != 0 && kontrolaCMD == 0) // read incomming bytes if flag = 0
    {
      c = Serial.read();   // read receaved byte from serial buffer
      if(c == 13 || c == 10 || xyz >= 16 ) kontrolaCMD = 1;  // if end of line received or temp buffer size exceeded escape, set flag to 1  
      else                    
      { 
        bufferX[xyz] = c;      // store in our temp buffer
        xyz++;                 // increment bufferX position
      }    
    } 

    if(kontrolaCMD==1)        // If EOL detected or buffer size exceeded  
    {
      if(compareStr(0,code) == 1)    // compare if code is a match (our case "AMP1")
      {
        if(compareStr(4, "00") == 1)    // next code 00 (stand-by, on)
        {
          lcd_flag = 1;    // here we want a lcd update
          temp = toNum(6);  

          if(temp <= 1)    // only default values
          {
            if(unit != temp)
            {
              unit = temp;
              set_unit();
            }
          }
          Serial.print(code);          // send back OK when done
          Serial.println("OK");
        }
        else if(compareStr(4, "01") == 1)   // code 01 (set channel)
        {
          lcd_flag = 1;    // here we want a lcd update
          temp = toNum(6);
          if(temp <= 4)
          {
            if(temp != CH)
            {
              CH = temp;
              set_ch();
            }
          }
          Serial.print(code);
          Serial.println("OK");
        }
        else if(compareStr(4, "02") == 1)   // code 02 (set mode)
        {
          lcd_flag = 1;  // here we want a lcd update
          temp = toNum(6);
          if(temp <= 3)
          {
            if(temp != mode)
            {
              mode = temp;
              set_mode();
            }
          }
          Serial.print(code);
          Serial.println("OK");
        }
        else if(compareStr(4, "03") == 1)   // code 03 (set correction), here we don't need a lcd update (lcd_flag not set) 
        {
          temp = toNum(8);
          if(temp <= 168 && temp >= 88)
          {
            if(compareStr(6, "FL"))              // no problem here if same value is set
            {
              FL = temp;
            }
            else if(compareStr(6, "FR"))
            {
              FR = temp;
            }
            else if(compareStr(6, "CE"))
            {
              CE = temp;
            }
            else if(compareStr(6, "SU"))
            {
              SU = temp;
            }
            else if(compareStr(6, "RL"))
            {
              RL = temp;
            }
            else if(compareStr(6, "RR"))
            {
              RR = temp;
            }
            set_volume(volume,volume);
          }
          Serial.print(code);
          Serial.println("OK");
        }
        else if(compareStr(4, "04") == 1)  // code 04 (set enhance)
        {
          lcd_flag = 1; 
          if(toNum(6) <= 1)
          {
            enhance = toNum(6);
            set_enhance();
          }
          Serial.print(code);
          Serial.println("OK");
        }
        else if(compareStr(4, "05") == 1)  // code 05 (set amp)
        {
          lcd_flag = 1;
          if(toNum(6) <= 1)
          {
            amp = toNum(6);
            set_amp();
          }
          Serial.print(code);
          Serial.println("OK");
        }
        else if(compareStr(4, "06") == 1)  // code 06 (set volume)
        {
          lcd_flag = 1;
          if(toNum(6) <= 79)
          {
            set_volume(volume, toNum(6)); // from current volume to new volume
          }
          Serial.print(code);
          Serial.println("OK"); 
        }
        else if(compareStr(4, "07") == 1)  // set mute
        {
          lcd_flag = 1;
          if(toNum(6) <= 1)
          {
            mute = toNum(6);
            set_mute();
          }
          Serial.print(code);
          Serial.println("OK");
        }
        else if(compareStr(4, "08") == 1)  // set buttons 
        {
          if(toNum(6) <= 1)
          {
            external_buttons = toNum(6);
          }
          Serial.print(code);
          Serial.println("OK");
        }
        else if(compareStr(4, "09") == 1)  // set remote
        {
          if(toNum(6) <= 1)
          {
            external_remote = toNum(6);
          }
          Serial.print(code);
          Serial.println("OK");
        }
        else if(compareStr(4, "10") == 1)  // set lcd enable
        {
          lcd_flag = 1;
          if(toNum(6) <= 1)
          {
            enable_lcd = toNum(6);
          }
          Serial.print(code);
          Serial.println("OK");           
        }
        else if(compareStr(4, "11") == 1)  // store in flash
        {
          write_to_eeprom();
          Serial.print(code);
          Serial.println("OK");
        }
        else if(compareStr(4, "20") == 1)  // return main status
        {
          Serial.print(code);
          Serial.print("P");
          Serial.print(unit, DEC);
          Serial.print("C");
          Serial.print(CH, DEC);
          Serial.print("M");
          Serial.print(mode, DEC);
          Serial.print("E");
          Serial.print(enhance, DEC);
          Serial.print("A");
          Serial.print(amp, DEC);
          Serial.print("V");
          if(volume<10) Serial.print("0");
          Serial.print(volume, DEC);
          Serial.print("MU");
          Serial.print(mute, DEC);
          Serial.print("B");
          Serial.print(external_buttons, DEC);
          Serial.print("R");
          Serial.print(external_remote, DEC);
          Serial.print("L");
          Serial.println(enable_lcd, DEC);
        }
        else if(compareStr(4, "21") == 1)  // return correction settings
        {
          Serial.print(code);
          Serial.print("L");
          if(FL<10) Serial.print("0");
          if(FL<100) Serial.print("0");
          Serial.print(FL, DEC); 
          Serial.print("R");
          if(FR<10) Serial.print("0");
          if(FR<100) Serial.print("0");
          Serial.print(FR, DEC);
          Serial.print("S");
          if(SU<10) Serial.print("0");
          if(SU<100) Serial.print("0");
          Serial.print(SU, DEC);
          Serial.print("C");
          if(CE<10) Serial.print("0");
          if(CE<100) Serial.print("0");
          Serial.print(CE, DEC);
          Serial.print("L");
          if(RL<10) Serial.print("0");
          if(RL<100) Serial.print("0");
          Serial.print(RL, DEC);
          Serial.print("R");
          if(RR<10) Serial.print("0");
          if(RR<100) Serial.print("0");
          Serial.println(RR, DEC);
        }
        else
        {
          // do nothing, inccorect code
        } 
      }
      bufXClear();            // Clear BufferX
      xyz = 0;                // reset bufferX counter
      kontrolaCMD = 0;        // Read again flag
    }
  }
}

//------------------------------------------------------------------------------
// Convert  1, 2 or 3 chars to number (Location in bufferX at startLocation)
//------------------------------------------------------------------------------
int toNum(byte startLocation)
{
  char numbers[10] = {
    '0','1','2','3','4','5','6','7','8','9'  };  // array of chars (numbers)
  byte flag_nmb = 0;    // flag for number found 

  int x = 0;

  for(int i = 0; i < 10; i++)          // check first loction for number
  {
    if(bufferX[startLocation] == numbers[i]) x = x + (i*100), flag_nmb = 1;
  }

  if(flag_nmb == 0) return 0;  // number not found
  flag_nmb = 0;                // reset flag

  for(int i = 0; i < 10; i++)         // check second location for number
  {
    if(bufferX[startLocation+1]== numbers[i]) x = x + (i*10), flag_nmb = 1; 
  }

  if(flag_nmb == 0) // number on second location not found
  {
    if(x != 0 )return x/100;    // we don't want to divide by 0 (end of the world and stuff.. :)
    else return 0;
  }

  flag_nmb = 0; // reset flag

  for(int i = 0; i < 10; i++)  // check third location for number
  {
    if(bufferX[startLocation+2]== numbers[i]) x = x + i, flag_nmb = 1; 
  }

  if(flag_nmb == 0)  // number on third location not found
  {
    if(x != 0 ) return x/10;   // we don't want to divide by 0 (end of the world and stuff.. :)
    else return 0;
  }

  if(x >= 256) return 0;
  return x;    // if all 3 numbers found 
}

//------------------------------------------------------------------------------
// Clear temp Serial buffer
//------------------------------------------------------------------------------
void bufXClear()          // clear serial buffer
{
  for(int x = 0; x < 16; x++)   // clear bufferX
  {
    bufferX[x] = '\0';            // \0 in ASCII end of string
  }
}

//------------------------------------------------------------------------------
// Commpare bufferX from location startPos with another string
//------------------------------------------------------------------------------
byte compareStr(int startPos, char *nekaj)
{
  int comp = 1;
  while(*nekaj)
  {
    if(bufferX[startPos] != *nekaj++) comp = 0;
    startPos++;
  }
  return comp;
}

//******************************************************************************
// EXTERNAL BUTTONS
//******************************************************************************
//------------------------------------------------------------------------------
// External buttons command execute, move between menus
//------------------------------------------------------------------------------
void checkButtons()             // check button interrupts
{
  if(read_button1() == 1)        // read on/off (allways)
  {
    if(unit == 1)
    {
      unit = 0;
      set_unit();
    }
    else
    {
      unit = 1;
      set_unit();
    }
  }

  if(read_button2() == 1)          // read mute
  {
    if(mute == 1)
    {
      mute = 0;
      set_mute();
    }
    else
    {
      mute = 1;
      set_mute();
    }
    lcd_flag = 1; // update lcd
  }

  int tempvalue = 0;                  // temp value    
  byte butn_menu = read_button3();    // read button menu and work with this value  
  byte butn_ok = read_button4();      // read button ok and work with this value
  check_encoder();                    // read encoder and work with this value

  if(butn_menu == 1) lcd_flag = 1;      // if button pressed update lcd
  if(butn_ok == 1) lcd_flag = 1;        // if button pressed update lcd
  if(encoder_value != 0) lcd_flag = 1;  // if encoder turned update lcd

  if(butn_ok == 1 && do_this == 0 && button_menus == 1)    // toggle do_this with OK button (depends on where in menu are we)
  {
    do_this = 1;
  }  
  else if(butn_ok == 1 && do_this == 1 && button_menus == 1)
  {
    do_this = 0;
    read_value = 1;             // here flag is set to change menu with encoder, and not change value 
  }
  else 
  {
    // do nothing
  }

  if(butn_ok == 1 && do_correct == 0  && button_menus == 2)  // toggle do_correct with OK button (depends on where in menu are we)
  {
    do_correct = 1;
  }
  else if(butn_ok == 1 && do_correct == 1  && button_menus == 2)
  {
    do_correct = 0;
    read_value = 1;              // here flag is set to change menu with encoder, and not change value
  }
  else 
  {
    // do nothing
  }


  if(butn_menu == 1)          // read menu if button pressed, move between menus (depends on where we are), also set default flags
  {  
    if(button_menus == 0) button_menus = 1, read_value = 1, set_menu = 0,  do_correct = 0, do_this = 0;
    else if(button_menus == 2) button_menus = 1, set_menu = 2, do_correct = 0, do_this = 0;
    else button_menus = 0, read_value = 1, set_menu = 0,  do_correct = 0, do_this = 0;
  }

  // Programmed menues
  switch(button_menus)
  {
  case 0:      // default - status  only change volume, show status
    do_correct = 0;
    do_this = 0;
    temp1 = external_buttons;                     // flag for enable buttons, latter used for APPLY and STORE, other changes take effect immediatly
    temp2 = external_remote;                      // flag for enable remote
    temp3 = enable_lcd;                           // flag for enable lcd
    temp4 = unit;                                 // flag for unit on/off
    if(encoder_value != 0)        // if encoder is not 0
    {
      if(volume + encoder_value > 79) set_volume(volume, 79);
      else if(volume + encoder_value < 0 ) set_volume(volume, 0);
      else set_volume(volume, (volume + encoder_value));
      set_menu = 0;            // in main menu we change volume with encoder 
      read_value = 1;     
    }
    break;

  case 1:      // go in menu selection (if menu pressed)
    do_correct = 0;
    if(read_value == 1)       // we are in menu and we move between him with encoder
    { 
      set_menu = set_menu + encoder_value;
      if(set_menu < 0) set_menu = 13;
      if(set_menu > 13) set_menu = 0;
    }
    switch(set_menu)  // jump between menus
    {
    case 0:    // set CH
      if(do_this == 1) // if OK pressed, encoder is used to change value and not move between menu
      {
        read_value = 0;                          // dont'leave this menu, set value
        if(CH + encoder_value < 0) CH = 4;
        else if(CH + encoder_value > 4) CH = 0;
        else CH = CH + encoder_value;
        if(encoder_value != 0) set_ch();         // if we have a value on encoder, execute command
      }
      else read_value = 1;                       // move between menu, encoder used for this 
      break;

    case 1:    // set mode
      if(do_this == 1)
      {
        read_value = 0;  // dont'leave this menu, set value
        if(mode + encoder_value < 0) mode = 3;
        else if(mode + encoder_value > 3) mode = 0;
        else mode = mode + encoder_value;
        if(encoder_value != 0) set_mode();
      }
      else read_value = 1;
      break;

    case 2:    // set correct
      if(do_this == 1)
      {
        read_value = 1;
        button_menus = 2;  // go in corrections menu  
      }
      else 
      {  
        read_value = 1;
        set_corrections_menu = 0;
      }
      break;

    case 3:    // set enhence
      if(do_this == 1)
      {
        read_value = 0;  // dont'leave this menu, set value
        if(enhance + encoder_value <= 0) enhance = 0;
        if(enhance + encoder_value >= 1) enhance = 1;
        if(encoder_value != 0) set_enhance();
      }
      else read_value = 1;
      break;

    case 4:    // set boost
      if(do_this == 1)
      {
        read_value = 0;  // dont'leave this menu, set value
        if(amp + encoder_value <= 0) amp = 0;
        if(amp + encoder_value >= 1) amp = 1;
        if(encoder_value != 0) set_amp();
      }
      else read_value = 1;
      break;

    case 5:    // set mute
      if(do_this == 1)
      {
        read_value = 0;  // dont'leave this menu, set value
        if(mute + encoder_value <= 0) mute = 0;
        if(mute + encoder_value >= 1) mute = 1;
        if(encoder_value != 0) set_mute();
      }
      else read_value = 1;
      break;

    case 6:    // set volume
      if(do_this == 1)
      {
        read_value = 0;  // dont'leave this menu, set value
        tempvalue = volume + encoder_value;
        if(tempvalue < 0) tempvalue = 0;
        if(tempvalue > 79) tempvalue = 79;
        if(encoder_value != 0) set_volume(volume, tempvalue);
      }
      else read_value = 1;
      break;

    case 7:    // set buttons
      if(do_this == 1)
      {
        read_value = 0;  // dont'leave this menu, set value
        if(external_buttons + encoder_value <= 0 && encoder_value != 0) temp1 = 0;  // value stored in temp value, will be set on APPLY or STORE
        if(external_buttons + encoder_value >= 1 && encoder_value != 0) temp1 = 1;
      }
      else read_value = 1;
      break;

    case 8:    // set remote
      if(do_this == 1)
      {
        read_value = 0;  // dont'leave this menu, set value
        if(external_remote + encoder_value <= 0 && encoder_value != 0) temp2 = 0;  // value stored in temp value, will be set on APPLY or STORE
        if(external_remote + encoder_value >= 1 && encoder_value != 0) temp2 = 1;
      }
      else read_value = 1;
      break;

    case 9:    // set lcd
      if(do_this == 1)
      {
        read_value = 0;  // dont'leave this menu, set value
        if(enable_lcd + encoder_value <= 0 && encoder_value != 0) temp3 = 0;    // value stored in temp value, will be set on APPLY or STORE
        if(enable_lcd + encoder_value >= 1 && encoder_value != 0) temp3 = 1;
      }
      else read_value = 1;
      break;

    case 10:    // set on/off
      if(do_this == 1)
      {
        read_value = 0;  // dont'leave this menu, set value
        if(unit + encoder_value <= 0 && encoder_value != 0) temp4 = 0;   // value stored in temp value, will be set on APPLY or STORE
        if(unit + encoder_value >= 1 && encoder_value != 0) temp4 = 1;
      }
      else read_value = 1;
      break;

    case 11:    // set apply
      if(do_this == 1)
      {
        read_value = 0;  // dont'leave this menu, set value
        external_buttons = temp1;    // set globals with temp values, we don't need to set unit ON/OFF because we don't want to turn our unit off
        external_remote = temp2;
        enable_lcd = temp3; 

        button_menus = 0;    // return in main menu
      }
      break;

    case 12:    // set store
      if(do_this == 1)
      {
        read_value = 0;  // dont'leave this menu, set value
        external_buttons = temp1;    // set globals with temp values
        external_remote = temp2;
        enable_lcd = temp3;
        unit = temp4;

        button_menus = 0;
        write_to_eeprom();  // store in eeprom
        
        unit = 1;  // set flag for unit ON, because we don't want to turn off unit, just store the value as default
      }
      break;

    default:   // exit
      if(do_this == 1)
      {
        button_menus = 0;    // go in main menu
      }
      break;
    }
    break;

  case 2:
    do_this = 0;
    if(read_value == 1)       // we are in sub menu for correction
    { 
      set_corrections_menu = set_corrections_menu + encoder_value;    // move between menu with encoder
      if(set_corrections_menu < 0) set_corrections_menu = 6;
      if(set_corrections_menu > 6) set_corrections_menu = 0;
    }
    switch(set_corrections_menu)      // go in sub menu
    {
    case 0:    // set FL
      if(do_correct == 1)
      {
        read_value = 0;  // dont'leave this menu, set value
        if(FL + encoder_value < 88) FL = 88;
        else if(FL + encoder_value > 168) FL = 168;
        else FL = FL + encoder_value;
      }
      else read_value = 1;
      break;

    case 1:    // set FR
      if(do_correct == 1)
      {
        read_value = 0;  // dont'leave this menu, set value
        if(FR + encoder_value < 88) FR = 88;
        else if(FR + encoder_value > 168) FR = 168;
        else FR = FR + encoder_value;
      }
      else read_value = 1;
      break;

    case 2:    // set SU
      if(do_correct == 1)
      {
        read_value = 0;  // dont'leave this menu, set value
        if(SU + encoder_value < 88) SU = 88;
        else if(SU + encoder_value > 168) SU = 168;
        else SU = SU + encoder_value;
      }
      else read_value = 1;
      break;

    case 3:    // set CE
      if(do_correct == 1)
      {
        read_value = 0;  // dont'leave this menu, set value
        if(CE + encoder_value < 88) CE = 88;
        else if(CE + encoder_value > 168) CE = 168;
        else CE = CE + encoder_value;
      }
      else read_value = 1;
      break;

    case 4:    // set RR
      if(do_correct == 1)
      {
        read_value = 0;  // dont'leave this menu, set value
        if(RR + encoder_value < 88) RR = 88;
        else if(RR + encoder_value > 168) RR = 168;
        else RR = RR + encoder_value;
      }
      else read_value = 1;
      break;

    case 5:    // set RL
      if(do_correct == 1)
      {
        read_value = 0;  // dont'leave this menu, set value
        if(RL + encoder_value < 88) RL = 88;
        else if(RL + encoder_value > 168) RL = 168;
        else RL = RL + encoder_value;
      }
      else read_value = 1;
      break;

    default:   // go back
      if(do_correct == 1)
      { 
        set_menu = 2;    // set defaults for previous menu  
        do_correct = 0;
        read_value = 1;
        button_menus = 1; 
      }
      else read_value = 1;
      break;
    }
    if(do_correct == 1 && encoder_value != 0) set_volume(volume, volume);  // if a value was on encoder execute command
    break;

  default:    // should not go here
    break;
  }
  encoder_value = 0;        // reset value 
}

//------------------------------------------------------------------------------
// Check encoder clicks, and buttons
//------------------------------------------------------------------------------
void check_encoder()      // check encoder status
{
  encoder *thisEncoder;
  if(external_buttons == 1 && unit == 1) // if buttons enabled and unit is on
  {
    thisEncoder=AdaEncoder::genie(&clicks, &id);    // check clicks
    if(clicks != 0)    
    {
      if(clicks > 1) clicks = 1;      // move only with 1 in either direction
      if(clicks < -1) clicks = -1;
      encoder_value = clicks;         // store in global value
    }
  }
  clicks = 0;    // reset clicks
}

//------------------------------------------------------------------------------
byte read_button1()  // on/off
{
  if(int1 == 1 && debounce == 1)  // read if interrupt flag set and debounce over
  {
    debounce = 0;          // reset debounce
    int_counter = 0;       // reset debounce counter
    int1 = 0; 
    return 1;
  }
  int1 = 0;   // reset flag (in case debounce was not timed out and interrupt flag was set)
  return 0;
}

//------------------------------------------------------------------------------
byte read_button2()   // mute 
{
  if(int2 == 1 && unit == 1 && debounce == 1) // read only if unit is on, on interrupt and debounce over 
  {
    debounce = 0;
    int_counter = 0;
    int2 = 0;
    return 1;
  }
  int2 = 0;  // reset flag (in case debounce was not timed out and interrupt flag was set)
  return 0;
}

//------------------------------------------------------------------------------
byte read_button3()    // menu
{
  if(int3 == 1 && unit == 1 && debounce == 1)
  {
    debounce = 0;
    int_counter = 0;
    int3 = 0;
    return 1;
  }
  int3 = 0;
  return 0;
}

//------------------------------------------------------------------------------
byte read_button4()    // ok
{
  if(int4 == 1 && unit == 1 && debounce == 1)
  {
    debounce = 0;
    int_counter = 0;
    int4 = 0;
    return 1;
  }
  int4 = 0;
  return 0;
}

//******************************************************************************
// REMOTE 
//******************************************************************************
//------------------------------------------------------------------------------
// Remote commands execute
//------------------------------------------------------------------------------
void checkIR()                  // check IR commands
{
  if((irrecv.decode(&results) != 0))  // if something received
  {
    //Serial.println(results.value, HEX);  // here you can uncomment this to listen for values of unknown remote
    if(((unit == 0 && results.value == rON) || unit == 1) && (IR_WAIT+1) == ir_counter) // check if unit is on, if unit is off (just power button), and if timedout
    {
      ir_counter = 0;         // reset timeout counter
      switch(results.value)
      {
      case rON:       // on/off
        int1 = 1;          // emulate button pressed (set interrupt flag)
        break;

      case rMUTE:     // mute
        int2 = 1;
        break;

      case rCH:     // ch
        CH++;
        if (CH == 5) CH = 0;  // do not exceed 4, set back to 0
        set_ch();
        lcd_flag = 1;    // here we want lcd to update
        break;

      case rMODE:     // mode
        mode++;
        if (mode == 4) mode = 0;
        set_mode();
        lcd_flag = 1;
        break;

      case rBASSP:     // bass+
        temp_menu = 3;                // temp lcd info will be shown
        temp_lcd_counter = 0;         // temp lcd counter reset   
        if (SU >= 168) SU = 168;
        else SU++;
        set_volume(volume,volume);
        lcd_flag = 1;
        break;

      case rBASSM:     // bass-
        temp_menu = 3;
        temp_lcd_counter = 0;
        if (SU <= 88) SU = 88;
        else SU--;
        set_volume(volume,volume);
        lcd_flag = 1;
        break;

      case rREARP:     // rear+
        temp_menu = 5;
        temp_lcd_counter = 0;
        if (RR >= 168) RR = 168;
        else RR++;
        if (RL >= 168) RL = 168;
        else RL++;
        set_volume(volume,volume);
        lcd_flag = 1;
        break;

      case rREARM:     // rear-
        temp_menu = 5;
        temp_lcd_counter = 0;
        if (RR <= 88) RR = 88;
        else RR--;
        if (RL <= 88) RL = 88;
        else RL--;
        set_volume(volume,volume);
        lcd_flag = 1;
        break;

      case rCENP:     // center+
        temp_menu = 6;
        temp_lcd_counter = 0;
        if (CE >= 168) CE = 168;
        else CE++;
        set_volume(volume,volume);
        lcd_flag = 1;
        break;

      case rCENM:     // center-
        temp_menu = 6;
        temp_lcd_counter = 0;
        if (CE <= 88) CE = 88;
        else CE--;
        set_volume(volume,volume);
        lcd_flag = 1;
        break;

      case rVOLP:     // vol+
        encoder_value++; 
        lcd_flag = 1;
        break;
      case rVOLM:     // vol-
        encoder_value--;
        lcd_flag = 1;
        break;

      case rLCD:     // lcd on/off
        temp_menu = 4;
        temp_lcd_counter = 0;
        enable_lcd++;
        if (enable_lcd == 2) enable_lcd = 0;
        lcd_flag = 1;
        break;

      case rENH:     // enhance
        enhance++;
        if (enhance == 2) enhance = 0;
        set_enhance();
        lcd_flag = 1;
        break;    

      case rBOOST:     // boost
        amp++;
        if (amp == 2) amp = 0;
        set_amp();
        lcd_flag = 1;
        break;

      case rMENU:     // menu
        int3 = 1;
        break;

      case rOK:     // ok
        int4 = 1;
        break;

      default:   // incorect code
        break;
      }
    }
    irrecv.resume();      // receive next value on IR
    results.value = 0;    // reset results value to 0
  }
}

//******************************************************************************
// LCD UPDATE
//******************************************************************************
//------------------------------------------------------------------------------
// Update LCD
//------------------------------------------------------------------------------
void update_lcd()
{
  switch(button_menus)    // where we are in menu
  {
  case 0:      // status and volume
    lcd.setCursor(1, 0);       // cursor at 2nd character, 1 line 
    switch(CH)
    {
    case 1:
      lcd.print("CH-1 ");
      break;
    case 2:
      lcd.print("CH-2 ");
      break;
    case 3:
      lcd.print("CH-3 ");
      break;
    case 4:
      lcd.print("CH-4 ");
      break;
    default:
      lcd.print("6-CH ");
      break;
    }
    switch(mode)
    {
    case 1:
      lcd.print(" 2.1 MODE");
      break;
    case 2:
      lcd.print(" 3.1 MODE");
      break;
    case 3:
      lcd.print(" 4.1 MODE");
      break;
    case 4:
    default:
      lcd.print(" 5.1 MODE");
      break;
    }
    lcd.setCursor(1, 1);       // cursor at 2nd character, 2 line 
    switch(enhance)
    {
    case 1:
      lcd.print("E");
      break;
    default:
      lcd.print(" ");
      break;
    }
    switch(amp)
    {
    case 1:
      lcd.print("B  ");
      break;
    default:
      lcd.print("   ");
      break;
    }
    lcd.print(" VOL ");
    if(volume < 10) lcd.print(" ");
    lcd.print(volume, DEC);
    lcd.print("  ");
    switch(mute)
    {
    case 1:
      lcd.print("M");
      break;
    default:
      lcd.print(" ");
      break;
    }
    break;

  case 1:      // main menu (move between menu)
    switch(set_menu)
    {
    case 0:  // ch
      lcd.setCursor(1, 0);       // cursor at 2nd character, 1 line 
      lcd.print(" SET  CHANNEL ");
      lcd.setCursor(1, 1);       // cursor at 2nd character, 2 line 
      if(do_this == 1) lcd.print("S");  // S stands for selected and waits for a change of value
      else lcd.print(" ");
      switch(CH)
      {
      case 1:
        lcd.print("    CH-1     ");
        break;
      case 2:
        lcd.print("    CH-2     ");
        break;
      case 3:
        lcd.print("    CH-3     ");
        break;
      case 4:
        lcd.print("    CH-4     ");
        break;
      default:
        lcd.print("    6-CH     ");
        break;
      }
      break;

    case 1:  // mode
      lcd.setCursor(1, 0);       // cursor at 2nd character, 1 line 
      lcd.print("   SET MODE   ");
      lcd.setCursor(1, 1);       // cursor at 2nd character, 2 line 
      if(do_this == 1) lcd.print("S");
      else lcd.print(" ");
      switch(mode)
      {
      case 1:
        lcd.print("  2.1  MODE  ");
        break;
      case 2:
        lcd.print("  3.1  MODE  ");
        break;
      case 3:
        lcd.print("  4.1  MODE  ");
        break;
      default:
        lcd.print("  5.1  MODE  ");
        break;
      }
      break;

    case 2:  // correct
      lcd.setCursor(1, 0);       // cursor at 2nd character, 1 line 
      lcd.print("  CH CORRECT  ");
      lcd.setCursor(1, 1);       // cursor at 2nd character, 2 line 
      lcd.print("              ");
      break;

    case 3:  // enhence
      lcd.setCursor(1, 0);       // cursor at 2nd character, 1 line 
      lcd.print(" SET  ENHANCE ");
      lcd.setCursor(1, 1);       // cursor at 2nd character, 2 line 
      if(do_this == 1) lcd.print("S");
      else lcd.print(" ");
      switch(enhance)
      {
      case 1:
        lcd.print("   ACTIVE    ");
        break;
      default:
        lcd.print("  DISABLED   ");
        break;
      }
      break;

    case 4:  // boost
      lcd.setCursor(1, 0);       // cursor at 2nd character, 1 line 
      lcd.print("  SET BOOST   ");
      lcd.setCursor(1, 1);       // cursor at 2nd character, 2 line 
      if(do_this == 1) lcd.print("S");
      else lcd.print(" ");
      switch(amp)
      {
      case 1:
        lcd.print("   ACTIVE    ");
        break;
      default:
        lcd.print("  DISABLED   ");
        break;
      }
      break;

    case 5:  // mute
      lcd.setCursor(1, 0);       // cursor at 2nd character, 1 line 
      lcd.print("   SET MUTE   ");
      lcd.setCursor(1, 1);       // cursor at 2nd character, 2 line 
      if(do_this == 1) lcd.print("S");
      else lcd.print(" ");
      switch(mute)
      {
      case 1:
        lcd.print("   ACTIVE    ");
        break;
      default:
        lcd.print("  DISABLED   ");
        break;
      }
      break;

    case 6:  // volume
      lcd.setCursor(1, 0);       // cursor at 2nd character, 1 line 
      lcd.print("  SET VOLUME  ");
      lcd.setCursor(1, 1);       // cursor at 2nd character, 2 line 
      if(do_this == 1) lcd.print("S");
      else lcd.print(" ");
      lcd.print("  VOL  ");
      if(volume < 10) lcd.print(" "); 
      lcd.print(volume, DEC);
      lcd.print("    ");
      break;

    case 7:  // buttons
      lcd.setCursor(1, 0);       // cursor at 2nd character, 1 line 
      lcd.print("  SET BUTTONS ");
      lcd.setCursor(1, 1);       // cursor at 2nd character, 2 line 
      if(do_this == 1) lcd.print("S");
      else lcd.print(" ");
      switch(temp1)        // here we use temp values, globals need to be set
      {
      case 1:
        lcd.print("   ACTIVE    ");
        break;
      default:
        lcd.print("  DISABLED   ");
        break;
      }
      break;

    case 8:  // remote
      lcd.setCursor(1, 0);       // cursor at 2nd character, 1 line 
      lcd.print("  SET REMOTE  ");
      lcd.setCursor(1, 1);       // cursor at 2nd character, 2 line 
      if(do_this == 1) lcd.print("S");
      else lcd.print(" ");
      switch(temp2)
      {
      case 1:
        lcd.print("   ACTIVE    ");
        break;
      default:
        lcd.print("  DISABLED   ");
        break;
      }
      break;

    case 9:  // lcd
      lcd.setCursor(1, 0);       // cursor at 2nd character, 1 line 
      lcd.print("   LCD MODE   ");
      lcd.setCursor(1, 1);       // cursor at 2nd character, 2 line 
      if(do_this == 1) lcd.print("S");
      else lcd.print(" ");
      switch(temp3)
      {
      case 1:
        lcd.print("     ON      ");
        break;
      default:
        lcd.print("   TIMEOUT   ");
        break;
      }
      break;

    case 10:  // on-off
      lcd.setCursor(1, 0);       // cursor at 2nd character, 1 line 
      lcd.print("  SET ON/OFF  ");
      lcd.setCursor(1, 1);       // cursor at 2nd character, 2 line 
      if(do_this == 1) lcd.print("S");
      else lcd.print(" ");
      switch(temp4)
      {
      case 1:
        lcd.print("     ON      ");
        break;
      default:
        lcd.print("     OFF     ");
        break;
      }
      break;

    case 11:  // apply
      lcd.setCursor(1, 0);       // cursor at 2nd character, 1 line 
      lcd.print("     APPLY    ");
      lcd.setCursor(1, 1);       // cursor at 2nd character, 2 line 
      lcd.print("              ");
      break;

    case 12:  // store
      lcd.setCursor(1, 0);       // cursor at 2nd character, 1 line 
      lcd.print("     STORE    ");
      lcd.setCursor(1, 1);       // cursor at 2nd character, 2 line 
      lcd.print("              ");
      break;

    default:   // back
      lcd.setCursor(1, 0);       // cursor at 2nd character, 1 line 
      lcd.print("     BACK     ");
      lcd.setCursor(1, 1);       // cursor at 2nd character, 2 line 
      lcd.print("              ");
      break;
    }
    break;

  case 2:      // correct menu, move beetween correct menu
    switch(set_corrections_menu)
    {
    case 0:    // FL
      lcd.setCursor(1, 0);       // cursor at 2nd character, 1 line 
      lcd.print(" SET  FRONT L ");
      lcd.setCursor(1, 1);       // cursor at 2nd character, 2 line 
      if(do_correct == 1) lcd.print("S");
      else lcd.print(" ");
      lcd.print("    ");
      if(FL-128 < 10 && FL-128> -10) lcd.print(" ");
      if(FL>128) lcd.print("+");
      lcd.print(FL-128);
      lcd.print("      ");
      break;

    case 1:    // FR
      lcd.setCursor(1, 0);       // cursor at 2nd character, 1 line 
      lcd.print(" SET  FRONT R ");
      lcd.setCursor(1, 1);       // cursor at 2nd character, 2 line 
      if(do_correct == 1) lcd.print("S");
      else lcd.print(" ");
      lcd.print("    ");
      if(FR-128 < 10 && FR-128> -10) lcd.print(" ");
      if(FR>128) lcd.print("+");
      lcd.print(FR-128);
      lcd.print("      ");
      break;

    case 2:    // SU
      lcd.setCursor(1, 0);       // cursor at 2nd character, 1 line 
      lcd.print(" SET SUBWOOFER ");
      lcd.setCursor(1, 1);       // cursor at 2nd character, 2 line 
      if(do_correct == 1) lcd.print("S");
      else lcd.print(" ");
      lcd.print("    ");
      if(SU-128 < 10 && SU-128> -10) lcd.print(" ");
      if(SU>128) lcd.print("+");
      lcd.print(SU-128);
      lcd.print("      ");
      break;

    case 3:    // CE
      lcd.setCursor(1, 0);       // cursor at 2nd character, 1 line 
      lcd.print("  SET CENTER  ");
      lcd.setCursor(1, 1);       // cursor at 2nd character, 2 line 
      if(do_correct == 1) lcd.print("S");
      else lcd.print(" ");
      lcd.print("    ");
      if(CE-128 < 10 && CE-128> -10) lcd.print(" ");
      if(CE>128) lcd.print("+");
      lcd.print(CE-128);
      lcd.print("      ");
      break;

    case 4:    // RR
      lcd.setCursor(1, 0);       // cursor at 2nd character, 1 line 
      lcd.print(" SET  REAR  R ");
      lcd.setCursor(1, 1);       // cursor at 2nd character, 2 line 
      if(do_correct == 1) lcd.print("S");
      else lcd.print(" ");
      lcd.print("    ");
      if(RR-128 < 10 && RR-128> -10) lcd.print(" ");
      if(RR>128) lcd.print("+");
      lcd.print(RR-128);
      lcd.print("      ");
      break;

    case 5:    // RL
      lcd.setCursor(1, 0);       // cursor at 2nd character, 1 line 
      lcd.print(" SET  REAR  L ");
      lcd.setCursor(1, 1);       // cursor at 2nd character, 2 line 
      if(do_correct == 1) lcd.print("S");
      else lcd.print(" ");
      lcd.print("    ");
      if(RL-128 < 10 && RL-128> -10) lcd.print(" ");
      if(RL>128) lcd.print("+");
      lcd.print(RL-128);
      lcd.print("      ");
      break;

    default:   // BACK
      lcd.setCursor(1, 0);       // cursor at 2nd character, 1 line 
      lcd.print("     BACK     ");
      lcd.setCursor(1, 1);       // cursor at 2nd character, 2 line 
      lcd.print("              ");
      break;
    }
    break;

  case 3:        // remote bass info (this is a temp LCD INFO)
    lcd.setCursor(1, 0);       // cursor at 2nd character, 1 line 
    lcd.print("  SUBWOOFER   ");
    lcd.setCursor(1, 1);       // cursor at 2nd character, 2 line 
    lcd.print("     ");
    if(SU-128 < 10 && SU-128> -10) lcd.print(" ");
    if(SU>128) lcd.print("+");
    lcd.print(SU-128);
    lcd.print("      ");  
    break;

  case 4:        // remote lcd on/off info(this is a temp LCD INFO)
    lcd.setCursor(1, 0);       // cursor at 2nd character, 1 line 
    lcd.print("   LCD MODE   ");
    lcd.setCursor(1, 1);       // cursor at 2nd character, 1 line 
    if(enable_lcd == 1)lcd.print("      ON      ");
    else lcd.print("    TIMEOUT   "); 
    break;

  case 5:        // remote rear info (this is a temp LCD INFO)
    lcd.setCursor(1, 0);       // cursor at 2nd character, 1 line 
    lcd.print("  REAR L & R  ");
    lcd.setCursor(1, 1);       // cursor at 2nd character, 1 line 
    lcd.print("  ");
    if(RR-128 > -10 && RR-128 < 10) lcd.print(" ");
    if(RR > 128) lcd.print("+");
    lcd.print(RR-128);
    lcd.print("    ");
    if(RL-128 > -10 && RL-128 < 10) lcd.print(" ");
    if(RL > 128) lcd.print("+");
    lcd.print(RL-128);
    lcd.print("  ");  
    break;

  case 6:        // remote cen info (this is a temp LCD INFO)
    lcd.setCursor(1, 0);       // cursor at 2nd character, 1 line 
    lcd.print("    CENTER    ");
    lcd.setCursor(1, 1);       // cursor at 2nd character, 1 line 
    lcd.print("     ");
    if(CE-128 > -10 && CE-128 < 10) lcd.print(" ");
    if(CE > 128) lcd.print("+");
    lcd.print(CE-128);
    lcd.print("      ");
    break;

  default:     // should not go here
    break;
  }
}

//******************************************************************************
// EEPROM READ AND WRITE
//******************************************************************************
//------------------------------------------------------------------------------
// Store settings in eeprom
//------------------------------------------------------------------------------
void write_to_eeprom()          
{
  EEPROM.write(0, volume);      // store volume settings in address location 0 (1 byte for location)
  EEPROM.write(1, FL);          // ...        
  EEPROM.write(2, FR);                  
  EEPROM.write(3, CE);                  
  EEPROM.write(4, SU);                  
  EEPROM.write(5, RL);                      
  EEPROM.write(6, RR);                  
  EEPROM.write(7, CH);                   
  EEPROM.write(8, enhance);              
  EEPROM.write(9, amp);                 
  EEPROM.write(10, mute);               
  EEPROM.write(11, unit);               
  EEPROM.write(12, mode);               

  EEPROM.write(13, external_buttons);   
  EEPROM.write(14, external_remote);    
  EEPROM.write(15, enable_lcd);         
}

//------------------------------------------------------------------------------
// Read from eeprom and store to our global variables
//------------------------------------------------------------------------------
void read_from_eeprom()
{
  volume = EEPROM.read(0);
  FL = EEPROM.read(1);
  FR = EEPROM.read(2);
  CE = EEPROM.read(3);
  SU = EEPROM.read(4);
  RL = EEPROM.read(5);    
  RR = EEPROM.read(6);
  CH = EEPROM.read(7); 
  enhance = EEPROM.read(8); 
  amp = EEPROM.read(9);
  mute = EEPROM.read(10);
  unit = EEPROM.read(11);
  mode = EEPROM.read(12);

  external_buttons = EEPROM.read(13);
  external_remote = EEPROM.read(14);
  enable_lcd = EEPROM.read(15);
}

//******************************************************************************
// FLAGS
//******************************************************************************
//------------------------------------------------------------------------------
// Default settings of global flags
//------------------------------------------------------------------------------
void default_flags()
{
  int1 = 0;                 // interrupt flag for button 1
  int2 = 0;                 // interrupt flag for button 2
  int3 = 0;                 // interrupt flag for button 3     
  int4 = 0;                 // interrupt flag for button 4 
  button_menus = 0;         // global variable for menu
  set_menu = 0;              // global variable for sub_menu 
  temp_menu = 0;             // global temp menu varaiable (for quick status)
  set_corrections_menu = 0;      // global variable for sub_menu of corrections
  read_value = 0;                // read encoder flag value in menu
  do_this = 0;                   // select menu flag
  do_correct = 0;                // select correct flag
  temp1 = -1;                     // flag for enable buttons
  temp2 = -1;                     // flag for enable remote
  temp3 = -1;                     // flag for enable lcd
  temp4 = -1;                     // flag for unit on/off     
  encoder_value = 0;              // value for encoder
  clicks = 0;                     // value for encoder clicks
  lcd_flag = 0;                   // lcd_flag
}
