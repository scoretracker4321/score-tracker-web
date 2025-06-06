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
      isArchived: map['isArchived'] as bool? ?? false, // Handle null for old data
    );
  }

  /// Converts a `StudentGroup` instance to a Map for Firestore.
  Map<String, dynamic> toFirestore() {
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
}

/// Data model for a single score history entry.
class ScoreHistoryEntry {
  int score;
  DateTime timestamp;
  String? reason;
  String? customComment;

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
      timestamp: (map['timestamp'] as Timestamp).toDate(), // Convert Firestore Timestamp to DateTime
      reason: map['reason'] as String?,
      customComment: map['customComment'] as String?,
    );
  }

  /// Converts a `ScoreHistoryEntry` instance to a Map for Firestore.
  Map<String, dynamic> toMap() {
    return {
      'score': score,
      'timestamp': Timestamp.fromDate(timestamp), // Convert DateTime to Firestore Timestamp
      'reason': reason,
      'customComment': customComment,
    };
  }
}

/// Data model for an application activity log entry.
class AppActivity {
  String id;
  String action;
  DateTime timestamp;
  Map<String, dynamic> details;

  AppActivity({
    required this.id,
    required this.action,
    required this.timestamp,
    this.details = const {},
  });

  /// Factory constructor to create an `AppActivity` from a Firestore Map.
  factory AppActivity.fromMap(Map<String, dynamic> map, {String? id}) {
    return AppActivity(
      id: id ?? map['id'] as String,
      action: map['action'] as String,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      details: (map['details'] as Map<String, dynamic>?) ?? {},
    );
  }

  /// Converts an `AppActivity` instance to a Map for Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'action': action,
      'timestamp': Timestamp.fromDate(timestamp),
      'details': details,
    };
  }
}

/// Data model for a declared winner.
class Winner {
  String? id; // Document ID from Firestore
  String studentGroupId; // ID of the student/group that won
  String studentGroupName;
  int score;
  DateTime timestamp;
  String classId;
  String? imageUrl; // Optional: URL to a winner photo

  Winner({
    this.id,
    required this.studentGroupId,
    required this.studentGroupName,
    required this.score,
    required this.timestamp,
    required this.classId,
    this.imageUrl,
  });

  /// Factory constructor to create a `Winner` from a Firestore Map.
  factory Winner.fromMap(Map<String, dynamic> map, {String? id}) {
    return Winner(
      id: id,
      studentGroupId: map['studentGroupId'] as String,
      studentGroupName: map['studentGroupName'] as String,
      score: map['score'] as int,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      classId: map['classId'] as String,
      imageUrl: map['imageUrl'] as String?,
    );
  }

  /// Converts a `Winner` instance to a Map for Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      'studentGroupId': studentGroupId,
      'studentGroupName': studentGroupName,
      'score': score,
      'timestamp': Timestamp.fromDate(timestamp),
      'classId': classId,
      'imageUrl': imageUrl,
    };
  }
}

/// Data model for application error logs.
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
  Map<String, dynamic> toFirestore() {
    return {
      'classId': classId,
      'generatedAt': Timestamp.fromDate(generatedAt),
      'generatorUserId': generatorUserId,
      'active': active,
    };
  }
}
