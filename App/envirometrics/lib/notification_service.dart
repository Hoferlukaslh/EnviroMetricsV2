import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // AJOUT d'un paramètre optionnel pour désactiver la demande graphique en arrière-plan
  Future<void> init({bool requestPermission = true}) async {
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
      const AndroidNotificationChannel alertChannel = AndroidNotificationChannel(
        'envirometrics_alerts', 
        'Alertes Aération', 
        description: 'Notifications pour aérer la pièce', 
        importance: Importance.max, 
      );

      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      await androidImplementation?.createNotificationChannel(alertChannel);
      
      // On ne demande la permission QUE si l'application est ouverte au premier plan
      if (requestPermission) {
        await androidImplementation?.requestNotificationsPermission();
      }
    }
  }

  Future<void> showNotification(int id, String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'envirometrics_alerts', 
      'Alertes Aération',
      channelDescription: 'Notifications pour aérer la pièce',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon', 
    );
    
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: DarwinNotificationDetails(),
      linux: LinuxNotificationDetails(),
    );
    
    await flutterLocalNotificationsPlugin.show(id, title, body, platformChannelSpecifics);
  }
}