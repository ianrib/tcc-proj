import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/reminder.dart';
import '../repositories/firestore_repository.dart';
import 'user_provider.dart';

final remindersStreamProvider = StreamProvider<List<Reminder>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return Stream.value([]);
  }
  return FirestoreRepository().remindersForUser(user.uid);
});
