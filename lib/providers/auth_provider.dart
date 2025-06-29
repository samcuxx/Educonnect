import 'dart:io';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/supabase_service.dart';
import '../services/local_storage_service.dart';
import '../services/app_initializer.dart';

enum AuthStatus { initial, authenticated, unauthenticated, loading, error }

class AuthProvider extends ChangeNotifier {
  final SupabaseService _supabaseService;

  // Auth state
  AuthStatus _status = AuthStatus.initial;
  User? _currentUser;
  String? _errorMessage;

  // Getters
  AuthStatus get status => _status;
  User? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  bool get isStudent => _currentUser is Student;
  bool get isLecturer => _currentUser is Lecturer;
  SupabaseService get supabaseService => _supabaseService;

  AuthProvider(this._supabaseService) {
    // Check for existing session on initialization
    _checkCurrentUser();
  }

  // Clear any error messages
  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      _status =
          _currentUser != null
              ? AuthStatus.authenticated
              : AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  // Check if user is already signed in with improved session restoration and offline support
  Future<void> _checkCurrentUser() async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      // First try to get the user from cache to show the UI immediately
      final localStorageService = LocalStorageService();
      final cachedUser = localStorageService.getUser();

      if (cachedUser != null) {
        _currentUser = cachedUser;
        _status = AuthStatus.authenticated;
        notifyListeners(); // Notify early to show the dashboard immediately
        print('Using cached user initially: ${cachedUser.fullName}');

        // Then try to validate the session in the background
        try {
          final user = await _supabaseService.getCurrentUser();
          if (user != null) {
            // If user data changed, update it
            if (user.toString() != cachedUser.toString()) {
              _currentUser = user;
              notifyListeners();
            }
            print('Session validated successfully. User: ${user.fullName}');
          } else {
            // If server says session is invalid but we have cached user,
            // keep the user logged in with cached data in offline mode
            print(
              'Session expired but using cached data to maintain login state',
            );
          }
        } catch (e) {
          // If we can't reach the server but we have cached user, stay logged in
          print('Could not validate session but using cached data: $e');
        }

        return; // Exit early since we already have a user
      }

      // If no cached user, attempt to restore the session normally
      final user = await _supabaseService.getCurrentUser();

