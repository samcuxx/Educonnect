import 'package:flutter/material.dart';
import '../models/chat_model.dart';
import '../models/conversation_model.dart';
import '../models/user_model.dart';
import '../services/supabase_service.dart';
import '../services/mnotify_service.dart';

class ChatProvider with ChangeNotifier {
  final SupabaseService _supabaseService;
  final MNotifyService _mnotifyService;

  ChatProvider(this._supabaseService, this._mnotifyService);

  // State variables
  List<ConversationModel> _conversations = [];
  List<ChatModel> _messages = [];
  List<UserModel> _classMembers = [];
  bool _isLoading = false;
  bool _isLoadingMessages = false;
  String? _error;
  bool _disposed = false;

  // Getters
  List<ConversationModel> get conversations => _conversations;
  List<ChatModel> get messages => _messages;
  List<UserModel> get classMembers => _classMembers;
  bool get isLoading => _isLoading;
  bool get isLoadingMessages => _isLoadingMessages;
  String? get error => _error;

  // Load conversations
  Future<void> loadConversations() async {
    _isLoading = true;
    _error = null;
    if (!_disposed) notifyListeners();

    try {
      _conversations = await _supabaseService.getUserConversations();
    } catch (e) {
      _error = 'Failed to load conversations: ${e.toString()}';
      print('Error loading conversations: $e');
    } finally {
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  // Refresh conversations
  Future<void> refreshConversations() async {
    try {
      await loadConversations();
    } catch (e) {
      _error = 'Failed to refresh conversations: ${e.toString()}';
      print('Error in refreshConversations: $e');
      print('Error loading conversations: $e');
    } finally {
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  // Load messages for a specific conversation
  Future<void> loadMessages(String conversationId) async {
    _isLoadingMessages = true;
    _error = null;
    if (!_disposed) notifyListeners();

    try {
      _messages = await _supabaseService.getConversationMessages(
        conversationId,
      );
      // Mark messages as read
      await markMessagesAsRead(conversationId);
    } catch (e) {
      _error = 'Failed to load messages: ${e.toString()}';
      print('Error loading messages: $e');
    } finally {
      _isLoadingMessages = false;
      if (!_disposed) notifyListeners();
    }
  }

  // Load class members for starting new chats
  Future<void> loadClassMembers() async {
    _isLoading = true;
    _error = null;
    if (!_disposed) notifyListeners();

    try {
      _classMembers = await _supabaseService.getAllClassMembers();
    } catch (e) {
      _error = 'Failed to load class members: ${e.toString()}';
      print('Error loading class members: $e');
    } finally {
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  // Send a message
  Future<void> sendMessage({
    required String conversationId,
    required String message,
    String messageType = 'text',
    String? fileUrl,
    String? fileName,
  }) async {
    try {
      final chatMessage = await _supabaseService.sendMessage(
        conversationId: conversationId,
        message: message,
        messageType: messageType,
        fileUrl: fileUrl,
        fileName: fileName,
      );

      // Add message to local list
      _messages.add(chatMessage);

      // Update conversation in local list
      _updateConversationLastMessage(conversationId, chatMessage);

      if (!_disposed) notifyListeners();

      // Send push notification to the other participant
      await _sendPushNotification(conversationId, message);
    } catch (e) {
      _error = 'Failed to send message: ${e.toString()}';
      print('Error sending message: $e');
      if (!_disposed) notifyListeners();
    }
  }

  // Create or get existing conversation
  Future<ConversationModel?> createOrGetConversation({
    required String otherUserId,
    required String otherUserName,
    required String otherUserRole,
    required String classId,
    required String className,
  }) async {
    try {
      final conversation = await _supabaseService.createOrGetConversation(
        otherUserId: otherUserId,
        otherUserName: otherUserName,
        otherUserRole: otherUserRole,
        classId: classId,
        className: className,
      );

      // Add to local list if not exists
      final existingIndex = _conversations.indexWhere(
        (c) => c.id == conversation.id,
      );
      if (existingIndex == -1) {
        _conversations.insert(0, conversation);
        if (!_disposed) notifyListeners();
      }

      return conversation;
    } catch (e) {
      _error = 'Failed to create conversation: ${e.toString()}';
      print('Error creating conversation: $e');
      if (!_disposed) notifyListeners();
      return null;
    }
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String conversationId) async {
    try {
      await _supabaseService.markMessagesAsRead(conversationId);

      // Update local conversation unread count
      final conversationIndex = _conversations.indexWhere(
        (c) => c.id == conversationId,
      );
      if (conversationIndex != -1) {
        _conversations[conversationIndex] = _conversations[conversationIndex]
            .copyWith(unreadCount: 0);
        if (!_disposed) notifyListeners();
      }
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  // Update conversation with last message
  void _updateConversationLastMessage(
    String conversationId,
    ChatModel message,
  ) {
    final conversationIndex = _conversations.indexWhere(
      (c) => c.id == conversationId,
    );
    if (conversationIndex != -1) {
      _conversations[conversationIndex] = _conversations[conversationIndex]
          .copyWith(
            lastMessage: message.message,
            lastMessageTime: message.timestamp,
            lastMessageSenderId: message.senderId,
            updatedAt: message.timestamp,
          );

      // Move conversation to top
      final conversation = _conversations.removeAt(conversationIndex);
      _conversations.insert(0, conversation);
    }
  }

  // Send push notification
  Future<void> _sendPushNotification(
    String conversationId,
    String message,
  ) async {
    try {
      final conversation = _conversations.firstWhere(
        (c) => c.id == conversationId,
      );
      final currentUser = await _supabaseService.getCurrentUser();

      if (currentUser != null) {
        final otherParticipant = conversation.getOtherParticipant(
          currentUser.id,
        );

        // Get the other user's phone number for SMS notification
        final otherUser = await _supabaseService.getUserById(
          otherParticipant['id']!,
        );

        if (otherUser != null && otherUser.phoneNumber.isNotEmpty) {
          await _mnotifyService.sendSms(
            recipient: otherUser.phoneNumber,
            message:
                'New message from ${currentUser.fullName}: ${message.length > 50 ? '${message.substring(0, 50)}...' : message}',
          );
        }
      }
    } catch (e) {
      print('Error sending push notification: $e');
    }
  }

  // Get total unread count
  int get totalUnreadCount {
    return _conversations.fold(
      0,
      (total, conversation) => total + conversation.unreadCount,
    );
  }

  // Clear current messages (when leaving chat screen)
  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Subscribe to real-time updates (if needed)
  void subscribeToConversationUpdates(String conversationId) {
    // Implementation for real-time updates using Supabase subscriptions
    // This would listen for new messages in the conversation
  }

  void unsubscribeFromUpdates() {
    // Clean up subscriptions
  }

  // Get shared classes between two users
  Future<List<Map<String, dynamic>>> getSharedClasses(
    String userId1,
    String userId2,
  ) async {
    return await _supabaseService.getSharedClasses(userId1, userId2);
  }

  @override
  void dispose() {
    unsubscribeFromUpdates();
    _disposed = true;
    super.dispose();
  }
}
