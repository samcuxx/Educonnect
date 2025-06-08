import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';

/// A navigator observer that monitors route changes and redirects
/// to the login screen if a user tries to access a protected route
/// while not authenticated.
class AuthRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _checkAuthState(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _checkAuthState(newRoute);
    }
  }

  void _checkAuthState(Route<dynamic> route) {
    // Skip checking routes that are exempted (login, signup, etc.)
    if (_isExemptedRoute(route)) {
      return;
    }

    // Get the build context from the route
    final BuildContext? context = route.navigator?.context;
    if (context == null) return;

    // Check authentication state
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // If user status is still loading or initial, wait for it to resolve
    if (authProvider.status == AuthStatus.loading ||
        authProvider.status == AuthStatus.initial) {
      return; // Don't redirect yet, wait for auth state to be determined
    }

    // If user is not authenticated, redirect to login
    if (authProvider.status != AuthStatus.authenticated) {
      // Use a post-frame callback to avoid build conflicts
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route.navigator?.context != null) {
          print('User not authenticated, redirecting to login screen');
          route.navigator?.pushNamedAndRemoveUntil('/login', (route) => false);
        }
      });
    }
  }

  bool _isExemptedRoute(Route<dynamic> route) {
    // Define routes that don't require authentication
    final settings = route.settings;

    // Check if route name is related to authentication
    if (settings.name != null) {
      // Exempt all auth-related routes
      if (settings.name == '/login' ||
          settings.name == '/forgot-password' ||
          settings.name!.startsWith('/signup')) {
        return true;
      }
    }

    // Check route by widget type if name is null
    if (settings.name == null && route is MaterialPageRoute) {
      final widget = route.builder(route.navigator!.context);
      // Exempt login and signup screens
      return widget is LoginScreen ||
          widget.toString().toLowerCase().contains('signup') ||
          widget.toString().toLowerCase().contains('sign_up');
    }

    return false;
  }
}

/// Extension method for RouteSettings to check if a route is protected
extension RouteSettingsExtension on RouteSettings {
  bool get requiresAuth {
    // Define routes that don't require authentication
    if (name == null) return true;

    // Exempt auth-related routes
    if (name == '/login' || name == '/forgot-password') {
      return false;
    }

    // Exempt all signup routes
    if (name!.startsWith('/signup')) {
      return false;
    }

    return true;
  }
}
