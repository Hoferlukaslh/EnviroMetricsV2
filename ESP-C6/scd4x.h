#include <SensirionI2CScd4x.h>
#include <Wire.h>

SensirionI2CScd4x scd4x;

bool isDataReady = false;
char errorMessage[256];
uint16_t error, serial0, serial1, serial2;


void printUint16Hex(uint16_t value) {
    Serial.print(value < 4096 ? "0" : "");
    Serial.print(value < 256 ? "0" : "");
    Serial.print(value < 16 ? "0" : "");
    Serial.print(value, HEX);
}

void printSerialNumber(uint16_t serial0, uint16_t serial1, uint16_t serial2) {
    Serial.print("Serial: 0x");
    printUint16Hex(serial0);
    printUint16Hex(serial1);
    printUint16Hex(serial2);
    Serial.println();
}


uint16_t stop_mesure_periodique()
{
  error = scd4x.stopPeriodicMeasurement();
  return error;
}


uint16_t affiche_num_serie()
{
  error = scd4x.getSerialNumber(serial0, serial1, serial2);

  if (error) 
  {
      Serial.print("Error trying to execute getSerialNumber(): ");
      errorToString(error, errorMessage, 256);
      Serial.println(errorMessage);
  } 
  else 
  {
    printSerialNumber(serial0, serial1, serial2);
  }

  return error;
}
    
