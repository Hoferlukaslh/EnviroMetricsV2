import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'notification_service.dart';

Future<void> initializeBackgroundService() async {
  if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
    return;
  }

  final service = FlutterBackgroundService();

  const AndroidNotificationChannel serviceChannel = AndroidNotificationChannel(
    'envirometrics_service',
    'Surveillance continue',
    description: 'Maintient l\'application active en arrière-plan',
    importance: Importance.low, 
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  
  if (Platform.isAndroid) {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(serviceChannel);
  }

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'envirometrics_service',
      initialNotificationTitle: 'EnviroMetrics',
      initialNotificationContent: 'Démarrage de la surveillance...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(autoStart: false),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  
  await NotificationService().init(requestPermission: false);

  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    
    service.on('stopService').listen((event) {
      service.stopSelf();
    });
  }

  Future<void> checkMetrics() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload(); 
      
      final url = prefs.getString('apiUrl') ?? 'https://env.kreativcam.ch/api';
      final meteoStationId = prefs.getString('meteoStationId') ?? 'DEM';

      // Heartbeat
      final lastTick = prefs.getInt('lastForegroundTick') ?? 0;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final isAppInForeground = (nowMs - lastTick) < 5000;

      try {
        // Récupération de tous les appareils
        final appareils = await ApiService().fetchAppareils(url: url);
        
        bool atLeastOneAlertActive = false;

        // Parcours de chaque appareil
        for (var app in appareils) {
          final appId = app.id;
          final appName = app.nom;

          final notifyCo2 = prefs.getBool('notifyCo2_$appId') ?? false;
          final co2Threshold = prefs.getDouble('co2Threshold_$appId') ?? 900.0;
          final notifyTemp = prefs.getBool('notifyTemp_$appId') ?? false;
          final tempDiff = prefs.getDouble('tempDiff_$appId') ?? 1.0;

          // Passer si aucune alerte n'est configurée pour cette pièce
          if (!notifyCo2 && !notifyTemp) continue;

          atLeastOneAlertActive = true;

          // Téléchargement de la dernière mesure
          final derniereMesure = await ApiService().fetchDerniereMesure(appId, url: url);
          if (derniereMesure == null) continue;

          // Envoi de la notification push uniquement en arrière-plan
          if (!isAppInForeground) {
            
            // Alerte CO2
            final co2AlertSent = prefs.getBool('co2AlertBg_$appId') ?? false;
            if (notifyCo2) {
              if (derniereMesure.co2 > co2Threshold) {
                if (!co2AlertSent) {
                  NotificationService().showNotification(
                    appId * 10 + 1, 
                    "AÉRATION RECOMMANDÉ - $appName",
                    "Danger : Le CO2 a atteint ${derniereMesure.co2} ppm.",
                  );
                  await prefs.setBool('co2AlertBg_$appId', true);
                }
              } else {
                await prefs.setBool('co2AlertBg_$appId', false);
              }
            }

            // Alerte Température
            if (notifyTemp) {
              final tempAlertSent = prefs.getBool('tempAlertSent_$appId') ?? false;
              final meteo = await ApiService().fetchMeteoData(meteoStationId, "280000"); 
              
              if (meteo.currentTemp <= (derniereMesure.temperature - tempDiff)) {
                if (!tempAlertSent) {
                  NotificationService().showNotification(
                    appId * 10 + 2, 
                    "Aération possible - $appName",
                    "Il fait plus frais dehors (${meteo.currentTemp}°C) qu'à l'intérieur (${derniereMesure.temperature}°C).",
                  );
                  await prefs.setBool('tempAlertSent_$appId', true);
                }
              } else {
                await prefs.setBool('tempAlertSent_$appId', false);
              }
            }
          }
        }

        // Mise à jour de la notification de base
        if (service is AndroidServiceInstance) {
          if (!atLeastOneAlertActive) {
            service.setForegroundNotificationInfo(
              title: 'EnviroMetrics',
              content: 'Surveillance en pause (Aucune alerte configurée).',
            );
          } else {
            service.setForegroundNotificationInfo(
              title: 'EnviroMetrics',
              content: 'Surveillance air en cours',
            );
          }
        }
      } catch (e) {
        print("ERREUR ARRIÈRE-PLAN EnviroMetrics: $e");
      }
    }

  await checkMetrics();
  final initialPrefs = await SharedPreferences.getInstance();
  await initialPrefs.setInt('lastBgRunEpoch', DateTime.now().millisecondsSinceEpoch);

  Timer.periodic(const Duration(minutes: 1), (timer) async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.reload(); 
    
    final bgInterval = prefs.getInt('bgInterval') ?? 5; 
    final lastRunEpoch = prefs.getInt('lastBgRunEpoch') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (now - lastRunEpoch >= (bgInterval * 60000) - 10000) {
      await prefs.setInt('lastBgRunEpoch', now);
      await checkMetrics();
    }
  });
}