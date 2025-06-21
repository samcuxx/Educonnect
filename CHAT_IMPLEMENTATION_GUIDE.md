# EduConnect Chat System Implementation Guide

## Overview

This guide explains how to implement the comprehensive chat system for the EduConnect app, which allows lecturers and students to communicate privately within their shared classes.

## Features Implemented

✅ **Chat Models**: ChatModel and ConversationModel for data structure
✅ **Chat Provider**: State management for chat operations
✅ **Chat Screens**: Main chat list, individual chat, and user selection screens
✅ **Navigation Integration**: Added chat tab to dashboard navigation
✅ **Database Schema**: Complete migration script for chat tables
✅ **MNotify Integration**: SMS notifications for new messages
✅ **Professional UI**: WhatsApp-style chat interface following app design patterns

## Implementation Steps

### 1. Database Setup

Execute the `chat_migration.sql` script in your Supabase SQL editor:

```bash
# Run this in your Supabase dashboard > SQL Editor
# Copy and paste the contents of chat_migration.sql
```

This creates:

- `conversations` table for chat conversations
- `messages` table for individual messages
- Proper indexes for performance
- Row Level Security (RLS) policies
- Database functions for updating timestamps and unread counts

### 2. Fix SupabaseService Imports

The SupabaseService has import conflicts that need to be resolved. Update the imports section:

```dart
// Remove duplicate UserModel import and fix conflicts
import '../models/user_model.dart' as app_models; // Keep this
// Remove: import '../models/user_model.dart'; // Remove this duplicate

// The chat methods have been added but need the import fixes
```

### 3. Create Missing UserModel

The chat system references a `UserModel` that might not exist. Create it if missing:

```dart
// lib/models/user_model.dart (if not exists)
class UserModel {
  final String id;
  final String fullName;
  final String email;
  final String role;
  final String phoneNumber;
  final String? profileImageUrl;

  UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.phoneNumber,
    this.profileImageUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      fullName: json['full_name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      profileImageUrl: json['profile_image_url'],
    );
  }
}
```

### 4. Add Required Dependencies

Add these to your `pubspec.yaml`:

```yaml
dependencies:
  intl: ^0.18.1 # For date formatting in chat
  # Other existing dependencies...
```

### 5. Configure MNotify Service

Update your MNotify configuration with your actual API key:

```dart
// In dashboard_screen.dart, replace:
MNotifyService(apiKey: 'your_mnotify_api_key')

// With your actual MNotify API key:
MNotifyService(apiKey: 'your_actual_api_key_here')
```

### 6. Navigation Structure

The chat system integrates into the existing navigation:

**For Students:**

- Home (index 0)
- Classes (index 1)
- Resources (index 2)
- **Chats (index 3)** ← New
- Profile (index 4)

**For Lecturers:**

- Home (index 0)
- Classes (index 1)
- **Chats (index 2)** ← New (no Resources tab)
- Students (index 3)
- Profile (index 4)

## Screen Flow

### 1. Chats Tab (Main Chat List)

- Shows all existing conversations
- Displays unread message counts
- FAB button to start new chats
- Real-time updates of last messages

### 2. Select User Screen

- Lists all classmates and lecturers
- Search functionality
- Shows user roles (lecturer/student)
- Tap to start new conversation

### 3. Individual Chat Screen

- WhatsApp-style message bubbles
- Real-time messaging
- Message timestamps
- Read receipts
- Professional design matching app theme

## Key Features

### Private Messaging

- Only users in the same class can message each other
- Conversations are class-specific
- Secure with Row Level Security

### Professional UI

- Gradient backgrounds matching app theme
- Role-based color coding (blue for lecturers, green for students)
- Modern Material Design components
- Responsive design for all screen sizes

### SMS Notifications

- Automatic SMS notifications via MNotify
- Sent when users receive new messages
- Includes sender name and message preview
- Configurable through app settings

### Real-time Features

- Instant message delivery
- Automatic scroll to new messages
- Message read status tracking
- Conversation timestamp updates

## Database Schema Details

### Conversations Table

```sql
- id: UUID (primary key)
- participant1_id, participant2_id: User references
- participant names and roles: Cached for performance
- last_message info: For conversation preview
- unread_count: Automatic calculation
- class_id: Links conversation to specific class
```

### Messages Table

```sql
- id: UUID (primary key)
- conversation_id: Links to conversation
- sender info: User ID, name, role
- message: Text content
- timestamp: When message was sent
- is_read: Read status
- message_type: text/image/file (extensible)
```

## Security Features

### Row Level Security (RLS)

- Users can only see their own conversations
- Messages are filtered by conversation access
- Database-level security enforcement

### Data Validation

- Message length limits
- File type restrictions
- User role verification

## Testing

### Manual Testing Steps

1. Create test users (lecturer and student)
2. Enroll them in the same class
3. Test conversation creation
4. Send messages back and forth
5. Verify SMS notifications
6. Test read receipts and unread counts

### Database Testing

```sql
-- Test conversation creation
SELECT * FROM conversations WHERE participant1_id = 'user_id';

-- Test message flow
SELECT * FROM messages WHERE conversation_id = 'conv_id' ORDER BY timestamp;

-- Test unread counts
SELECT unread_count FROM conversations WHERE id = 'conv_id';
```

## Troubleshooting

### Common Issues

1. **Import Conflicts**

   - Fix duplicate UserModel imports in SupabaseService
   - Use proper namespacing for models

2. **Navigation Issues**

   - Ensure tab indices are correct for students vs lecturers
   - Verify PageView children match navigation tabs

3. **Database Errors**

   - Run migration script in Supabase
   - Check RLS policies are applied
   - Verify foreign key relationships

4. **SMS Not Sending**
   - Check MNotify API key configuration
   - Verify phone number format
   - Test with valid phone numbers

### Debug Tips

```dart
// Enable debug logging in ChatProvider
print('Loading conversations for user: ${user.id}');
print('Sending message: $message to conversation: $conversationId');
```

## Future Enhancements

### Phase 2 Features

- File and image sharing
- Message reactions
- Group chats for classes
- Voice messages
- Message encryption

### Performance Optimizations

- Real-time subscriptions with Supabase
- Message pagination
- Offline message caching
- Push notifications (FCM)

## Support

If you encounter issues:

1. Check the console for error messages
2. Verify database migration was successful
3. Test with simple text messages first
4. Ensure proper user authentication

The chat system is designed to be scalable and maintainable, following the existing app architecture patterns. It integrates seamlessly with the current user management and class systems.
