-- Fix Chat System RLS Policies
-- This script fixes the Row Level Security policies to allow students and lecturers 
-- to see other users in their shared classes for chat functionality

-- Drop the restrictive policy that only allows users to see their own memberships
DROP POLICY IF EXISTS student_view_memberships ON class_members;

-- Create a new policy that allows users to view their own memberships
CREATE POLICY "Users can view their own memberships" ON class_members
  FOR SELECT
  USING (auth.uid() = user_id);

-- Create a new policy that allows users to view memberships of classes they are part of
-- This is essential for chat functionality
CREATE POLICY "Users can view memberships in their classes" ON class_members
  FOR SELECT
  USING (
    class_id IN (
      -- For students: classes they are members of
      SELECT cm.class_id 
      FROM class_members cm 
      WHERE cm.user_id = auth.uid()
      
      UNION
      
      -- For lecturers: classes they created
      SELECT c.id 
      FROM classes c 
      WHERE c.created_by = auth.uid()
    )
  );

-- Also ensure lecturers can view all memberships in classes they created (should already exist)
-- But let's make sure it's there
CREATE POLICY "Lecturers can view memberships in their classes" ON class_members
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM classes
      WHERE classes.id = class_members.class_id
      AND classes.created_by = auth.uid()
    )
  );

-- Optional: Add a more comprehensive policy that covers both cases
-- Drop if exists and recreate to avoid conflicts
DROP POLICY IF EXISTS "Chat system: users can view class memberships" ON class_members;

CREATE POLICY "Chat system: users can view class memberships" ON class_members
  FOR SELECT
  USING (
    -- User is viewing their own membership
    auth.uid() = user_id 
    OR
    -- User is in the same class (for students)
    class_id IN (
      SELECT cm.class_id 
      FROM class_members cm 
      WHERE cm.user_id = auth.uid()
    )
    OR
    -- User is the lecturer who created the class
    EXISTS (
      SELECT 1 FROM classes c
      WHERE c.id = class_members.class_id
      AND c.created_by = auth.uid()
    )
  );

-- Verify that the policies are in place
SELECT 
  schemaname, 
  tablename, 
  policyname, 
  cmd
FROM pg_policies 
WHERE tablename = 'class_members'
ORDER BY policyname; 