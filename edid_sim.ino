// edidsim.ino
// -----------
// Simulation for EDID-eeprom.  Replaces HDMI monitor for headless PC.
//
//
//********************************************************************************#
// History:                                                                       #
// Date       Author      Change                                                  #
// ---------  ------      --------------------------------------------------------#
// 04-05-2015 ES          Original version (untested).                            #
//********************************************************************************#
//

#define EDID_SLAVE 0x50
#define CLKPIN 3
#define SDAPIN 4
#define HOTPLUGPIN 5
#define LEDPIN 13

byte   *p = NULL ;                         // Pointer to data byte white sending data
int    DEBUG = 0 ;

// EDID-block voor een LG-televisie
byte edid_b1[128] = { 0x00, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x00, 0x1e, 0x6d, 0x01, 0x00, 0x01, 0x01, 0x01, 0x01,
                      0x02, 0x13, 0x01, 0x03, 0x80, 0x73, 0x41, 0x78, 0x0a, 0xcf, 0x74, 0xa3, 0x57, 0x4c, 0xb0, 0x23,
                      0x09, 0x48, 0x4c, 0xa1, 0x08, 0x00, 0x81, 0x80, 0x61, 0x40, 0x45, 0x40, 0x31, 0x40, 0x01, 0x01,
                      0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x02, 0x3a, 0x80, 0x18, 0x71, 0x38, 0x2d, 0x40, 0x58, 0x2c,
                      0x45, 0x00, 0x7e, 0x8a, 0x42, 0x00, 0x00, 0x1e, 0x01, 0x1d, 0x00, 0x72, 0x51, 0xd0, 0x1e, 0x20,
                      0x6e, 0x28, 0x55, 0x00, 0x7e, 0x8a, 0x42, 0x00, 0x00, 0x1e, 0x00, 0x00, 0x00, 0xfd, 0x00, 0x3a,
                      0x3e, 0x1e, 0x53, 0x10, 0x00, 0x0a, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x00, 0x00, 0x00, 0xfc,
                      0x00, 0x4c, 0x47, 0x20, 0x54, 0x56, 0x0a, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x01, 0x04,
                    } ;

// Extended block
byte edid_b2[128] = { 0x02, 0x03, 0x2c, 0xf1, 0x4e, 0x10, 0x1f, 0x84, 0x13, 0x05, 0x14, 0x03, 0x02, 0x12, 0x20, 0x21,
                      0x22, 0x15, 0x01, 0x2c, 0x09, 0x1f, 0x07, 0x0f, 0x1f, 0x07, 0x15, 0x07, 0x50, 0x3d, 0x07, 0xc0,
                      0x83, 0x4f, 0x00, 0x00, 0x67, 0x03, 0x0c, 0x00, 0x12, 0x00, 0x80, 0x1e, 0x01, 0x1d, 0x80, 0x18,
                      0x71, 0x1c, 0x16, 0x20, 0x58, 0x2c, 0x25, 0x00, 0x7e, 0x8a, 0x42, 0x00, 0x00, 0x9e, 0x01, 0x1d,
                      0x00, 0x80, 0x51, 0xd0, 0x0c, 0x20, 0x40, 0x80, 0x35, 0x00, 0x7e, 0x8a, 0x42, 0x00, 0x00, 0x1e,
                      0x02, 0x3a, 0x80, 0x18, 0x71, 0x38, 0x2d, 0x40, 0x58, 0x2c, 0x45, 0x00, 0x7e, 0x8a, 0x42, 0x00,
                      0x00, 0x1e, 0x66, 0x21, 0x50, 0xb0, 0x51, 0x00, 0x1b, 0x30, 0x40, 0x70, 0x36, 0x00, 0x7e, 0x8a,
                      0x42, 0x00, 0x00, 0x1e, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x4b
                    } ;

// Compute and restore checksum
void setchecksum ( byte* p )
{
  byte csum = 0 ;
  int  i ;

  for ( i = 0 ; i < 127 ; i++ )
  {
    if ( DEBUG )
    {
      Serial.print ( *p, HEX ) ;
      Serial.print ( " " ) ;
      if ( ( i % 16 ) == 15 )
      {
        Serial.println ( "" ) ;
      }
    }
    csum += *p ;
    p++ ;
  }
  csum = 256 - csum ;                     // Final checksum
  if ( csum != *p )
  {
    Serial.print ( "Checksum was " ) ;
    Serial.print ( *p, HEX ) ;
    *p = csum ;
    Serial.print ( ", now " ) ;
    Serial.println ( *p, HEX ) ;
  }
}


