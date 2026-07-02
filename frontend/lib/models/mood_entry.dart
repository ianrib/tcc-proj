class MoodEntry {
  final String id;
  final String userId;
  final int score;
  final String emoji;
  final String description;
  final List<String> tags;
  final DateTime timestamp;

  MoodEntry({
    required this.id,
    required this.userId,
    required this.score,
    required this.emoji,
    required this.description,
    required this.tags,
    required this.timestamp,
  });

  factory MoodEntry.fromJson(Map<String, dynamic> json, {String? id}) {
    DateTime parsedDate;
    final timestampRaw = json['timestamp'];
    if (timestampRaw != null) {
      if (timestampRaw is String) {
        parsedDate = DateTime.parse(timestampRaw);
      } else {
        // Se vier do Firestore no formato de map com seconds/nanoseconds ou toDate
        parsedDate = DateTime.tryParse(timestampRaw.toString()) ?? DateTime.now();
      }
    } else {
      parsedDate = DateTime.now();
    }

    return MoodEntry(
      id: id ?? json['id'] ?? '',
      userId: json['userId'] ?? '',
      score: json['score'] ?? 5,
      emoji: json['emoji'] ?? '😐',
      description: json['description'] ?? '',
      tags: List<String>.from(json['tags'] ?? []),
      timestamp: parsedDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'score': score,
      'emoji': emoji,
      'description': description,
      'tags': tags,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
