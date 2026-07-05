#include <SensirionI2cScd4x.h>
#include <Wire.h>

SensirionI2cScd4x scd4x;

bool isDataReady = false;
char errorMessage[256];

int16_t error; 
uint64_t serialNumber;

int16_t stop_mesure_periodique()
{
  error = scd4x.stopPeriodicMeasurement();
  return error;
}

int16_t affiche_num_serie()
{
  error = scd4x.getSerialNumber(serialNumber);

  if (error) 
  {
      Serial.print("Error trying to execute getSerialNumber(): ");
      errorToString(error, errorMessage, 256);
      Serial.println(errorMessage);
  } 
  else 
  {
    Serial.print("Serial: 0x");
    Serial.print((uint32_t)(serialNumber >> 32), HEX);
    Serial.println((uint32_t)(serialNumber & 0xFFFFFFFF), HEX);
  }

  return error;
}