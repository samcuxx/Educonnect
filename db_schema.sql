-- Table: announcements
CREATE TABLE announcements (
  id UUID PRIMARY KEY,
  class_id UUID REFERENCES classes(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  posted_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);

-- Table: resources
CREATE TABLE resources (
  id UUID PRIMARY KEY,
  class_id UUID REFERENCES classes(id) ON DELETE CASCADE,
  file_url TEXT NOT NULL,
  title TEXT NOT NULL,
  uploaded_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);

-- Create RLS (Row Level Security) policies

-- Announcements policies
ALTER TABLE announcements ENABLE ROW LEVEL SECURITY;

-- Lecturers can create announcements for their own classes
CREATE POLICY "Lecturers can create announcements" ON announcements
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 
      FROM classes 
      WHERE classes.id = announcements.class_id 
        AND classes.created_by = auth.uid()
    )
  );

-- Lecturers can view and update their own announcements
CREATE POLICY "Lecturers can view and update their own announcements" ON announcements
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 
      FROM classes 
      WHERE classes.id = announcements.class_id 
        AND classes.created_by = auth.uid()
    )
  );

-- Students can view announcements for classes they are members of
CREATE POLICY "Students can view announcements for their classes" ON announcements
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 
      FROM class_members 
      WHERE class_members.class_id = announcements.class_id 
        AND class_members.user_id = auth.uid()
    )
  );

-- Resources policies
ALTER TABLE resources ENABLE ROW LEVEL SECURITY;

-- Lecturers can upload resources to their own classes
CREATE POLICY "Lecturers can upload resources" ON resources
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 
      FROM classes 
      WHERE classes.id = resources.class_id 
        AND classes.created_by = auth.uid()
    )
  );

-- Lecturers can view and update their own resources
CREATE POLICY "Lecturers can view and update their own resources" ON resources
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 
      FROM classes 
      WHERE classes.id = resources.class_id 
        AND classes.created_by = auth.uid()
    )
  );

-- Students can view resources for classes they are members of
CREATE POLICY "Students can view resources for their classes" ON resources
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 
      FROM class_members 
      WHERE class_members.class_id = resources.class_id 
        AND class_members.user_id = auth.uid()
    )
  );

-- Storage policies (for file uploads)
-- Create a storage bucket for resources
CREATE POLICY "Public access to resources"
  ON storage.objects FOR SELECT
  USING ( bucket_id = 'educonnect' );

-- Allow authenticated users to upload files
CREATE POLICY "Authenticated users can upload resources"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK ( 
    bucket_id = 'educonnect' AND 
    (storage.foldername(name))[1] = 'resources'
  ); 