import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings: settings);
  }

  static Future<void> showSavingsNotification({
    required String goalName,
    required double amount,
    required double currentAmount,
    required double targetAmount,
  }) async {
    final fmt = amount.toStringAsFixed(2);
    final progress = (currentAmount / targetAmount * 100).toStringAsFixed(1);

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'savings_channel',
        'Metas de ahorro',
        channelDescription: 'Notificaciones de abonos automáticos',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    );

    await _plugin.show(
      id: 0,
      title: 'Abono automático realizado',
      body: 'Se abonaron S/ $fmt a "$goalName" · Progreso: $progress%',
      notificationDetails: details,
    );
  }
}