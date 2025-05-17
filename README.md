# EduConnect

A Flutter and Supabase-powered educational platform that differentiates between lecturers and students, giving them appropriate access and permissions.

## Features

- **Role-based Authentication**: Separate sign-up flows for students and lecturers
- **Student Features**: Access to courses, assignments, timetables, and grades
- **Lecturer Features**: Create and manage courses, assignments, and grade students
- **Secure Authentication**: Email and password authentication with Supabase

## Getting Started

### Prerequisites

- Flutter SDK (version 3.0.0 or higher)
- Dart SDK (version 2.17.0 or higher)
- Supabase account

### Setup Supabase

1. Create a new Supabase project at [https://app.supabase.io/](https://app.supabase.io/)
2. Create a `profiles` table with the following schema:

```sql
create table public.profiles (
  id uuid references auth.users not null primary key,
  full_name text not null,
  email text not null,
  user_type text not null check (user_type in ('student', 'lecturer')),
  student_number text,
  institution text,
  level text,
  staff_id text,
  department text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Create policies
alter table public.profiles enable row level security;

create policy "Public profiles are viewable by everyone."
  on profiles for select
  using ( true );

create policy "Users can insert their own profile."
  on profiles for insert
  with check ( auth.uid() = id );

create policy "Users can update own profile."
  on profiles for update
  using ( auth.uid() = id );
```

3. Enable Row Level Security (RLS) for the `profiles` table
4. Create appropriate policies for the table as shown above

### Clone and Setup

1. Clone the repository:
```bash
git clone https://github.com/yourusername/educonnect.git
cd educonnect
```

2. Get Flutter dependencies:
```bash
flutter pub get
```

3. Update the Supabase credentials in `lib/main.dart`:
```dart
const String supabaseUrl = 'YOUR_SUPABASE_URL';
const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
```

### Run the app

```bash
flutter run
```

## Project Structure

- `lib/models/` - Data models
- `lib/services/` - API and service layers
- `lib/providers/` - State management
- `lib/screens/` - UI screens
- `lib/widgets/` - Reusable UI components
- `lib/utils/` - Utility functions

## License

This project is licensed under the MIT License - see the LICENSE file for details.
# Educonnect
# Educonnect
