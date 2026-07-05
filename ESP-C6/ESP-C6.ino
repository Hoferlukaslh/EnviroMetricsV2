#include <Arduino.h>
#include <esp_sleep.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <Wire.h>
#include "scd4x.h"
#include "AHT10.h"

// Broche pour lire la tension de la batterie (Pont diviseur 10k/10k)
#define BATTERY_PIN A1

AHT10 myAHT10(0x38);

// Sauvegarde en mémoire RTC pour reconnexion WiFi ultra-rapide
RTC_DATA_ATTR uint8_t savedBSSID[6];
RTC_DATA_ATTR uint8_t savedChannel;
RTC_DATA_ATTR bool wifiDataSaved = false;

// Paramètres Réseau
const char* ssid     = "U6-LR2_4";
const char* password = "Ubtn_U6-LR";
const char* server   = "http://192.168.1.240:8080/SendDB.php";

// Variables globales
float temp_aht = 0.0f;
float hum_aht  = 0.0f;
uint16_t co2_scd = 0;
float battery_voltage = 0.0f;

// Drapeau de sécurité
bool mesure_scd_valide = false; 

// ------------------------------------------------------------------
// FONCTION D'ENVOI HTTP
// ------------------------------------------------------------------
bool envois_valeurs(float temperature, float humidite, uint16_t co2, float vbat, int app_id) {
  HTTPClient http;
  String url = String(server)
             + "?temperature=" + String(temperature, 2)
             + "&humidite="    + String(humidite, 2)
             + "&co2="         + String(co2)
             + "&vbat="        + String(vbat, 2)
             + "&app_id="      + String(app_id);

  // Le timeout de 10s évite l'erreur -11 si le serveur API est un peu lent
  http.setTimeout(10000); 
  http.begin(url);
  
  int httpResponseCode = http.GET();
  bool success = (httpResponseCode == HTTP_CODE_OK);

  if (success) Serial.println("Envoi OK : " + url);
  else         Serial.printf("Erreur HTTP : %d\n", httpResponseCode);

  http.end();
  return success;
}

