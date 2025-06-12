-- Profile Image Migration Script
-- This script adds profile image support to the EduConnect database

-- 1. Add profile_image_url column to the profiles table
ALTER TABLE profiles 
ADD COLUMN profile_image_url TEXT;

-- 2. Create the profile-images storage bucket
INSERT INTO storage.buckets (id, name, public)
VALUES ('profile-images', 'profile-images', true);

-- 3. Create storage policy to allow authenticated users to upload their own profile images
CREATE POLICY "Users can upload their own profile images" ON storage.objects
FOR INSERT WITH CHECK (
  bucket_id = 'profile-images' 
  AND name LIKE 'public/profile_' || auth.uid()::text || '_%'
);

-- 4. Create storage policy to allow public read access to profile images
CREATE POLICY "Profile images are publicly accessible" ON storage.objects
FOR SELECT USING (bucket_id = 'profile-images');

-- 5. Create storage policy to allow users to update their own profile images
CREATE POLICY "Users can update their own profile images" ON storage.objects
FOR UPDATE USING (
  bucket_id = 'profile-images' 
  AND name LIKE 'public/profile_' || auth.uid()::text || '_%'
);

-- 6. Create storage policy to allow users to delete their own profile images
CREATE POLICY "Users can delete their own profile images" ON storage.objects
FOR DELETE USING (
  bucket_id = 'profile-images' 
  AND name LIKE 'public/profile_' || auth.uid()::text || '_%'
);

-- 7. Create a function to clean up orphaned profile images
CREATE OR REPLACE FUNCTION cleanup_orphaned_profile_images()
RETURNS void AS $$
BEGIN
  -- Delete storage objects that don't have corresponding profiles
  DELETE FROM storage.objects 
  WHERE bucket_id = 'profile-images' 
  AND NOT EXISTS (
    SELECT 1 FROM profiles 
    WHERE profile_image_url LIKE '%' || storage.objects.name || '%'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. Create a trigger to clean up profile images when a profile is deleted
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

-- Create the trigger
DROP TRIGGER IF EXISTS on_profile_delete ON profiles;
CREATE TRIGGER on_profile_delete
  BEFORE DELETE ON profiles
  FOR EACH ROW EXECUTE FUNCTION handle_profile_deletion();

-- 9. Create an index on profile_image_url for better performance
CREATE INDEX IF NOT EXISTS idx_profiles_profile_image_url 
ON profiles(profile_image_url) 
WHERE profile_image_url IS NOT NULL;

-- 10. Add a comment to document the column
COMMENT ON COLUMN profiles.profile_image_url IS 'URL to the user''s profile image stored in Supabase Storage'; 