void setup()
{
  Serial.begin ( 115200 ) ;
  Serial.println ( "Program edid_sim started." ) ;
  Serial.println ( HIGH ) ;
  Serial.println ( LOW ) ;
  pinMode ( CLKPIN, INPUT ) ;             // Clock is always INPUT
  pinMode ( SDAPIN, INPUT ) ;             // SDA is input exect for ACK and sending data as slave
  digitalWrite ( SDAPIN, LOW ) ;          // So we can output a zero when switched to OUTPUT
  pinMode ( HOTPLUGPIN, OUTPUT ) ;        // Hotplugpin always output
  digitalWrite ( HOTPLUGPIN, LOW ) ;      // unplug the cable
  pinMode ( LEDPIN, OUTPUT ) ;            // LED pin always output
  digitalWrite ( LEDPIN, LOW ) ; 
  setchecksum ( edid_b1 ) ;               // Compute and set checksum
  setchecksum ( edid_b2 ) ;               // Compute and set checksum
  delay ( 10 ) ;
  digitalWrite ( HOTPLUGPIN, HIGH ) ;     // plug in cable
  if ( digitalRead ( SDAPIN ) == HIGH )
  {
    Serial.println ( "SDA is HIGH, okay." ) ;
  }
  else
  {
    Serial.println ( "Error: SDA is LOW." ) ;
  }
}

void wstart()
{
  // Wait for startbit: CLK is high and SDA is low.
  // Returns when CLK is low again
  do
  {
  } while ( ! ( digitalRead ( SDAPIN ) == LOW && digitalRead ( CLKPIN ) == HIGH ) ) ;
  // Wait until clock goes LOW
  do
  {
  } while ( digitalRead ( CLKPIN ) == HIGH ) ;
}


byte read8bits()
{
  // Read 8 bits.  Could be address + R/W or data
  // Returns when CLK is low again
  int  cnt8 ;                             // Counter for 8 bits
  int  bit ;
  byte res ;                              // Resulting 8 bits

  for ( cnt8 = 0 ; cnt8 < 8 ; cnt8++ )
  {
    // Wait until clock goes HIGH
    do
    {
      bit = digitalRead ( SDAPIN ) ;
    } while ( digitalRead ( CLKPIN ) == LOW ) ;
    // CLK has become HIGH, input from SDA is in variable "bit"
    res = ( res << 1 ) | bit ;            // Shift a zero/one in
    // Wait until clock goes LOW
    do
    {
    } while ( digitalRead ( CLKPIN ) == HIGH  ) ;
  }
  return res ;
}


void sendack()
{
  // Send ACK (one bit LOW ) to master
  // Returns when CLK is low again
  pinMode ( SDAPIN, OUTPUT ) ;            // ACK is a low bit
  // Wait until clock goes HIGH
  do
  {
  } while ( digitalRead ( CLKPIN ) == LOW ) ;
  // Wait until clock goes LOW
  do
  {
  } while ( digitalRead ( CLKPIN ) == HIGH ) ;
  pinMode ( SDAPIN, INPUT ) ;            // End of ACK
}



void loop()
{
  int        i ;
  byte       b0, b1 ;                    // Commandbyte and data

  noInterrupts() ;
  wstart() ;                             // Wait for start bit
  b0 = read8bits() ;                     // Read commandword from master
  if ( ( b0 >> 1 ) == EDID_SLAVE )       // Stuff meant for us?
  {
    sendack() ;                          // Yes, send ACK
    b1 = read8bits() ;                   // Read dataword from master
    sendack() ;                          // Send ACK to satisfy master
    interrupts() ;
    Serial.print ( "B0 is " ) ;
    Serial.print ( b0, HEX ) ;
    Serial.print ( ", B1 is " ) ;
    Serial.print ( b1, HEX ) ;
    Serial.println() ;
  }
  else
  {
    Serial.print ( "B0 is " ) ;
    Serial.print ( b0, HEX ) ;
    Serial.println() ;
  }
  delay ( 10 ) ;
}
