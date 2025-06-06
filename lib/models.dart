import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model for a Student or Group.
class StudentGroup {
  String? id; // Document ID from Firestore
  String name;
  bool isGroup;
  int score;
  List<ScoreHistoryEntry> history;
  String classId;
  List<String>? memberIds; // Only for groups
  bool isArchived; // New field for archiving

  // Static constant for the fixed initial score, available globally to StudentGroup instances
  static const int fixedInitialScore = 100;

  StudentGroup({
    this.id,
    required this.name,
    required this.isGroup,
    required this.score,
    required this.history,
    required this.classId,
    this.memberIds,
    this.isArchived = false, // Default to not archived
  });

  /// Factory constructor to create a `StudentGroup` from a Firestore Map.
  factory StudentGroup.fromMap(Map<String, dynamic> map, {String? id}) {
    return StudentGroup(
      id: id,
      name: map['name'] as String,
      isGroup: map['isGroup'] as bool,
      score: map['score'] as int,
      history: (map['history'] as List<dynamic>?)
          ?.map((e) => ScoreHistoryEntry.fromMap(e as Map<String, dynamic>))
          .toList() ??
          [],
      classId: map['classId'] as String,
      memberIds: (map['memberIds'] as List<dynamic>?)?.map((e) => e as String).toList(),
      isArchived: map['isArchived'] as bool? ?? false, // Default to false if not present
    );
  }

  /// Converts a `StudentGroup` instance to a Map for Firestore.
  Map<String, dynamic> toMap() { // <--- CORRECTED: Changed toFirestore() to toMap()
    return {
      'name': name,
      'isGroup': isGroup,
      'score': score,
      'history': history.map((e) => e.toMap()).toList(),
      'classId': classId,
      'memberIds': memberIds,
      'isArchived': isArchived,
    };
  }

  /// Helper method to calculate growth metrics consistently.
  /// Uses a fixed initial score of 100 for net growth baseline.
  /// Calculates total increment and total decrement from the entire history.
  Map<String, int> calculateGrowthMetrics() {
    // Net growth baseline is always fixedInitialScore (100)
    final int netGrowth = score - fixedInitialScore;

    int totalIncrement = 0;
    int totalDecrement = 0;

    // The starting score for cumulative increment/decrement calculation.
    // If history is not empty, use the first history entry's score.
    // Otherwise, use the fixed initial score (100).
    int currentCumulativeScore = history.isNotEmpty ? history.first.score : fixedInitialScore;

    // Calculate cumulative increment and decrement from history entries
    for (int i = 0; i < history.length; i++) {
      final int entryScore = history[i].score;
      final int change = entryScore - currentCumulativeScore;

      if (change > 0) {
        totalIncrement += change;
      } else if (change < 0) { // Only negative changes contribute to decrement
        totalDecrement += change; // Add negative value
      }
      currentCumulativeScore = entryScore; // Update for next iteration
    }

    // Account for the change from the last history entry to the current score
    // If history is empty, this accounts for the change from fixedInitialScore to current score
    final int finalChange = score - currentCumulativeScore;
    if (finalChange > 0) {
      totalIncrement += finalChange;
    } else if (finalChange < 0) {
      totalDecrement += finalChange;
    }

    return {
      'initialScore': fixedInitialScore, // The baseline initial score used for net growth
      'netGrowth': netGrowth,
      'totalIncrement': totalIncrement,
      'totalDecrement': totalDecrement,
      'currentScore': score, // The current score of the student/group
    };
  }
}

/// Data model for an individual score history entry.
class ScoreHistoryEntry {
  int score;
  DateTime timestamp;
  String? reason; // Reason for score change (e.g., 'reward', 'penalty')
  String? customComment; // Optional custom comment for the entry

  ScoreHistoryEntry({
    required this.score,
    required this.timestamp,
    this.reason,
    this.customComment,
  });

  /// Factory constructor to create a `ScoreHistoryEntry` from a Firestore Map.
  factory ScoreHistoryEntry.fromMap(Map<String, dynamic> map) {
    return ScoreHistoryEntry(
      score: map['score'] as int,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      reason: map['reason'] as String?,
      customComment: map['customComment'] as String?,
    );
  }

  /// Converts a `ScoreHistoryEntry` instance to a Map for Firestore.
  Map<String, dynamic> toMap() {
    return {
      'score': score,
      'timestamp': Timestamp.fromDate(timestamp),
      'reason': reason,
      'customComment': customComment,
    };
  }
}

/// Data model for an error log, to be sent to a server for monitoring.
class AppErrorLog {
  String message;
  String stackTrace;
  String platform;
  String? userId;
  String? userEmail;
  DateTime timestamp;
  String? customMessage;

  AppErrorLog({
    required this.message,
    required this.stackTrace,
    required this.platform,
    this.userId,
    this.userEmail,
    required this.timestamp,
    this.customMessage,
  });

