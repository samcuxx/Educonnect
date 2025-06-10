# Class Details Screen Architecture

This directory contains the refactored components of the Class Details Screen, which was previously a monolithic file exceeding 5,000 lines of code.

## Directory Structure

```
lib/
├── screens/
│   ├── class_details/
│   │   ├── announcements_tab.dart   # Announcements tab UI and logic
│   │   ├── resources_tab.dart       # Resources tab UI and logic
│   │   ├── assignments_tab.dart     # Assignments tab UI and logic
│   │   └── class_details_utils.dart # Utilities for class details
│   └── class_details_screen.dart    # Main container with TabController
├── utils/
│   ├── download_manager.dart        # File download and management
│   ├── dialog_utils.dart            # Dialog and bottom sheet utilities
│   └── file_utils.dart              # File type and icon helpers
```

## Component Responsibilities

### Main Screen

- `class_details_screen.dart`: Contains the main `ClassDetailsScreen` widget with `TabController` and app bar. Handles state management and data loading for all tabs.

### Tab Screens

- `announcements_tab.dart`: UI and interactions for the Announcements tab
- `resources_tab.dart`: UI and interactions for the Resources tab
- `assignments_tab.dart`: UI and interactions for the Assignments tab

### Utilities

- `class_details_utils.dart`: Utilities specific to the class details screen
- `download_manager.dart`: Manages downloading, tracking, and opening files
- `dialog_utils.dart`: Reusable dialog and bottom sheet components
- `file_utils.dart`: Utilities for handling file types, icons, and formatting

## Data Flow

1. The main `ClassDetailsScreen` loads data through Supabase service
2. Data and callbacks are passed to each tab component
3. User interactions in tabs call back to main screen methods
4. File operations are delegated to the `DownloadManager`
5. UI components use utilities from `dialog_utils.dart` and `file_utils.dart`

## Future Improvements

- Implement proper state management (BLoC, Provider, or Riverpod)
- Add better error handling and retry mechanisms
- Improve offline support with better caching
- Add pagination for large data sets
