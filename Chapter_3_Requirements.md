# EduConnect Chapter 3 Requirements - System Analysis

## 🔹 1. Software Design Methodology

### Design Methodology

**Approach**: **Component-Based Design with MVC/MVP Architecture**

- Followed a **modular, component-based design** using Flutter's widget-centric architecture
- Implemented **Provider pattern for state management** (not Riverpod as initially mentioned)
- Used **Repository pattern** with service layers for data management
- Applied **Clean Architecture principles** with separation of concerns:
  - Models (Data entities)
  - Services (Business logic & API calls)
  - Providers (State management)
  - Screens (UI/Presentation)
  - Widgets (Reusable UI components)

### Design Philosophy

**Primary**: **User-first, role-based design**

- **Role-based access control** - Clear separation between student and lecturer experiences
- **Offline-first approach** - Works without internet connectivity using local caching
- **Mobile-first responsive design** - Optimized for mobile devices
- **Security-first** - Row Level Security (RLS) policies implemented throughout

### Tools Used

- **Supabase Dashboard** - Database design and management
- **Flutter's built-in tools** - No external prototyping tools mentioned in codebase
- **Git version control** - Standard development workflow

---

## 🔹 2. System Architecture

### Technology Stack

**Confirmed Stack:**

```
Frontend: Flutter 3.7.2+ (Dart)
Backend: Supabase (PostgreSQL + Auth + Storage + Real-time)
State Management: Provider 6.1.1
Local Storage: SQLite (sqflite), Hive, Shared Preferences, Secure Storage
```

### Third-Party Packages & Services

**Core Dependencies:**

- `supabase_flutter: ^2.3.1` - Backend integration
- `provider: ^6.1.1` - State management
- `flutter_secure_storage: ^9.0.0` - Secure local storage
- `sqflite: ^2.4.2` & `hive: ^2.2.3` - Local databases
- `cached_network_image: ^3.3.1` - Image caching

**SMS Notifications:**

- **mNotify SMS API** - African SMS service provider (not Twilio)
- Custom implementation in `lib/services/mnotify_service.dart`

**File Handling:**

- `image_picker: ^1.0.7` - Profile images
- `file_selector: ^1.0.3` - Document uploads
- `pdf: ^3.10.7` - PDF generation
- `share_plus: ^7.2.1` - File sharing

### API Communication

**REST API** - Using Supabase REST endpoints with real-time subscriptions

### Background Services

**Implemented:**

- **Supabase Real-time subscriptions** - Live updates for classes
- **Local caching system** - Offline data synchronization
- **SMS notifications** - Via mNotify service
- **File storage** - Supabase Storage buckets with RLS policies

---

## 🔹 3. System Modules

### Confirmed Module List:

1. **User Authentication & Profile Management**

   - Role-based signup (Student/Lecturer)
   - Email/password authentication
   - Profile image upload
   - Secure session management

2. **Class Management**

   - Create classes (Lecturers)
   - Join classes via unique codes (Students)
   - Class member management
   - Class archiving

3. **Announcement System**

   - Create/view announcements
   - Real-time notifications
   - SMS integration for announcements

4. **Resource Upload & Sharing**

   - File upload to Supabase Storage
   - Support for multiple file types
   - Download and sharing capabilities

5. **Assignment Management**

   - Create assignments with deadlines
   - File attachments for assignments
   - Assignment submission system
   - View submissions (Lecturers)

6. **SMS Notification Module**

   - mNotify integration
   - OTP verification
   - Bulk SMS for class announcements

7. **Student Management**

   - View class members
   - Approve/remove students
   - Student profile viewing

8. **Offline Data Management**
   - Local caching with Hive
   - SQLite for complex queries
   - Connectivity monitoring
   - Sync when online

---

## 🔹 4. Database Schema / Entity List

### Core Entities:

**Users (Supabase Auth + Profiles table)**

```sql
profiles:
- id (UUID, FK to auth.users)
- full_name (TEXT)
- email (TEXT)
- user_type (TEXT: 'student'|'lecturer')
- student_number (TEXT, nullable)
- institution (TEXT, nullable)
- level (TEXT, nullable)
- staff_id (TEXT, nullable)
- department (TEXT, nullable)
- phone_number (TEXT, nullable)
- profile_image_url (TEXT, nullable)
- created_at, updated_at (TIMESTAMP)
```

**Classes**

```sql
- id (UUID, PK)
- name (TEXT)
- code (TEXT, UNIQUE)
- course_code (TEXT)
- level (TEXT)
- start_date, end_date (TIMESTAMP)
- created_by (UUID, FK to auth.users)
- created_at (TIMESTAMP)
```

**Class_Members (Pivot Table)**

