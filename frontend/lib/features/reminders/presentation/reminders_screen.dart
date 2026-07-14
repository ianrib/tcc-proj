import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gaia/core/widgets/app_drawer.dart';
import '../../../core/repositories/firestore_repository.dart';
import '../../../models/reminder.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/providers/reminder_providers.dart';
import '../../../core/services/notification_service.dart';

class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddReminderDialog(BuildContext context, String initialType) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();
    String type = initialType;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      type == 'remedio' ? 'Novo Lembrete de Medicamento' : 'Novo Lembrete de Consulta',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: type == 'remedio' ? 'Nome do Medicamento' : 'Nome/Especialidade do Médico',
                        prefixIcon: Icon(type == 'remedio' ? Icons.medication : Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(
                        labelText: 'Descrição / Observações',
                        prefixIcon: Icon(Icons.description_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Seletor de Tipo
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ChoiceChip(
                          label: const Text('Medicamento'),
                          selected: type == 'remedio',
                          onSelected: (selected) {
                            if (selected) setModalState(() => type = 'remedio');
                          },
                        ),
                        const SizedBox(width: 12),
                        ChoiceChip(
                          label: const Text('Consulta'),
                          selected: type == 'consulta',
                          onSelected: (selected) {
                            if (selected) setModalState(() => type = 'consulta');
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Seletor de Data e Hora
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                setModalState(() => selectedDate = picked);
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_today, size: 16),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}',
                                    style: const TextStyle(fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              showCupertinoModalPopup(
                                context: context,
                                builder: (BuildContext context) {
                                  return Container(
                                    height: 320,
                                    color: theme.cardColor,
                                    child: Column(
                                      children: [
                                        Container(
                                          color: theme.brightness == Brightness.light
                                              ? Colors.grey.shade100
                                              : theme.scaffoldBackgroundColor,
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              GestureDetector(
                                                onTap: () => Navigator.of(context).pop(),
                                                child: Text(
                                                  'Voltar',
                                                  style: TextStyle(
                                                    color: theme.colorScheme.secondary,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              GestureDetector(
                                                onTap: () => Navigator.of(context).pop(),
                                                child: Text(
                                                  'Confirmar',
                                                  style: TextStyle(
                                                    color: theme.colorScheme.primary,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          child: CupertinoTheme(
                                            data: CupertinoThemeData(
                                              brightness: theme.brightness,
                                              textTheme: CupertinoTextThemeData(
                                                dateTimePickerTextStyle: TextStyle(
                                                  color: theme.colorScheme.onSurface,
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            child: CupertinoDatePicker(
                                              mode: CupertinoDatePickerMode.time,
                                              initialDateTime: DateTime(
                                                2020, 1, 1,
                                                selectedTime.hour,
                                                selectedTime.minute,
                                              ),
                                              use24hFormat: true,
                                              onDateTimeChanged: (DateTime newDateTime) {
                                                setModalState(() {
                                                  selectedTime = TimeOfDay(
                                                    hour: newDateTime.hour,
                                                    minute: newDateTime.minute,
                                                  );
                                                });
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.access_time, size: 16),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    selectedTime.format(context),
                                    style: const TextStyle(fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        final title = titleController.text.trim();
                        if (title.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Por favor, preencha o título.')),
                          );
                          return;
                        }

                        final user = ref.read(currentUserProvider);
                        if (user == null) return;

                        final finalDateTime = DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day,
                          selectedTime.hour,
                          selectedTime.minute,
                        );

                        final id = FirebaseFirestore.instance.collection('reminders').doc().id;
                        final reminder = Reminder(
                          id: id,
                          uid: user.uid,
                          title: title,
                          description: descController.text.trim().isEmpty ? null : descController.text.trim(),
                          dueDate: Timestamp.fromDate(finalDateTime),
                          type: type,
                        );

                        await FirestoreRepository().addReminder(reminder);

                        // Agendar notificação local
                        final int notificationId = id.hashCode & 0x7FFFFFFF;

                        if (type == 'remedio') {
                          // Medicamento: uma única notificação no horário exato
                          await NotificationService().scheduleNotification(
                            id: notificationId,
                            title: 'Hora do Medicamento: $title',
                            body: descController.text.trim().isEmpty
                                ? 'Está na hora de tomar seu medicamento.'
                                : descController.text.trim(),
                            scheduledDate: finalDateTime,
                          );
                        } else {
                          // Consulta: notificações em 30, 15 e 5 minutos antes
                          await NotificationService().scheduleConsultaNotifications(
                            baseId: notificationId,
                            consultaTitle: title,
                            descricao: descController.text.trim().isEmpty
                                ? null
                                : descController.text.trim(),
                            consultaDateTime: finalDateTime,
                          );
                        }

                        // Verifica se o widget ainda está montado antes de usar context
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                      },
                      child: const Text('Salvar Lembrete', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remindersAsync = ref.watch(remindersStreamProvider);

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Meus Lembretes', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.grid_view, color: theme.colorScheme.secondary),
            tooltip: 'Menu',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.secondary,
          labelColor: theme.colorScheme.secondary,
          unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          tabs: const [
            Tab(icon: Icon(Icons.medication), text: 'Medicamentos'),
            Tab(icon: Icon(Icons.calendar_month), text: 'Consultas'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: theme.colorScheme.secondary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
        onPressed: () {
          final activeType = _tabController.index == 0 ? 'remedio' : 'consulta';
          _showAddReminderDialog(context, activeType);
        },
      ),
      body: remindersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erro ao carregar lembretes: $err')),
        data: (reminders) {
          final meds = reminders.where((r) => r.type == 'remedio').toList();
          final consults = reminders.where((r) => r.type == 'consulta').toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildReminderList(meds, 'remedio'),
              _buildReminderList(consults, 'consulta'),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReminderList(List<Reminder> list, String type) {
    final theme = Theme.of(context);

    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                type == 'remedio' ? Icons.medication_outlined : Icons.calendar_month_outlined,
                size: 64,
                color: theme.colorScheme.secondary.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 16),
              Text(
                type == 'remedio' ? 'Nenhum medicamento agendado.' : 'Nenhuma consulta agendada.',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Toque no botão "+" no canto inferior para criar um novo lembrete.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.55)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final reminder = list[index];
        final dt = reminder.dueDate?.toDate();
        final dateStr = dt != null
            ? '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} às ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
            : 'Sem data/hora';

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
              child: Icon(
                type == 'remedio' ? Icons.medication : Icons.calendar_month,
                color: theme.colorScheme.primary,
              ),
            ),
            title: Text(
              reminder.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (reminder.description != null && reminder.description!.isNotEmpty) ...[
                  Text(reminder.description!),
                  const SizedBox(height: 2),
                ],
                Text(
                  dateStr,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            trailing: IconButton(
              icon: Icon(Icons.delete_outline, color: theme.colorScheme.error.withValues(alpha: 0.7)),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text('Excluir Lembrete'),
                      content: const Text('Tem certeza que deseja remover este lembrete?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancelar'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                          child: const Text('Excluir'),
                        ),
                      ],
                    );
                  },
                );
                if (confirm == true) {
                  await FirestoreRepository().deleteReminder(reminder.id);
                  final int notificationId = reminder.id.hashCode & 0x7FFFFFFF;
                  if (type == 'consulta') {
                    // Cancela as 3 notificações (30, 15 e 5 min antes)
                    await NotificationService().cancelConsultaNotifications(notificationId);
                  } else {
                    await NotificationService().cancelNotification(notificationId);
                  }
                }
              },
            ),
          ),
        );
      },
    );
  }
}
