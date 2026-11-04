enum NotificationKind { invite, vote, system, application }

/// In-app notification (Lab 2 SCR_09). FCM messages are stored in the same list.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.read = false,
    this.teamId,
    this.actionLabel,
  });

  final String id;
  final NotificationKind kind;

  /// Front-loaded: the key words come first (UX writing: notifications).
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;
  final String? teamId;

  /// Deep link label, e.g. "View Team".
  final String? actionLabel;

  bool get isInvite => kind == NotificationKind.invite;

  AppNotification copyWith({bool? read}) => AppNotification(
    id: id,
    kind: kind,
    title: title,
    body: body,
    createdAt: createdAt,
    read: read ?? this.read,
    teamId: teamId,
    actionLabel: actionLabel,
  );

  factory AppNotification.fromJson(Map<String, dynamic> j, DateTime now) => AppNotification(
    id: j['id'] as String,
    kind: NotificationKind.values.byName(j['kind'] as String),
    title: j['title'] as String,
    body: j['body'] as String,
    createdAt: now.subtract(Duration(minutes: j['minutesAgo'] as int)),
    read: j['read'] as bool? ?? false,
    teamId: j['teamId'] as String?,
    actionLabel: j['actionLabel'] as String?,
  );
}