```sql
- id (UUID, PK)
- user_id (UUID, FK to auth.users)
- class_id (UUID, FK to classes)
- joined_at (TIMESTAMP)
- UNIQUE(user_id, class_id)
```

**Assignments**

```sql
- id (UUID, PK)
- class_id (UUID, FK to classes)
- title (TEXT)
- description (TEXT)
- file_url (TEXT, nullable)
- assigned_by (UUID, FK to auth.users)
- deadline (TIMESTAMP)
- created_at (TIMESTAMP)
```

**Announcements**

```sql
- id (UUID, PK)
- class_id (UUID, FK to classes)
- title (TEXT)
- message (TEXT)
- posted_by (UUID, FK to auth.users)
- created_at (TIMESTAMP)
```

**Resources**

```sql
- id (UUID, PK)
- class_id (UUID, FK to classes)
- file_url (TEXT)
- title (TEXT)
- uploaded_by (UUID, FK to auth.users)
- created_at (TIMESTAMP)
```

**Submissions** (Implemented in models)

```sql
- id (UUID, PK)
- assignment_id (UUID, FK to assignments)
- student_id (UUID, FK to auth.users)
- file_url (TEXT, nullable)
- submitted_at (TIMESTAMP)
- file_type (TEXT)
```

### Role-Based Access Control

**Implementation**: User type field in profiles + Supabase RLS policies

- Comprehensive Row Level Security policies for all tables
- Role-based access patterns in Flutter providers

---

## 🔹 5. Visuals and Diagram Choices

### Recommendation:

**Create actual diagrams** for the following:

- **Entity Relationship Diagram (ERD)** - Database relationships
- **System Architecture Diagram** - Flutter + Supabase architecture
- **Data Flow Diagram (DFD)** - User interactions and data flow
- **Use Case Diagram** - Student vs Lecturer functionalities
- **Navigation Flow Charts** - App screen flows

### UI Documentation:

- Use **screenshots from the actual app** for UI examples
- Include **wireframes for key user journeys**
- Add **component hierarchy diagrams** for Flutter widget structure

---

## 🔹 6. User Interaction Flow

### Student Journey - Joining a Class:

1. Student logs in → Dashboard
2. Selects "Join Class" option
3. Enters unique class code
4. System validates code and adds student to class
5. Student receives SMS confirmation (if enabled)
6. Class appears in student's dashboard

### Lecturer Journey - Creating a Class:

1. Lecturer logs in → Dashboard
2. Selects "Create Class" option
3. Fills class details (name, course code, level, dates)
4. System generates unique class code
5. Class is created and appears in lecturer's dashboard
6. Lecturer can share class code with students

### SMS Notification Flow:

1. Lecturer posts announcement
2. System identifies class members
3. SMS sent via mNotify service to all students
4. Delivery status tracked and logged

---

## 🔹 7. Scalability/Expandability Plans

### Current Expansion Capabilities:

**Multi-platform Support:**

- ✅ **Mobile** (iOS/Android) - Current implementation
- 🔄 **Web Support** - Flutter web already configured
- 🔄 **Desktop** - Windows/macOS/Linux targets available

### Planned Features (Based on Codebase Structure):

**Institutional Scaling:**

- Multi-institution support (institution field in profiles)
- Department-level management (department field in lecturer profiles)

**Enhanced Features:**

- **Push notifications** - Infrastructure ready (currently SMS-only)
- **Payment integration** - Modular service architecture supports addition
- **Timetable/Calendar** - Database schema can accommodate
- **Admin dashboard** - Role-based system can add admin role
- **Analytics** - Supabase provides built-in analytics capabilities

### Architecture Readiness:

- **Microservices-ready** - Modular service layer
- **Offline-first** - Already implemented
- **Real-time capabilities** - Supabase subscriptions active
- **File storage scaling** - Supabase Storage with CDN
- **Database scaling** - PostgreSQL with connection pooling

---

## 📋 Implementation Status Summary

| Component             | Status      | Notes                          |
| --------------------- | ----------- | ------------------------------ |
| **Authentication**    | ✅ Complete | Role-based with profile images |
| **Class Management**  | ✅ Complete | Full CRUD with RLS             |
| **Announcements**     | ✅ Complete | Real-time updates              |
| **Resources**         | ✅ Complete | File upload/download           |
| **Assignments**       | ✅ Complete | With submission system         |
| **SMS Notifications** | ✅ Complete | mNotify integration            |
| **Offline Support**   | ✅ Complete | Multi-layer caching            |
| **Security**          | ✅ Complete | Comprehensive RLS policies     |

### Technical Debt:

- Some provider files appear empty (resource_provider.dart)
- Large files indicate potential refactoring opportunities
- Missing comprehensive error logging system

This architecture demonstrates a well-structured, scalable educational platform with strong security foundations and offline capabilities.
