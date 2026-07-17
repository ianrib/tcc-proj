import 'package:cloud_firestore/cloud_firestore.dart';

class Reminder {
  final String id;
  final String uid;
  final String title;
  final String? description;
  final Timestamp? dueDate;
  final String type; // 'remedio' ou 'consulta'
  final bool repeat;
  final String? repeatFrequency; // 'diario', 'semanal', 'mensal'

  Reminder({
    required this.id,
    required this.uid,
    required this.title,
    this.description,
    this.dueDate,
    this.type = 'remedio',
    this.repeat = false,
    this.repeatFrequency,
  });

  // Factory constructor to create a Reminder from Firestore data
  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: json['id']?.toString() ?? '',
      uid: json['uid']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Lembrete',
      description: json['description'] as String?,
      dueDate: json['dueDate'] as Timestamp?,
      type: (json['type'] as String?) ?? 'remedio',
      repeat: json['repeat'] as bool? ?? false,
      repeatFrequency: json['repeatFrequency'] as String?,
    );
  }

  // Convert Reminder instance to a map for Firestore storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uid': uid,
      'title': title,
      if (description != null) 'description': description,
      if (dueDate != null) 'dueDate': dueDate,
      'type': type,
      'repeat': repeat,
      if (repeatFrequency != null) 'repeatFrequency': repeatFrequency,
    };
  }
}
