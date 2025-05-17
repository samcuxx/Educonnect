import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/supabase_service.dart';

enum AuthStatus {
  initial,
  authenticated,
  unauthenticated,
  loading,
  error,
}

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
      _status = _currentUser != null ? AuthStatus.authenticated : AuthStatus.unauthenticated;
      notifyListeners();
    }
  }
  
  // Check if user is already signed in
  Future<void> _checkCurrentUser() async {
    _status = AuthStatus.loading;
    notifyListeners();
    
    try {
      final user = await _supabaseService.getCurrentUser();
      if (user != null) {
        _currentUser = user;
        _status = AuthStatus.authenticated;
      } else {
        _status = AuthStatus.unauthenticated;
      }
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = _formatErrorMessage(e.toString());
    }
    
    notifyListeners();
  }
  
  // Sign in with email and password
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
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
        _errorMessage = 'The email or password you entered is incorrect. Please try again.';
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
  // The resetClassProvider parameter should be set by the UI when calling this method
  Future<void> signOut({Function? resetClassProvider}) async {
    _status = AuthStatus.loading;
    notifyListeners();
    
    try {
      // If a reset function was provided, call it to reset other providers
      if (resetClassProvider != null) {
        resetClassProvider();
      }
      
      await _supabaseService.signOut();
      _currentUser = null;
      _status = AuthStatus.unauthenticated;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = _formatErrorMessage(e.toString());
    }
    
    notifyListeners();
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
    } else if (errorMsg.contains('network') || errorMsg.contains('connection')) {
      return 'Unable to connect to the server. Please check your internet connection and try again.';
    } else if (errorMsg.contains('User already registered')) {
      return 'An account with this email already exists. Please use a different email or try signing in.';
    } else {
      // Generic error message for unknown errors
      return 'An unexpected error occurred. Please try again later.';
    }
  }
} 