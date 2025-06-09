import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/reset_password_screen.dart';

/// A navigator observer that monitors route changes and redirects
/// to the login screen if a user tries to access a protected route
/// while not authenticated.
class AuthRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    // Don't check auth state for dialog routes (modals)
    if (route is! DialogRoute) {
      _checkAuthState(route);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null && newRoute is! DialogRoute) {
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
    // But only for routes that actually require authentication
    if (authProvider.status != AuthStatus.authenticated) {
      // Check if this route actually requires authentication
      final settings = route.settings;

      // Extra check for password reset flows - don't redirect if coming from password reset
      if (_isPasswordResetFlow(route)) {
        return;
      }

      if (settings.requiresAuth) {
        // Use a post-frame callback to avoid build conflicts
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (route.navigator?.context != null) {
            print('User not authenticated, redirecting to login screen');
            route.navigator?.pushNamedAndRemoveUntil(
              '/login',
              (route) => false,
            );
          }
        });
      }
    }
  }

  bool _isPasswordResetFlow(Route<dynamic> route) {
    // Check if this is part of the password reset flow
    if (route is MaterialPageRoute || route is PageRoute) {
      try {
        // Only access builder if the route supports it
        if (route is MaterialPageRoute) {
          final widget = route.builder(route.navigator!.context);
          // Direct widget type check for ResetPasswordScreen
          if (widget is ResetPasswordScreen) {
            return true;
          }

          final widgetString = widget.toString().toLowerCase();
          return widgetString.contains('resetpassword') ||
              widgetString.contains('reset_password') ||
              widgetString.contains('resetpasswordscreen');
        } else if (route is PageRoute && route.hasActiveRouteBelow == false) {
          // For PageRoute instances that might have custom builders
          // We'll check the route settings or other properties
          final settings = route.settings;
          if (settings.name != null) {
            return settings.name!.toLowerCase().contains('reset') ||
                settings.name!.toLowerCase().contains('password');
          }
        }
      } catch (e) {
        return false;
      }
    }
    return false;
  }

  bool _isExemptedRoute(Route<dynamic> route) {
    // Define routes that don't require authentication
    final settings = route.settings;

    // Check if route name is related to authentication
    if (settings.name != null) {
      // Exempt all auth-related routes
      if (settings.name == '/login' ||
          settings.name == '/forgot-password' ||
          settings.name == '/reset-password' ||
          settings.name == '/otp-verification' ||
          settings.name!.startsWith('/signup')) {
        return true;
      }
    }

    // Check route by widget type if name is null
    if (settings.name == null && route is MaterialPageRoute) {
      try {
        final widget = route.builder(route.navigator!.context);

        // Direct widget type checks
        if (widget is LoginScreen || widget is ResetPasswordScreen) {
          return true;
        }

        final widgetString = widget.toString().toLowerCase();
        // Exempt login, signup, and password reset screens
        return widgetString.contains('signup') ||
            widgetString.contains('sign_up') ||
            widgetString.contains('forgotpassword') ||
            widgetString.contains('resetpassword') ||
            widgetString.contains('forgot_password') ||
            widgetString.contains('reset_password') ||
            widgetString.contains('resetpasswordscreen') ||
            widgetString.contains('loginscreen');
      } catch (e) {
        // If we can't determine the widget type, assume it needs auth
        return false;
      }
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
    if (name == '/login' ||
        name == '/forgot-password' ||
        name == '/reset-password' ||
        name == '/otp-verification') {
      return false;
    }

    // Exempt all signup routes
    if (name!.startsWith('/signup')) {
      return false;
    }

    return true;
  }
}
