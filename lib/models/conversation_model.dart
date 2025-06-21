class ConversationModel {
  final String id;
  final String participant1Id;
  final String participant1Name;
  final String participant1Role;
  final String participant2Id;
  final String participant2Name;
  final String participant2Role;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final String? lastMessageSenderId;
  final int unreadCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String classId;
  final String className;

  ConversationModel({
    required this.id,
    required this.participant1Id,
    required this.participant1Name,
    required this.participant1Role,
    required this.participant2Id,
    required this.participant2Name,
    required this.participant2Role,
    this.lastMessage,
    this.lastMessageTime,
    this.lastMessageSenderId,
    this.unreadCount = 0,
    required this.createdAt,
    required this.updatedAt,
    required this.classId,
    required this.className,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'] ?? '',
      participant1Id: json['participant1_id'] ?? '',
      participant1Name: json['participant1_name'] ?? '',
      participant1Role: json['participant1_role'] ?? '',
      participant2Id: json['participant2_id'] ?? '',
      participant2Name: json['participant2_name'] ?? '',
      participant2Role: json['participant2_role'] ?? '',
      lastMessage: json['last_message'],
      lastMessageTime:
          json['last_message_time'] != null
              ? DateTime.parse(json['last_message_time'])
              : null,
      lastMessageSenderId: json['last_message_sender_id'],
      unreadCount: json['unread_count'] ?? 0,
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updated_at'] ?? DateTime.now().toIso8601String(),
      ),
      classId: json['class_id'] ?? '',
      className: json['class_name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'participant1_id': participant1Id,
      'participant1_name': participant1Name,
      'participant1_role': participant1Role,
      'participant2_id': participant2Id,
      'participant2_name': participant2Name,
      'participant2_role': participant2Role,
      'last_message': lastMessage,
      'last_message_time': lastMessageTime?.toIso8601String(),
      'last_message_sender_id': lastMessageSenderId,
      'unread_count': unreadCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'class_id': classId,
      'class_name': className,
    };
  }

  // Get the other participant's details (not the current user)
  Map<String, String> getOtherParticipant(String currentUserId) {
    if (participant1Id == currentUserId) {
      return {
        'id': participant2Id,
        'name': participant2Name,
        'role': participant2Role,
      };
    } else {
      return {
        'id': participant1Id,
        'name': participant1Name,
        'role': participant1Role,
      };
    }
  }

  ConversationModel copyWith({
    String? id,
    String? participant1Id,
    String? participant1Name,
    String? participant1Role,
    String? participant2Id,
    String? participant2Name,
    String? participant2Role,
    String? lastMessage,
    DateTime? lastMessageTime,
    String? lastMessageSenderId,
    int? unreadCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? classId,
    String? className,
  }) {
    return ConversationModel(
      id: id ?? this.id,
      participant1Id: participant1Id ?? this.participant1Id,
      participant1Name: participant1Name ?? this.participant1Name,
      participant1Role: participant1Role ?? this.participant1Role,
      participant2Id: participant2Id ?? this.participant2Id,
      participant2Name: participant2Name ?? this.participant2Name,
      participant2Role: participant2Role ?? this.participant2Role,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      unreadCount: unreadCount ?? this.unreadCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      classId: classId ?? this.classId,
      className: className ?? this.className,
    );
  }

  @override
  String toString() {
    return 'ConversationModel(id: $id, participants: $participant1Name & $participant2Name, lastMessage: $lastMessage)';
  }
}