      if (user != null) {
        _currentUser = user;
        _status = AuthStatus.authenticated;
        print('Session restored successfully. User: ${user.fullName}');
      } else {
        _status = AuthStatus.unauthenticated;
        print('No valid session found. User needs to log in.');
      }
    } catch (e) {
      // For offline scenarios, don't show error if it's just a connectivity issue
      if (e.toString().contains('network') ||
          e.toString().contains('connection') ||
          e.toString().contains('internet') ||
          e.toString().contains('offline')) {
        // Check if we have a stored user
        try {
          final localStorageService = LocalStorageService();
          final cachedUser = localStorageService.getUser();

          if (cachedUser != null) {
            _currentUser = cachedUser;
            _status = AuthStatus.authenticated;
            print('Using cached user while offline: ${cachedUser.fullName}');
            notifyListeners();
            return;
          }
        } catch (storageError) {
          print('Error accessing local storage: $storageError');
        }
      }

      _status = AuthStatus.error;
      _errorMessage = _formatErrorMessage(e.toString());
      print('Error checking current user: $_errorMessage');
    }

    notifyListeners();
  }

  // Check if email already exists
  Future<bool> checkEmailExists(String email) async {
    try {
      return await _supabaseService.isEmailExists(email);
    } catch (e) {
      print('Error checking email: $e');
      return false;
    }
  }

  // Check if phone number already exists
  Future<bool> checkPhoneExists(String phoneNumber) async {
    try {
      return await _supabaseService.isPhoneNumberExists(phoneNumber);
    } catch (e) {
      print('Error checking phone: $e');
      return false;
    }
  }

  // Send OTP to phone number
  Future<bool> sendOtp(String phoneNumber) async {
    try {
      return await _supabaseService.mnotifyService.sendOtp(
        phoneNumber: phoneNumber,
      );
    } catch (e) {
      print('Error sending OTP: $e');
      return false;
    }
  }

  // Verify OTP
  bool verifyOtp(String phoneNumber, String otp) {
    try {
      return _supabaseService.mnotifyService.verifyOtp(
        phoneNumber: phoneNumber,
        otp: otp,
      );
    } catch (e) {
      print('Error verifying OTP: $e');
      return false;
    }
  }

  // Get user phone number by email for password reset
  Future<String?> getUserPhoneByEmail(String email) async {
    try {
      return await _supabaseService.getUserPhoneByEmail(email);
    } catch (e) {
      print('Error getting user phone: $e');
      return null;
    }
  }

  // Reset user password
  Future<bool> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    try {
      return await _supabaseService.resetUserPassword(
        email: email,
        newPassword: newPassword,
      );
    } catch (e) {
      print('Error resetting password: $e');
      return false;
    }
  }

  // Sign in with email and password
  Future<void> signIn({required String email, required String password}) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _supabaseService.signIn(
        email: email,
        password: password,
      );

      if (user != null) {
        _currentUser = user;
        _status = AuthStatus.authenticated;
      } else {
        _status = AuthStatus.unauthenticated;
        _errorMessage =
            'The email or password you entered is incorrect. Please try again.';
      }
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = _formatErrorMessage(e.toString());
    }

    notifyListeners();
  }

  // Sign up as a student
  Future<void> signUpStudent({
    required String email,
    required String password,
    required String fullName,
    required String studentNumber,
    required String institution,
    required String level,
    String? phoneNumber,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _supabaseService.signUpStudent(
        email: email,
        password: password,
        fullName: fullName,
        studentNumber: studentNumber,
        institution: institution,
        level: level,
        phoneNumber: phoneNumber,
      );

      // Sign in the user after successful sign up
      await signIn(email: email, password: password);
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = _formatErrorMessage(e.toString());
      notifyListeners();
    }
  }

  // Sign up as a lecturer
  Future<void> signUpLecturer({
    required String email,
    required String password,
    required String fullName,
    required String staffId,
    required String department,
    String? phoneNumber,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _supabaseService.signUpLecturer(
        email: email,
        password: password,
        fullName: fullName,
        staffId: staffId,
        department: department,
        phoneNumber: phoneNumber,
      );

      // Sign in the user after successful sign up
      await signIn(email: email, password: password);
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = _formatErrorMessage(e.toString());
      notifyListeners();
    }
  }

  // Sign out - Now this includes global state reset
  Future<void> signOut({Function? resetClassProvider}) async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      // If a reset function was provided, call it to reset other providers
      if (resetClassProvider != null) {
        resetClassProvider();
      }

      // Clear all app cache before signing out
      await AppInitializer.clearCache();

      // Sign out from Supabase
      await _supabaseService.signOut();

      _currentUser = null;
      _status = AuthStatus.unauthenticated;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = _formatErrorMessage(e.toString());
    }

    notifyListeners();
  }

  // Update student profile
  Future<void> updateStudentProfile({
    required String fullName,
    required String studentNumber,
    required String institution,
    required String level,
    String? phoneNumber,
    File? profileImage,
    bool removeProfileImage = false,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_currentUser == null || !isStudent) {
        throw Exception('No student profile found to update');
      }

      final updatedUser = await _supabaseService.updateStudentProfile(
        userId: _currentUser!.id,
        fullName: fullName,
        studentNumber: studentNumber,
        institution: institution,
        level: level,
        phoneNumber: phoneNumber,
        profileImage: profileImage,
        removeProfileImage: removeProfileImage,
      );

      _currentUser = updatedUser;
      _status = AuthStatus.authenticated;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = _formatErrorMessage(e.toString());
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  // Update lecturer profile
  Future<void> updateLecturerProfile({
    required String fullName,
    required String staffId,
    required String department,
    String? phoneNumber,
    File? profileImage,
    bool removeProfileImage = false,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_currentUser == null || !isLecturer) {
        throw Exception('No lecturer profile found to update');
      }

      final updatedUser = await _supabaseService.updateLecturerProfile(
        userId: _currentUser!.id,
        fullName: fullName,
        staffId: staffId,
        department: department,
        phoneNumber: phoneNumber,
        profileImage: profileImage,
        removeProfileImage: removeProfileImage,
      );

      _currentUser = updatedUser;
      _status = AuthStatus.authenticated;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = _formatErrorMessage(e.toString());
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  // Change user password
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      if (_currentUser == null) {
        return false;
      }

      // First verify the current password is correct
      final isCurrentPasswordValid = await _supabaseService.verifyPassword(
        email: _currentUser!.email,
        password: currentPassword,
      );

      if (!isCurrentPasswordValid) {
        return false;
      }

      // If current password is valid, update to new password
      return await _supabaseService.updateUserPassword(
        userId: _currentUser!.id,
        newPassword: newPassword,
      );
    } catch (e) {
      print('Error changing password: $e');
      return false;
    }
  }

  // Format error messages to be more user-friendly
  String _formatErrorMessage(String errorMsg) {
    // Convert Supabase error messages to more user-friendly ones
    if (errorMsg.contains('email already exists')) {
      return 'An account with this email address already exists. Please use a different email or try signing in.';
    } else if (errorMsg.contains('Invalid login credentials')) {
      return 'The email or password you entered is incorrect. Please try again.';
    } else if (errorMsg.contains('Email not confirmed')) {
      return 'Please verify your email address before signing in.';
    } else if (errorMsg.contains('Password should be at least 6 characters')) {
      return 'Your password must be at least 6 characters long.';
    } else if (errorMsg.contains('network') ||
        errorMsg.contains('connection')) {
      return 'Unable to connect to the server. Please check your internet connection and try again.';
    } else if (errorMsg.contains('User already registered')) {
      return 'An account with this email already exists. Please use a different email or try signing in.';
    } else {
      // Generic error message for unknown errors
      return 'An unexpected error occurred. Please try again later.';
    }
  }
}
