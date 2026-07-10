import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'notification_service.dart';

Future<void> initializeBackgroundService() async {
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
    
    final url = prefs.getString('apiUrl') ?? 'https://env.kreativcam.ch/api';
    final appId = prefs.getInt('appId') ?? 1;
    final appName = prefs.getString('appName') ?? "Pièce";
    
    final notifyCo2 = prefs.getBool('notifyCo2_$appId') ?? false;
    final co2Threshold = prefs.getDouble('co2Threshold_$appId') ?? 900.0;
    
    final notifyTemp = prefs.getBool('notifyTemp_$appId') ?? false;
    final tempDiff = prefs.getDouble('tempDiff_$appId') ?? 1.0;
    final meteoStationId = prefs.getString('meteoStationId') ?? 'DEM';

    if (service is AndroidServiceInstance) {
      final now = DateTime.now();
      final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
      service.setForegroundNotificationInfo(
        title: 'EnviroMetrics',
        content: 'Surveillance active. Dernier scan à $timeStr',
      );
    }

    if (!notifyCo2 && !notifyTemp) return;

    try {
      final mesures = await ApiService().fetchMesures(appId, 0.125, url: url);
      if (mesures.isEmpty) return;
      
      final derniereMesure = mesures.last;

      if (notifyCo2 && derniereMesure.co2 > co2Threshold) {
        NotificationService().showNotification(
          appId * 10 + 1,
          "Aération recommandée",
          "Le CO2 a atteint ${derniereMesure.co2} ppm dans '$appName'.",
        );
      }

      if (notifyTemp) {
        final meteo = await ApiService().fetchMeteoData(meteoStationId, "280000"); 
        if (meteo.currentTemp <= (derniereMesure.temperature - tempDiff)) {
          NotificationService().showNotification(
            appId * 10 + 2,
            "Aération possible",
            "Il fait plus frais dehors (${meteo.currentTemp}°C) que dans '$appName' (${derniereMesure.temperature}°C).",
          );
        }
      }
    } catch (e) {
      // Ignorer silencieusement
    }
  }

  await checkMetrics();

  Timer.periodic(const Duration(minutes: 3), (timer) async {
    await checkMetrics();
  });
}