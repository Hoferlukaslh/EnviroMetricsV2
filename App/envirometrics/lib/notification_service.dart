import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init({bool requestPermission = true}) async {
    if (kIsWeb) return;

    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/launcher_icon');
    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings();
    const LinuxInitializationSettings initializationSettingsLinux = LinuxInitializationSettings(defaultActionName: 'Ouvrir');
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
      linux: initializationSettingsLinux,
    );
    
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    if (Platform.isAndroid) {
      // Changement d'ID de canal pour forcer Android à le recréer
      const AndroidNotificationChannel alertChannel = AndroidNotificationChannel(
        'envirometrics_alerts_v2', 
        'Alertes Aération', 
        description: 'Notifications pour aérer la pièce', 
        importance: Importance.max, 
        playSound: true,
        enableVibration: true,
      );

      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      await androidImplementation?.createNotificationChannel(alertChannel);
      
      if (requestPermission) {
        await androidImplementation?.requestNotificationsPermission();
      }
    }
  }

  Future<void> showNotification(int id, String title, String body) async {
    if (kIsWeb) return;

    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'envirometrics_alerts_v2', // Correspond au canal d'alertes
      'Alertes Aération',
      channelDescription: 'Notifications pour aérer la pièce',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon', 
      playSound: true,
      enableVibration: true,
    );
    
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: DarwinNotificationDetails(),
      linux: LinuxNotificationDetails(),
    );
    
    await flutterLocalNotificationsPlugin.show(id, title, body, platformChannelSpecifics);
  }
}