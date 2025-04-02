class NotificationModel {
  final String id;
  final String title;
  final String body;
  final int timestamp;
  final bool isRead;
  final Map<String, dynamic> data;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.isRead,
    required this.data,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      title: json['title'],
      body: json['body'],
      timestamp: json['timestamp'],
      isRead: json['isRead'] == 1,
      data: Map<String, dynamic>.from(json['data'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'timestamp': timestamp,
      'isRead': isRead ? 1 : 0,
      'data': data,
    };
  }

  NotificationModel copyWith({
    String? id,
    String? title,
    String? body,
    int? timestamp,
    bool? isRead,
    Map<String, dynamic>? data,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      data: data ?? this.data,
    );
  }
}