#include <Arduino.h>
#include <esp_sleep.h>
#include <esp_pm.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <Wire.h>
#include "scd4x.h"
#include "AHT10.h"
#include <freertos/FreeRTOS.h>
#include <freertos/event_groups.h>

AHT10 myAHT10(0x38);

RTC_DATA_ATTR uint8_t savedBSSID[6];
RTC_DATA_ATTR uint8_t savedChannel;
RTC_DATA_ATTR bool wifiDataSaved = false;

const char* ssid     = "U6-LR2_4";
const char* password = "Ubtn_U6-LR";
const char* server   = "http://192.168.1.240:8080/SendDB.php";

float    temp_aht = 0.0f;
float    hum_aht  = 0.0f;
uint16_t co2_scd  = 0;

EventGroupHandle_t syncGroup;
#define WIFI_READY_BIT    BIT0
#define SENSORS_READY_BIT BIT1

// ------------------------------------------------------------------
// TÂCHE 1 : Connexion WiFi
// ------------------------------------------------------------------
void TaskWiFi(void *pvParameters) {
  WiFi.mode(WIFI_STA);
  WiFi.persistent(false);
  WiFi.setTxPower(WIFI_POWER_8_5dBm); // Réduction puissance émission

  // IP Statique (évite le DHCP à chaque réveil)
  IPAddress staticIP(192, 168, 1, 250);
  IPAddress gateway(192, 168, 1, 1);
  IPAddress subnet(255, 255, 255, 0);
  WiFi.config(staticIP, gateway, subnet);

  if (wifiDataSaved) {
    WiFi.begin(ssid, password, savedChannel, savedBSSID, true); // Reconnexion rapide
  } else {
    WiFi.begin(ssid, password);
  }

  while (WiFi.status() != WL_CONNECTED)
    vTaskDelay(pdMS_TO_TICKS(100));

  Serial.println("WiFi Connecté !");

  memcpy(savedBSSID, WiFi.BSSID(), 6);
  savedChannel  = WiFi.channel();
  wifiDataSaved = true;

  xEventGroupSetBits(syncGroup, WIFI_READY_BIT);
  vTaskDelete(NULL);
}

// ------------------------------------------------------------------
// FONCTION D'ENVOI
// ------------------------------------------------------------------
bool envois_valeurs(float temperature, float humidite, uint16_t co2, int app_id) {
  HTTPClient http;
  String url = String(server)
             + "?temperature=" + String(temperature, 2)
             + "&humidite="    + String(humidite, 2)
             + "&co2="         + String(co2)
             + "&app_id="      + String(app_id);

  http.begin(url);
  int httpResponseCode = http.GET();
  bool success = (httpResponseCode == HTTP_CODE_OK);

  if (success) Serial.println("Envoi OK : " + url);
  else         Serial.printf("Erreur HTTP : %d\n", httpResponseCode);

  http.end();
  return success;
}

// ------------------------------------------------------------------
// TÂCHE 2 : Lecture des capteurs
// ------------------------------------------------------------------
void TaskSensors(void *pvParameters) {
  myAHT10.begin();
  scd4x.begin(Wire);

  scd4x.stopPeriodicMeasurement();
  vTaskDelay(pdMS_TO_TICKS(500));

  scd4x.startPeriodicMeasurement();

  temp_aht = myAHT10.readTemperature();
  hum_aht  = myAHT10.readHumidity();

  vTaskDelay(pdMS_TO_TICKS(4500));

  bool isDataReady = false;
  int  timeout     = 0;

  while (!isDataReady && timeout < 20) {
    scd4x.getDataReadyFlag(isDataReady);
    if (!isDataReady) {
      vTaskDelay(pdMS_TO_TICKS(100));
      timeout++;
    }
  }

  if (isDataReady) {
    float t, h;
    scd4x.readMeasurement(co2_scd, t, h);
  } else {
    Serial.println("Erreur : Timeout SCD4x");
  }

  scd4x.stopPeriodicMeasurement();
  vTaskDelay(pdMS_TO_TICKS(500));

  Serial.println("Capteurs lus !");
  xEventGroupSetBits(syncGroup, SENSORS_READY_BIT);
  vTaskDelete(NULL);
}

// ------------------------------------------------------------------
// SETUP
// ------------------------------------------------------------------
void setup() {
  Serial.begin(115200);
  Serial.println("\n--- Réveil ESP32-C6 ---");

  pinMode(14, OUTPUT);
  digitalWrite(14, LOW);

  btStop();
  Wire.begin();

  // Light sleep automatique pendant les vTaskDelay 
  esp_pm_config_esp32c6_t pm_config = {
    .max_freq_mhz       = 80,
    .min_freq_mhz       = 10,
    .light_sleep_enable = true
  };
  esp_pm_configure(&pm_config);

  syncGroup = xEventGroupCreate();

  xTaskCreate(TaskWiFi,    "TaskWiFi",    4096, NULL, 1, NULL);
  xTaskCreate(TaskSensors, "TaskSensors", 4096, NULL, 1, NULL);

  xEventGroupWaitBits(syncGroup, WIFI_READY_BIT | SENSORS_READY_BIT,
                      pdFALSE, pdTRUE, portMAX_DELAY);

  envois_valeurs(temp_aht, hum_aht, co2_scd, 2);

  Serial.println("Deep sleep 5 minutes...");
  Serial.flush();

  esp_sleep_enable_timer_wakeup(5ULL * 60ULL * 1000000ULL);
  esp_deep_sleep_start();
}

// ------------------------------------------------------------------
// LOOP
// ------------------------------------------------------------------
void loop() {}