  /// Converts an `AppErrorLog` instance to a Map for sending to a server.
  Map<String, dynamic> toMap() {
    return {
      'message': message,
      'stackTrace': stackTrace,
      'platform': platform,
      'userId': userId,
      'userEmail': userEmail,
      'timestamp': timestamp.toIso8601String(), // ISO 8601 for easy parsing
      'customMessage': customMessage,
    };
  }
}

/// Data model for shared report links.
class SharedReport {
  String id;
  String classId;
  DateTime generatedAt;
  String? generatorUserId;
  bool active; // Can be deactivated by admin

  SharedReport({
    required this.id,
    required this.classId,
    required this.generatedAt,
    this.generatorUserId,
    this.active = true,
  });

  /// Factory constructor to create a `SharedReport` from a Firestore Map.
  factory SharedReport.fromMap(Map<String, dynamic> map, {String? id}) {
    return SharedReport(
      id: id ?? map['id'] as String,
      classId: map['classId'] as String,
      generatedAt: (map['generatedAt'] as Timestamp).toDate(),
      generatorUserId: map['generatorUserId'] as String?,
      active: map['active'] as bool? ?? true, // Default to true if not present
    );
  }

  /// Converts a `SharedReport` instance to a Map for Firestore.
  Map<String, dynamic> toMap() { // <--- CORRECTED: Changed toFirestore() to toMap()
    return {
      'id': id,
      'classId': classId,
      'generatedAt': Timestamp.fromDate(generatedAt),
      'generatorUserId': generatorUserId,
      'active': active,
    };
  }
}

/// Data model for a Winner.
class Winner {
  String? id; // Document ID from Firestore
  String studentGroupId; // ID of the winning student/group
  String studentGroupName;
  String classId;
  int score;
  DateTime timestamp;
  String? photoUrl; // URL to winner photo in Firebase Storage <--- CORRECTED: Changed imageUrl to photoUrl

  Winner({
    this.id,
    required this.studentGroupId,
    required this.studentGroupName,
    required this.classId,
    required this.score,
    required this.timestamp,
    this.photoUrl, // <--- CORRECTED: Changed imageUrl to photoUrl
  });

  /// Factory constructor to create a `Winner` from a Firestore Map.
  factory Winner.fromMap(Map<String, dynamic> map, {String? id}) {
    return Winner(
      id: id,
      studentGroupId: map['studentGroupId'] as String,
      studentGroupName: map['studentGroupName'] as String,
      classId: map['classId'] as String,
      score: map['score'] as int,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      photoUrl: map['photoUrl'] as String?, // <--- CORRECTED: Changed imageUrl to photoUrl
    );
  }

  /// Converts a `Winner` instance to a Map for Firestore.
  Map<String, dynamic> toMap() { // <--- CORRECTED: Changed toFirestore() to toMap()
    return {
      'studentGroupId': studentGroupId,
      'studentGroupName': studentGroupName,
      'classId': classId,
      'score': score,
      'timestamp': Timestamp.fromDate(timestamp),
      'photoUrl': photoUrl, // <--- CORRECTED: Changed imageUrl to photoUrl
    };
  }
}

/// Data model for App Activities (e.g., student added, score updated, winner declared).
class AppActivity {
  String? id; // Document ID from Firestore
  String activityType; // e.g., 'student_added', 'score_updated', 'winner_declared' <--- CORRECTED: Changed action to activityType
  String description; // New field for detailed description
  DateTime timestamp;
  String classId; // New field for class ID
  String? userId; // User who performed the activity
  Map<String, dynamic>? details; // Optional additional details

  AppActivity({
    this.id,
    required this.activityType, // <--- CORRECTED: Changed action to activityType
    required this.description, // New required field
    required this.timestamp,
    required this.classId, // New required field
    this.userId,
    this.details,
  });

  /// Factory constructor to create an `AppActivity` from a Firestore Map.
  factory AppActivity.fromMap(Map<String, dynamic> map, {String? id}) {
    return AppActivity(
      id: id,
      activityType: map['activityType'] as String? ?? 'unknown_activity', // Handle null or missing
      description: map['description'] as String? ?? 'No description provided.', // Handle null or missing
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      classId: map['classId'] as String? ?? 'unknown_class', // Handle null or missing
      userId: map['userId'] as String?,
      details: map['details'] as Map<String, dynamic>?,
    );
  }

  /// Converts an `AppActivity` instance to a Map for Firestore.
  Map<String, dynamic> toMap() { // <--- CORRECTED: Changed toFirestore() to toMap()
    return {
      'activityType': activityType, // <--- CORRECTED: Changed action to activityType
      'description': description, // New field
      'timestamp': Timestamp.fromDate(timestamp),
      'classId': classId, // New field
      'userId': userId,
      'details': details,
    };
  }
}
