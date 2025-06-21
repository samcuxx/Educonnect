-- URGENT: Fix Infinite Recursion Error in Chat System
-- Run this IMMEDIATELY in Supabase Dashboard → SQL Editor

-- 1. DROP ALL PROBLEMATIC POLICIES causing infinite recursion
DROP POLICY IF EXISTS student_view_memberships ON class_members;
DROP POLICY IF EXISTS lecturer_view_class_members ON class_members;
DROP POLICY IF EXISTS "Users can view their own memberships" ON class_members;
DROP POLICY IF EXISTS "Users can view memberships in their classes" ON class_members;
DROP POLICY IF EXISTS "Lecturers can view memberships in their classes" ON class_members;
DROP POLICY IF EXISTS "Chat system: users can view class memberships" ON class_members;

-- 2. TEMPORARILY disable RLS to test
ALTER TABLE class_members DISABLE ROW LEVEL SECURITY;

-- 3. Test if this fixes the issue first, then re-enable with correct policies
-- After testing, run this to re-enable with fixed policies:
/*
ALTER TABLE class_members ENABLE ROW LEVEL SECURITY;

-- Create ONE simple policy that works
CREATE POLICY "Allow class member access" ON class_members
  FOR ALL
  USING (true);
*/

-- 4. Verify no policies exist
SELECT policyname, cmd, qual 
FROM pg_policies 
WHERE tablename = 'class_members'; 