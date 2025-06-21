import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../utils/app_theme.dart';
import '../../models/conversation_model.dart';
import '../chat_screen.dart';
import '../select_user_screen.dart';

class ChatsTab extends StatefulWidget {
  const ChatsTab({Key? key}) : super(key: key);

  @override
  State<ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<ChatsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadChats();
    });
  }

  Future<void> _loadChats() async {
    if (!mounted) return;
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    await chatProvider.loadConversations();
  }

  Future<void> _refreshChats() async {
    if (!mounted) return;
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    await chatProvider.refreshConversations();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isLecturer = authProvider.isLecturer;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors:
                isLecturer
                    ? (isDark
                        ? [
                          AppTheme.darkSecondaryStart,
                          AppTheme.darkSecondaryEnd,
                        ]
                        : [
                          AppTheme.lightSecondaryStart,
                          AppTheme.lightSecondaryEnd,
                        ])
                    : (isDark
                        ? [AppTheme.darkPrimaryStart, AppTheme.darkPrimaryEnd]
                        : [
                          AppTheme.lightPrimaryStart,
                          AppTheme.lightPrimaryEnd,
                        ]),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: (isLecturer
                      ? AppTheme.lightSecondaryStart
                      : AppTheme.lightPrimaryStart)
                  .withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
              spreadRadius: 0.5,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: () => _showSelectUserScreen(),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Icon(Icons.chat_outlined, color: Colors.white, size: 24),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context, isLecturer, isDark),

            // Chat list
            Expanded(
              child: Consumer<ChatProvider>(
                builder: (context, chatProvider, child) {
                  if (chatProvider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (chatProvider.error != null) {
                    return _buildErrorState(
                      context,
                      chatProvider.error!,
                      isDark,
                    );
                  }

                  if (chatProvider.conversations.isEmpty) {
                    return _buildEmptyState(context, isLecturer, isDark);
                  }

                  return RefreshIndicator(
                    onRefresh: _refreshChats,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: chatProvider.conversations.length,
                      itemBuilder: (context, index) {
                        return _buildConversationCard(
                          context,
                          chatProvider.conversations[index],
                          authProvider.currentUser!.id,
                          isLecturer,
                          isDark,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isLecturer, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback:
                (bounds) => (isLecturer
                        ? AppTheme.secondaryGradient(isDark)
                        : AppTheme.primaryGradient(isDark))
                    .createShader(bounds),
            child: Text(
              'Chats',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const Spacer(),
          Consumer<ChatProvider>(
            builder: (context, chatProvider, child) {
              final unreadCount = chatProvider.totalUnreadCount;
              if (unreadCount > 0) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildConversationCard(
    BuildContext context,
    ConversationModel conversation,
    String currentUserId,
    bool isLecturer,
    bool isDark,
  ) {
    final otherParticipant = conversation.getOtherParticipant(currentUserId);
    final isUnread = conversation.unreadCount > 0;
    final lastMessageTime = conversation.lastMessageTime;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () => _openChat(conversation),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 24,
                  backgroundColor:
                      isLecturer
                          ? (isDark
                              ? AppTheme.darkSecondaryStart
                              : AppTheme.lightSecondaryStart)
                          : (isDark
                              ? AppTheme.darkPrimaryStart
                              : AppTheme.lightPrimaryStart),
                  child: Text(
                    otherParticipant['name']!.isNotEmpty
                        ? otherParticipant['name']![0].toUpperCase()
                        : '?',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Chat details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              otherParticipant['name']!,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color:
                                    isDark
                                        ? AppTheme.darkTextPrimary
                                        : AppTheme.lightTextPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (lastMessageTime != null)
                            Text(
                              _formatTime(lastMessageTime),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color:
                                    isDark
                                        ? AppTheme.darkTextSecondary
                                        : AppTheme.lightTextSecondary,
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      Row(
                        children: [
                          // Role indicator
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  otherParticipant['role'] == 'lecturer'
                                      ? Colors.blue.withOpacity(0.1)
                                      : Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              otherParticipant['role']!.toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color:
                                    otherParticipant['role'] == 'lecturer'
                                        ? Colors.blue
                                        : Colors.green,
                              ),
                            ),
                          ),

                          const SizedBox(width: 8),

                          // Last message
                          Expanded(
                            child: Text(
                              conversation.lastMessage ?? 'No messages yet',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color:
                                    isDark
                                        ? AppTheme.darkTextSecondary
                                        : AppTheme.lightTextSecondary,
                                fontWeight:
                                    isUnread
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      // Class info
                      Text(
                        'Class: ${conversation.className}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color:
                              isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Unread indicator
                if (isUnread)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color:
                          isLecturer
                              ? (isDark
                                  ? AppTheme.darkSecondaryStart
                                  : AppTheme.lightSecondaryStart)
                              : (isDark
                                  ? AppTheme.darkPrimaryStart
                                  : AppTheme.lightPrimaryStart),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      conversation.unreadCount > 99
                          ? '99+'
                          : conversation.unreadCount.toString(),
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isLecturer, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color:
                    isLecturer
                        ? (isDark
                            ? AppTheme.darkSecondaryStart.withOpacity(0.1)
                            : AppTheme.lightSecondaryStart.withOpacity(0.1))
                        : (isDark
                            ? AppTheme.darkPrimaryStart.withOpacity(0.1)
                            : AppTheme.lightPrimaryStart.withOpacity(0.1)),
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      isLecturer
                          ? (isDark
                              ? AppTheme.darkSecondaryStart.withOpacity(0.3)
                              : AppTheme.lightSecondaryStart.withOpacity(0.3))
                          : (isDark
                              ? AppTheme.darkPrimaryStart.withOpacity(0.3)
                              : AppTheme.lightPrimaryStart.withOpacity(0.3)),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.chat_outlined,
                size: 40,
                color:
                    isLecturer
                        ? (isDark
                            ? AppTheme.darkSecondaryStart
                            : AppTheme.lightSecondaryStart)
                        : (isDark
                            ? AppTheme.darkPrimaryStart
                            : AppTheme.lightPrimaryStart),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No conversations yet',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color:
                    isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Start chatting with your classmates and lecturers by tapping the chat button',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color:
                      isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color:
                    isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              onPressed: _loadChats,
            ),
          ],
        ),
      ),
    );
  }

  void _openChat(ConversationModel conversation) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(conversation: conversation),
      ),
    );
  }

  void _showSelectUserScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SelectUserScreen()),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(dateTime);
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat('EEE').format(dateTime);
    } else {
      return DateFormat('dd/MM').format(dateTime);
    }
  }
}
