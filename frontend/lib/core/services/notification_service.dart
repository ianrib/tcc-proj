import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // IDs derivados para as 3 notificações de consulta
  // base:    notificação no horário exato (medicamento)
  // base+1:  30 min antes (consulta)
  // base+2:  15 min antes (consulta)
  // base+3:   5 min antes (consulta)
  static int _id30(int base) => (base + 1) & 0x7FFFFFFF;
  static int _id15(int base) => (base + 2) & 0x7FFFFFFF;
  static int _id5(int base)  => (base + 3) & 0x7FFFFFFF;

  static const int inactivityNotificationId = 999999;

  Future<void> init() async {
    tz.initializeTimeZones();
    // Usa fuso horário de Brasília diretamente (sem flutter_timezone)
    tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notificação clicada: ${response.payload}');
      },
    );

    // Cria os canais de notificação necessários no Android
    final androidImplementation = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(_lembreteChannel);
      await androidImplementation.createNotificationChannel(_consultaChannel);
      await androidImplementation.createNotificationChannel(_inactivityChannel);
      debugPrint('Canais de notificação registrados com sucesso no Android.');
    }

    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.requestNotificationsPermission();
      await android.requestExactAlarmsPermission();
    }
  }

  // ---------------------------------------------------------------------------
  // Canal Android e Detalhes
  // ---------------------------------------------------------------------------
  static const _lembreteChannel = AndroidNotificationChannel(
    'lembretes_channel_id',
    'Lembretes e Medicamentos',
    description: 'Notificações de hora do medicamento',
    importance: Importance.max,
    playSound: true,
  );

  static const _consultaChannel = AndroidNotificationChannel(
    'consultas_channel_id',
    'Consultas Médicas',
    description: 'Avisos de consultas em 30, 15 e 5 minutos',
    importance: Importance.max,
    playSound: true,
  );

  static const _inactivityChannel = AndroidNotificationChannel(
    'inactivity_channel_id',
    'Mensagens de Apoio',
    description: 'Notificações enviadas se você ficar muito tempo sem conversar',
    importance: Importance.max,
    playSound: true,
  );

  static const _lembreteDetails = AndroidNotificationDetails(
    'lembretes_channel_id',
    'Lembretes e Medicamentos',
    channelDescription: 'Notificações de hora do medicamento',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
  );

  static const _consultaDetails = AndroidNotificationDetails(
    'consultas_channel_id',
    'Consultas Médicas',
    channelDescription: 'Avisos de consultas em 30, 15 e 5 minutos',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
  );

  // ---------------------------------------------------------------------------
  // Agenda UMA notificação (usada para medicamentos)
  // ---------------------------------------------------------------------------
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
    bool repeat = false,
    String? repeatFrequency,
  }) async {
    final now = DateTime.now();

    // Se for repetitivo, a data inicial scheduledDate precisa estar no futuro para o primeiro disparo
    var targetDate = scheduledDate;
    if (repeat && repeatFrequency != null) {
      while (targetDate.isBefore(now)) {
        if (repeatFrequency == 'diario') {
          targetDate = targetDate.add(const Duration(days: 1));
        } else if (repeatFrequency == 'semanal') {
          targetDate = targetDate.add(const Duration(days: 7));
        } else if (repeatFrequency == 'mensal') {
          targetDate = DateTime(targetDate.year, targetDate.month + 1, targetDate.day, targetDate.hour, targetDate.minute);
        }
      }
    } else if (scheduledDate.isBefore(now)) {
      debugPrint('Data $scheduledDate já passou. Notificação ignorada.');
      return;
    }

    final tzDate = tz.TZDateTime.from(targetDate, tz.local);

    DateTimeComponents? matchComponents;
    if (repeat && repeatFrequency != null) {
      if (repeatFrequency == 'diario') {
        matchComponents = DateTimeComponents.time;
      } else if (repeatFrequency == 'semanal') {
        matchComponents = DateTimeComponents.dayOfWeekAndTime;
      } else if (repeatFrequency == 'mensal') {
        matchComponents = DateTimeComponents.dayOfMonthAndTime;
      }
    }

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzDate,
        const NotificationDetails(android: _lembreteDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: matchComponents,
        payload: payload,
      );
      debugPrint('Notificação agendada: ID $id para $tzDate (Repete: $repeatFrequency)');
    } catch (e) {
      debugPrint('Erro ao agendar notificação ID $id: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Agenda TRÊS notificações para consultas (30 min, 15 min e 5 min antes)
  // ---------------------------------------------------------------------------
  Future<void> scheduleConsultaNotifications({
    required int baseId,
    required String consultaTitle,
    required String? descricao,
    required DateTime consultaDateTime,
    bool repeat = false,
    String? repeatFrequency,
  }) async {
    final now = DateTime.now();
    final body = descricao?.isNotEmpty == true
        ? descricao!
        : 'Prepare-se para sua consulta: $consultaTitle';

    final List<_ConsultaAlarm> alarms = [
      _ConsultaAlarm(
        id: _id30(baseId),
        scheduledAt: consultaDateTime.subtract(const Duration(minutes: 30)),
        title: '🗓 Consulta em 30 minutos',
        body: body,
      ),
      _ConsultaAlarm(
        id: _id15(baseId),
        scheduledAt: consultaDateTime.subtract(const Duration(minutes: 15)),
        title: '🗓 Consulta em 15 minutos',
        body: body,
      ),
      _ConsultaAlarm(
        id: _id5(baseId),
        scheduledAt: consultaDateTime.subtract(const Duration(minutes: 5)),
        title: '🗓 Consulta em 5 minutos!',
        body: body,
      ),
      _ConsultaAlarm(
        id: baseId,
        scheduledAt: consultaDateTime,
        title: '🗓 Hora da Consulta: $consultaTitle',
        body: body,
      ),
    ];

    DateTimeComponents? matchComponents;
    if (repeat && repeatFrequency != null) {
      if (repeatFrequency == 'diario') {
        matchComponents = DateTimeComponents.time;
      } else if (repeatFrequency == 'semanal') {
        matchComponents = DateTimeComponents.dayOfWeekAndTime;
      } else if (repeatFrequency == 'mensal') {
        matchComponents = DateTimeComponents.dayOfMonthAndTime;
      }
    }

    for (final alarm in alarms) {
      var targetDate = alarm.scheduledAt;
      if (repeat && repeatFrequency != null) {
        while (targetDate.isBefore(now)) {
          if (repeatFrequency == 'diario') {
            targetDate = targetDate.add(const Duration(days: 1));
          } else if (repeatFrequency == 'semanal') {
            targetDate = targetDate.add(const Duration(days: 7));
          } else if (repeatFrequency == 'mensal') {
            targetDate = DateTime(targetDate.year, targetDate.month + 1, targetDate.day, targetDate.hour, targetDate.minute);
          }
        }
      } else if (alarm.scheduledAt.isBefore(now)) {
        debugPrint('Alarme ${alarm.id} (${alarm.title}) já passou. Ignorado.');
        continue;
      }

      final tzDate = tz.TZDateTime.from(targetDate, tz.local);
      try {
        await _plugin.zonedSchedule(
          alarm.id,
          alarm.title,
          alarm.body,
          tzDate,
          const NotificationDetails(android: _consultaDetails),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: matchComponents,
          payload: 'consulta:$baseId',
        );
        debugPrint('Alarme de consulta agendado: ID ${alarm.id} → ${alarm.title} em $tzDate (Repete: $repeatFrequency)');
      } catch (e) {
        debugPrint('Erro ao agendar alarme de consulta ID ${alarm.id}: $e');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Agenda notificação de inatividade (caso fique sem mandar mensagens)
  // ---------------------------------------------------------------------------
  Future<void> scheduleInactivityNotification({
    Duration duration = const Duration(hours: 24),
  }) async {
    // 1. Cancela a notificação anterior para resetar o temporizador
    await cancelNotification(inactivityNotificationId);

    // 2. Escolhe uma mensagem aleatória
    final messages = [
      "Como você está se sentindo hoje? Que tal conversarmos um pouco?",
      "Faz um tempo que não nos falamos. Como você está?",
      "Gostaria de conversar um pouco hoje? Estou aqui para te ouvir.",
      "Como foi o seu dia? Se quiser desabafar, estou por aqui.",
      "Passando para saber se está tudo bem. Quer bater um papo?",
    ];
    // Semente simples baseada nos milissegundos atuais
    final index = DateTime.now().millisecond % messages.length;
    final randomMessage = messages[index];

    final scheduledDate = DateTime.now().add(duration);
    final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);

    try {
      await _plugin.zonedSchedule(
        inactivityNotificationId,
        'Pensando em você...',
        randomMessage,
        tzDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'inactivity_channel_id',
            'Mensagens de Apoio',
            channelDescription: 'Notificações enviadas se você ficar muito tempo sem conversar',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint('Notificação de inatividade agendada para: $tzDate');
    } catch (e) {
      debugPrint('Erro ao agendar notificação de inatividade: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Cancelamentos
  // ---------------------------------------------------------------------------
  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
    debugPrint('Notificação cancelada: ID $id');
  }

  /// Cancela as 4 notificações de consulta derivadas do [baseId] (incluindo horário exato)
  Future<void> cancelConsultaNotifications(int baseId) async {
    await Future.wait([
      _plugin.cancel(baseId),
      _plugin.cancel(_id30(baseId)),
      _plugin.cancel(_id15(baseId)),
      _plugin.cancel(_id5(baseId)),
    ]);
    debugPrint('Notificações de consulta canceladas para baseId $baseId');
  }

  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
    debugPrint('Todas as notificações canceladas.');
  }
}

// Helper interno
class _ConsultaAlarm {
  final int id;
  final DateTime scheduledAt;
  final String title;
  final String body;

  const _ConsultaAlarm({
    required this.id,
    required this.scheduledAt,
    required this.title,
    required this.body,
  });
}
