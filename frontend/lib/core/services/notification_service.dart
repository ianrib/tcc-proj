import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Inicializa os dados de timezone
    tz.initializeTimeZones();
    try {
      final String currentTimeZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(currentTimeZone));
    } catch (e) {
      debugPrint('Não foi possível definir o timezone local: $e. Usando UTC.');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    // Configuração para o Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Configuração geral de inicialização
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _localNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notificação clicada: ${response.payload}');
      },
    );

    // Solicita permissões para o Android 13+ logo ao inicializar se aplicável
    await requestPermissions();
  }

  Future<void> requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _localNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      await androidImplementation.requestExactAlarmsPermission();
    }
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    // Se a data de agendamento já passou, não agenda
    if (scheduledDate.isBefore(DateTime.now())) {
      debugPrint('A data agendada $scheduledDate já passou. Notificação não criada.');
      return;
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'lembretes_channel_id',
      'Lembretes e Consultas',
      channelDescription: 'Canal de notificações para lembretes de medicamentos e consultas médicas',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    final tz.TZDateTime tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

    try {
      await _localNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzScheduledDate,
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      debugPrint('Notificação agendada com sucesso: ID $id para $tzScheduledDate');
    } catch (e) {
      debugPrint('Erro ao agendar notificação ID $id: $e');
    }
  }

  Future<void> cancelNotification(int id) async {
    await _localNotificationsPlugin.cancel(id);
    debugPrint('Notificação cancelada com sucesso: ID $id');
  }

  Future<void> cancelAllNotifications() async {
    await _localNotificationsPlugin.cancelAll();
    debugPrint('Todas as notificações foram canceladas.');
  }
}
