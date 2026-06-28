import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/reminder.dart';

class FirestoreRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Salva um lembrete (cria ou atualiza)
  Future<void> addReminder(Reminder reminder) async {
    await _db
        .collection('reminders')
        .doc(reminder.id)            // usa id próprio ou gera automático
        .set(reminder.toJson());
  }

  // Stream de lembretes do usuário logado
  Stream<List<Reminder>> remindersForUser(String uid) {
    return _db
        .collection('reminders')
        .where('uid', isEqualTo: uid)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Reminder.fromJson(doc.data()))
            .toList());
  }
}