// ------------------------------------------------------------------
// SETUP
// ------------------------------------------------------------------
void setup() {
  Serial.begin(115200);
  Serial.println("\n--- Réveil ESP32-C6 ---");

  // 1. Démarrage du bus I2C (Les capteurs sont alimentés en permanence)
  Wire.begin();

  // 2. Mesure de la tension de la batterie
 // 2. Mesure de la tension de la batterie (Avec calibration d'usine ESP32)
  analogReadResolution(12);
  
  // Utilise la fonction magique qui lit la calibration interne de ta puce (renvoie des mV)
  uint32_t adc_mv = analogReadMilliVolts(BATTERY_PIN); 
  
  // On convertit les millivolts en Volts vus par la broche (ex: 2.05V)
  float v_pin = adc_mv / 1000.0f; 

  // --- TON FACTEUR DE CALIBRATION MULTIMÈTRE ---
  // Théoriquement 2.0f pour un pont 10k/10k. 
  // Mais on va l'ajuster pour coller PARFAITEMENT à ton multimètre !
  float facteur_correction = 2.069f;
  
  battery_voltage = v_pin * facteur_correction; 
  
  Serial.printf("Tension Batterie : %.2fV (Tension sur broche A1 : %.2fV)\n", battery_voltage, v_pin);

  pinMode(14, OUTPUT); 
  digitalWrite(14, LOW);
  
  // 3. Initialisation des capteurs
  Serial.println("Initialisation des capteurs...");
  myAHT10.begin();
  scd4x.begin(Wire, 0x62);

  // ----------------------------------------------------------------
  // RÉVEIL LOGICIEL DU SCD40
  // ----------------------------------------------------------------
  scd4x.wakeUp();
  delay(20); // Temps nécessaire au capteur pour sortir du coma logiciel

  scd4x.stopPeriodicMeasurement();
  delay(500);
  
  // Démarrage de la mesure
  int16_t start_error = scd4x.startPeriodicMeasurement();
  if (start_error) {
    Serial.printf("Alerte: Erreur I2C au démarrage du SCD40: %d\n", start_error);
  }

  // Lecture rapide de l'AHT10 (Lui n'a pas besoin de PowerDown, il consomme 0.25µA en veille)
  temp_aht = myAHT10.readTemperature();
  hum_aht  = myAHT10.readHumidity();

  // Attente de la mesure photoacoustique du SCD40
  Serial.println("Attente de 5s pour le SCD40...");
  delay(5000); 

  bool isDataReady = false;
  int timeout = 0;

  // Boucle d'attente sécurisée
  while (!isDataReady && timeout < 50) { 
    scd4x.getDataReadyStatus(isDataReady);
    if (!isDataReady) {
      delay(100);
      timeout++;
    }
  }

  // Vérification et lecture de la mesure
  if (isDataReady) {
    float t, h;
    int16_t error = scd4x.readMeasurement(co2_scd, t, h);
    if (error == 0 && co2_scd > 0) { 
      mesure_scd_valide = true;
      Serial.printf("Mesure SCD40 OK : %d ppm\n", co2_scd);
    } else {
      Serial.println("Erreur de lecture I2C interne du SCD40.");
    }
  } else {
    Serial.println("Erreur : Timeout SCD4x.");
  }

  // ----------------------------------------------------------------
  // EXTINCTION LOGICIELLE DU SCD40
  // ----------------------------------------------------------------
  scd4x.stopPeriodicMeasurement();
  delay(10);
  scd4x.powerDown(); // Le SCD40 passe en veille ultra-profonde (1 µA)
  Serial.println("Capteur SCD40 endormi logiciellement.");

  // 4. Allumage WiFi & Envoi (uniquement si la mesure est valide)
  if (mesure_scd_valide) {
    Serial.println("Allumage du WiFi...");
    WiFi.mode(WIFI_STA);
    WiFi.persistent(false);
    // WiFi.setTxPower(WIFI_POWER_8_5dBm); // Dé-commente si ta box WiFi est très proche pour économiser l'énergie

    IPAddress staticIP(192, 168, 1, 251);
    IPAddress gateway(192, 168, 1, 1);
    IPAddress subnet(255, 255, 255, 0);
    WiFi.config(staticIP, gateway, subnet);

    if (wifiDataSaved) {
      WiFi.begin(ssid, password, savedChannel, savedBSSID, true);
    } else {
      WiFi.begin(ssid, password);
    }

    int wifi_timeout = 0;
    while (WiFi.status() != WL_CONNECTED && wifi_timeout < 100) { 
      delay(100);
      wifi_timeout++;
    }

    if (WiFi.status() == WL_CONNECTED) {
      Serial.println("WiFi Connecté !");
      memcpy(savedBSSID, WiFi.BSSID(), 6);
      savedChannel  = WiFi.channel();
      wifiDataSaved = true;

      // Envoi des données vers le serveur FastAPI
      envois_valeurs(temp_aht, hum_aht, co2_scd, battery_voltage, 2);
    } else {
      Serial.println("Échec de connexion WiFi.");
    }
    
    // Extinction propre du modem radio
    WiFi.disconnect(true);
    WiFi.mode(WIFI_OFF);
    
  } else {
    Serial.println("Mesure invalide : envoi annulé (pas de WiFi allumé).");
  }

  // 5. Deep Sleep Dynamique
  uint64_t temps_veille_secondes;

  if (mesure_scd_valide) {
    Serial.println("Succès. Deep sleep normal de 5 minutes...");
    temps_veille_secondes = 5 * 60; // 5 minutes
  } else {
    Serial.println("Échec de la mesure. Deep sleep court de 30 secondes pour réessayer...");
    temps_veille_secondes = 30; // 10 secondes
  }

  Serial.flush();
  esp_sleep_enable_timer_wakeup(temps_veille_secondes * 1000000ULL);
  esp_deep_sleep_start();
}

void loop() {}