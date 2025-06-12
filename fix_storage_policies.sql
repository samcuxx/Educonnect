-- Fix Storage Policies Migration Script
-- Run this script if you already ran the initial database_migration.sql
-- This fixes the RLS policies to match the actual file naming pattern used by the app

-- 1. Drop existing policies
DROP POLICY IF EXISTS "Users can upload their own profile images" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own profile images" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own profile images" ON storage.objects;
DROP POLICY IF EXISTS "Profile images are publicly accessible" ON storage.objects;

-- 2. Create corrected storage policy to allow authenticated users to upload their own profile images
CREATE POLICY "Users can upload their own profile images" ON storage.objects
FOR INSERT WITH CHECK (
  bucket_id = 'profile-images' 
  AND name LIKE 'public/profile_' || auth.uid()::text || '_%'
);

-- 3. Create storage policy to allow public read access to profile images
CREATE POLICY "Profile images are publicly accessible" ON storage.objects
FOR SELECT USING (bucket_id = 'profile-images');

-- 4. Create storage policy to allow users to update their own profile images
CREATE POLICY "Users can update their own profile images" ON storage.objects
FOR UPDATE USING (
  bucket_id = 'profile-images' 
  AND name LIKE 'public/profile_' || auth.uid()::text || '_%'
);

-- 5. Create storage policy to allow users to delete their own profile images
CREATE POLICY "Users can delete their own profile images" ON storage.objects
FOR DELETE USING (
  bucket_id = 'profile-images' 
  AND name LIKE 'public/profile_' || auth.uid()::text || '_%'
);

-- 6. Update the cleanup function to match the new naming pattern
CREATE OR REPLACE FUNCTION handle_profile_deletion()
RETURNS trigger AS $$
BEGIN
  -- Extract the image path from the URL and delete the storage object
  IF OLD.profile_image_url IS NOT NULL THEN
    -- Extract the file path from the URL
    -- Format: https://your-project.supabase.co/storage/v1/object/public/profile-images/public/filename
    DECLARE
      image_path TEXT;
    BEGIN
      image_path := substring(OLD.profile_image_url from '.*/profile-images/(.*)$');
      IF image_path IS NOT NULL THEN
        -- Delete storage objects that match the user's profile pattern
        DELETE FROM storage.objects 
        WHERE bucket_id = 'profile-images' 
        AND name = image_path
        AND name LIKE 'public/profile_' || OLD.id::text || '_%';
      END IF;
    END;
  END IF;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Verify the policies are correctly applied
SELECT 
  schemaname, 
  tablename, 
  policyname, 
  cmd, 
  qual,
  with_check
FROM pg_policies 
WHERE tablename = 'objects' 
AND schemaname = 'storage'
ORDER BY policyname; 