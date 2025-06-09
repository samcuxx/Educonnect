-- Drop any existing policies to avoid conflicts
DROP POLICY IF EXISTS find_class_by_code ON classes;
DROP POLICY IF EXISTS lecturer_view_classes ON classes;
DROP POLICY IF EXISTS lecturer_insert_classes ON classes;
DROP POLICY IF EXISTS student_view_memberships ON class_members;
DROP POLICY IF EXISTS student_insert_memberships ON class_members;
DROP POLICY IF EXISTS view_joined_classes ON classes;
DROP POLICY IF EXISTS lecturer_view_class_members ON class_members;
DROP POLICY IF EXISTS lecturer_delete_classes ON classes;
DROP POLICY IF EXISTS student_delete_memberships ON class_members;

-- Create the classes table
CREATE TABLE IF NOT EXISTS classes (
  id UUID PRIMARY KEY,
  name TEXT NOT NULL,
  code TEXT NOT NULL UNIQUE,
  course_code TEXT NOT NULL,
  level TEXT NOT NULL,
  start_date TIMESTAMP WITH TIME ZONE NOT NULL,
  end_date TIMESTAMP WITH TIME ZONE NOT NULL,
  created_by UUID NOT NULL REFERENCES auth.users(id),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Create the class_members table (for many-to-many relationship)
CREATE TABLE IF NOT EXISTS class_members (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  class_id UUID NOT NULL REFERENCES classes(id),
  joined_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, class_id)
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_classes_created_by ON classes(created_by);
CREATE INDEX IF NOT EXISTS idx_class_members_user_id ON class_members(user_id);
CREATE INDEX IF NOT EXISTS idx_class_members_class_id ON class_members(class_id);

-- Set up row level security policies
ALTER TABLE classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE class_members ENABLE ROW LEVEL SECURITY;

-- Critical Fix: First, we need a policy that allows searching for classes by code
-- This policy allows anyone to find a class by its code (needed for joining)
CREATE POLICY find_class_by_code ON classes
  FOR SELECT
  USING (true);

-- Policy: Users can view classes they created (lecturers)
CREATE POLICY lecturer_view_classes ON classes
  FOR SELECT
  USING (auth.uid() = created_by);

-- Policy: Users can insert their own classes (lecturers)
CREATE POLICY lecturer_insert_classes ON classes
  FOR INSERT
  WITH CHECK (auth.uid() = created_by);

-- Policy: Users can delete classes they created (lecturers)
CREATE POLICY lecturer_delete_classes ON classes
  FOR DELETE
  USING (auth.uid() = created_by);

-- Policy: Users can view their class memberships (students)
CREATE POLICY student_view_memberships ON class_members
  FOR SELECT
  USING (auth.uid() = user_id);

-- Policy: Users can insert their own class memberships (students)
CREATE POLICY student_insert_memberships ON class_members
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Policy: Users can delete their own class memberships (students leaving classes)
CREATE POLICY student_delete_memberships ON class_members
  FOR DELETE
  USING (auth.uid() = user_id);

-- Policy: Lecturers can delete any memberships for classes they created
CREATE POLICY lecturer_delete_memberships ON class_members
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM classes
      WHERE classes.id = class_members.class_id
      AND classes.created_by = auth.uid()
    )
  );

-- Allow lecturers to view their own class members
CREATE POLICY lecturer_view_class_members ON class_members
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM classes
      WHERE classes.id = class_members.class_id
      AND classes.created_by = auth.uid()
    )
  );

-- Add delete policy for announcements (if announcements table exists)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'announcements') THEN
    -- Drop existing policy if it exists
    DROP POLICY IF EXISTS "Lecturers can delete their own announcements" ON announcements;
    
    -- Create the delete policy
    CREATE POLICY "Lecturers can delete their own announcements" ON announcements
      FOR DELETE
      TO authenticated
      USING (
        EXISTS (
          SELECT 1 
          FROM classes 
          WHERE classes.id = announcements.class_id 
            AND classes.created_by = auth.uid()
        )
      );
  END IF;
END $$;

-- Add delete policy for resources (if resources table exists)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'resources') THEN
    -- Drop existing policy if it exists
    DROP POLICY IF EXISTS "Lecturers can delete their own resources" ON resources;
    
    -- Create the delete policy
    CREATE POLICY "Lecturers can delete their own resources" ON resources
      FOR DELETE
      TO authenticated
      USING (
        EXISTS (
          SELECT 1 
          FROM classes 
          WHERE classes.id = resources.class_id 
            AND classes.created_by = auth.uid()
        )
      );
  END IF;
END $$;

-- Add delete policy for assignments (if assignments table exists)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'assignments') THEN
    -- Drop existing policy if it exists
    DROP POLICY IF EXISTS "Lecturers can delete their own assignments" ON assignments;
    
    -- Create the delete policy
    CREATE POLICY "Lecturers can delete their own assignments" ON assignments
      FOR DELETE
      TO authenticated
      USING (
        EXISTS (
          SELECT 1 
          FROM classes 
          WHERE classes.id = assignments.class_id 
            AND classes.created_by = auth.uid()
        )
      );
  END IF;
END $$;