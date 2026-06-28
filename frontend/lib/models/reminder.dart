import 'package:cloud_firestore/cloud_firestore.dart';

class Reminder {
  final String id;
  final String uid;
  final String title;
  final String? description;
  final Timestamp? dueDate;

  Reminder({
    required this.id,
    required this.uid,
    required this.title,
    this.description,
    this.dueDate,
  });

  // Factory constructor to create a Reminder from Firestore data
  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: json['id'] as String,
      uid: json['uid'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      dueDate: json['dueDate'] as Timestamp?,
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
    };
  }
}
