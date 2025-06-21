rr-- EduConnect Chat System Database Migration
-- This script creates the necessary tables for the chat functionality

-- Create conversations table
CREATE TABLE IF NOT EXISTS conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    participant1_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    participant1_name TEXT NOT NULL,
    participant1_role TEXT NOT NULL CHECK (participant1_role IN ('lecturer', 'student')),
    participant2_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    participant2_name TEXT NOT NULL,
    participant2_role TEXT NOT NULL CHECK (participant2_role IN ('lecturer', 'student')),
    last_message TEXT,
    last_message_time TIMESTAMPTZ,
    last_message_sender_id UUID REFERENCES auth.users(id),
    unread_count INTEGER DEFAULT 0,
    class_id UUID NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
    class_name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Ensure participants are different
    CONSTRAINT different_participants CHECK (participant1_id != participant2_id),
    
    -- Unique conversation per class between two users
    CONSTRAINT unique_conversation_per_class UNIQUE (participant1_id, participant2_id, class_id)
);

-- Create messages table
CREATE TABLE IF NOT EXISTS messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    sender_name TEXT NOT NULL,
    sender_role TEXT NOT NULL CHECK (sender_role IN ('lecturer', 'student')),
    message TEXT NOT NULL,
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    is_read BOOLEAN DEFAULT FALSE,
    message_type TEXT DEFAULT 'text' CHECK (message_type IN ('text', 'image', 'file')),
    file_url TEXT,
    file_name TEXT
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_conversations_participant1 ON conversations(participant1_id);
CREATE INDEX IF NOT EXISTS idx_conversations_participant2 ON conversations(participant2_id);
CREATE INDEX IF NOT EXISTS idx_conversations_class ON conversations(class_id);
CREATE INDEX IF NOT EXISTS idx_conversations_updated ON conversations(updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_messages_conversation ON messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender ON messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_timestamp ON messages(timestamp);
CREATE INDEX IF NOT EXISTS idx_messages_unread ON messages(is_read, conversation_id) WHERE is_read = FALSE;

-- Function to update conversation's updated_at timestamp
CREATE OR REPLACE FUNCTION update_conversation_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE conversations 
    SET updated_at = NOW()
    WHERE id = NEW.conversation_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update conversation timestamp when a message is added
DROP TRIGGER IF EXISTS trigger_update_conversation_timestamp ON messages;
CREATE TRIGGER trigger_update_conversation_timestamp
    AFTER INSERT ON messages
    FOR EACH ROW
    EXECUTE FUNCTION update_conversation_timestamp();

-- Function to update unread count
CREATE OR REPLACE FUNCTION update_unread_count()
RETURNS TRIGGER AS $$
BEGIN
    -- Update unread count for the conversation
    UPDATE conversations 
    SET unread_count = (
        SELECT COUNT(*)
        FROM messages 
        WHERE conversation_id = NEW.conversation_id 
        AND is_read = FALSE 
        AND sender_id != NEW.sender_id
    )
    WHERE id = NEW.conversation_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update unread count when messages are added or read status changes
DROP TRIGGER IF EXISTS trigger_update_unread_count_insert ON messages;
CREATE TRIGGER trigger_update_unread_count_insert
    AFTER INSERT ON messages
    FOR EACH ROW
    EXECUTE FUNCTION update_unread_count();

DROP TRIGGER IF EXISTS trigger_update_unread_count_update ON messages;
CREATE TRIGGER trigger_update_unread_count_update
    AFTER UPDATE OF is_read ON messages
    FOR EACH ROW
    EXECUTE FUNCTION update_unread_count();

-- Enable Row Level Security (RLS)
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Conversations RLS Policies

-- Users can view conversations they are part of
CREATE POLICY "Users can view their conversations" ON conversations
    FOR SELECT USING (
        participant1_id = auth.uid() OR participant2_id = auth.uid()
    );

-- Users can create conversations where they are a participant
CREATE POLICY "Users can create conversations" ON conversations
    FOR INSERT WITH CHECK (
        participant1_id = auth.uid() OR participant2_id = auth.uid()
    );

-- Users can update conversations they are part of
CREATE POLICY "Users can update their conversations" ON conversations
    FOR UPDATE USING (
        participant1_id = auth.uid() OR participant2_id = auth.uid()
    );

-- Messages RLS Policies

-- Users can view messages in conversations they are part of
CREATE POLICY "Users can view conversation messages" ON messages
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM conversations 
            WHERE conversations.id = messages.conversation_id 
            AND (participant1_id = auth.uid() OR participant2_id = auth.uid())
        )
    );

-- Users can send messages in conversations they are part of
CREATE POLICY "Users can send messages" ON messages
    FOR INSERT WITH CHECK (
        sender_id = auth.uid() AND
        EXISTS (
            SELECT 1 FROM conversations 
            WHERE conversations.id = messages.conversation_id 
            AND (participant1_id = auth.uid() OR participant2_id = auth.uid())
        )
    );

-- Users can update their own messages or mark messages as read in their conversations
CREATE POLICY "Users can update messages" ON messages
    FOR UPDATE USING (
        sender_id = auth.uid() OR
        EXISTS (
            SELECT 1 FROM conversations 
            WHERE conversations.id = messages.conversation_id 
            AND (participant1_id = auth.uid() OR participant2_id = auth.uid())
        )
    );

-- Grant necessary permissions
GRANT SELECT, INSERT, UPDATE ON conversations TO authenticated;
GRANT SELECT, INSERT, UPDATE ON messages TO authenticated;

-- Function to get class members for chat (used by the app)
CREATE OR REPLACE FUNCTION get_user_class_members(user_id_param UUID)
RETURNS TABLE (
    id UUID,
    full_name TEXT,
    email TEXT,
    role TEXT,
    phone_number TEXT,
    profile_image_url TEXT,
    class_id UUID,
    class_name TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        p.id,
        p.full_name,
        p.email,
        p.role,
        p.phone_number,
        p.profile_image_url,
        c.id as class_id,
        c.class_name
    FROM profiles p
    JOIN class_members cm ON p.id = cm.user_id
    JOIN classes c ON cm.class_id = c.id
    WHERE c.id IN (
        SELECT DISTINCT cm2.class_id 
        FROM class_members cm2 
        WHERE cm2.user_id = user_id_param
    )
    AND p.id != user_id_param;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission on the function
GRANT EXECUTE ON FUNCTION get_user_class_members(UUID) TO authenticated;

-- Insert sample data for testing (optional)
/*
-- This section can be uncommented to insert sample conversations for testing
-- Make sure to replace the UUIDs with actual user IDs from your system

INSERT INTO conversations (
    participant1_id, participant1_name, participant1_role,
    participant2_id, participant2_name, participant2_role,
    class_id, class_name
) VALUES 
-- Add sample conversations here if needed for testing
-- ('uuid1', 'John Doe', 'student', 'uuid2', 'Dr. Smith', 'lecturer', 'class_uuid', 'Mathematics 101')
;

INSERT INTO messages (
    conversation_id, sender_id, sender_name, sender_role, message
) VALUES
-- Add sample messages here if needed for testing
-- ('conversation_uuid', 'sender_uuid', 'John Doe', 'student', 'Hello, I have a question about the assignment.')
;
*/ 