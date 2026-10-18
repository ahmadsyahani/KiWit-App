enum NotificationKind { risk, syncPending, syncIssue, syncComplete }

class NotificationEntry {
  const NotificationEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
    this.recordId,
    this.pendingIds = const [],
  });

  final String id;
  final NotificationKind kind;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final String? recordId;
  final List<String> pendingIds;

  NotificationEntry read() => NotificationEntry(
    id: id, kind: kind, title: title, message: message,
    createdAt: createdAt, isRead: true, recordId: recordId, pendingIds: pendingIds,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'kind': kind.name, 'title': title, 'message': message,
    'createdAt': createdAt.toUtc().toIso8601String(), 'isRead': isRead,
    'recordId': recordId, 'pendingIds': pendingIds,
  };

  factory NotificationEntry.fromJson(Map<String, dynamic> json) => NotificationEntry(
    id: json['id'] as String,
    kind: NotificationKind.values.byName(json['kind'] as String),
    title: json['title'] as String,
    message: json['message'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    isRead: json['isRead'] as bool,
    recordId: json['recordId'] as String?,
    pendingIds: List<String>.from(json['pendingIds'] as List? ?? const []),
  );
}
