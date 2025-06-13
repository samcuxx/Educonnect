import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'services/supabase_service.dart';
import 'providers/auth_provider.dart';
import 'providers/class_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/student_management_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_role_select_screen.dart';
import 'screens/auth/student_signup_screen.dart';
import 'screens/auth/lecturer_signup_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/class_dashboard_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'models/user_model.dart';
import 'utils/app_theme.dart';
import 'utils/route_guard.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'services/app_initializer.dart';
import 'services/connectivity_service.dart';

// Replace these with your own Supabase project credentials
// You can find these in your Supabase project settings > API
const String supabaseUrl = 'https://zxjswdmjhbeqnjaxlxbn.supabase.co';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp4anN3ZG1qaGJlcW5qYXhseGJuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDY4NzIyNDYsImV4cCI6MjA2MjQ0ODI0Nn0.80JpWfHlffBlpb-M8g0Fvxp677b0jLLO8bAzZ0ts3RI';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Initialize offline-first services
  await AppInitializer().initialize();

  // Initialize Supabase
  final supabaseService = await SupabaseService.init(
    supabaseUrl: supabaseUrl,
    supabaseKey: supabaseAnonKey,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(supabaseService)),
        ChangeNotifierProvider(create: (_) => ClassProvider(supabaseService)),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(
          create: (_) => StudentManagementProvider(supabaseService),
        ),
        Provider<ConnectivityService>(create: (_) => ConnectivityService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Remove the splash screen once the app is built
    FlutterNativeSplash.remove();

    final themeProvider = Provider.of<ThemeProvider>(context);

    // Create a route observer to guard protected routes
    final authRouteObserver = AuthRouteObserver();
    final authProvider = Provider.of<AuthProvider>(context);

    return MaterialApp(
      title: 'EduConnect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      navigatorObservers: [authRouteObserver],
      home: const AuthWrapper(),
      // Define named routes for navigation
      routes: {
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/signup': (context) => const SignupRoleSelectScreen(),
        '/signup/student': (context) => const StudentSignupScreen(),
        '/signup/lecturer': (context) => const LecturerSignupScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
      },
      // Handle routing when the app is in an unauthenticated state
      onGenerateRoute: (settings) {
        // Allow access to auth-related routes even when not authenticated
        if (settings.name == '/login' ||
            settings.name == '/forgot-password' ||
            (settings.name != null && settings.name!.startsWith('/signup'))) {
          return null; // Let the routes table handle it
        }

        // If trying to access a protected route while not authenticated
        if (authProvider.status != AuthStatus.authenticated) {
          return MaterialPageRoute(
            builder: (context) => const LoginScreen(),
            settings: const RouteSettings(name: '/login'),
          );
        }
        return null;
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Listen to auth state changes
    final authProvider = Provider.of<AuthProvider>(context);
    final classProvider = Provider.of<ClassProvider>(context);
    final appInitializer = AppInitializer();

    // Update offline status for the class provider
    appInitializer.connectivityChanges.listen((isConnected) {
      classProvider.setOfflineStatus(!isConnected);
    });

    // Build the offline status indicator widget
    Widget buildOfflineIndicator() {
      return StreamBuilder<bool>(
        stream: appInitializer.connectivityChanges,
        initialData: appInitializer.isOnline,
        builder: (context, snapshot) {
          final isOnline = snapshot.data ?? true;
          if (isOnline) return const SizedBox.shrink();

          // Check if user is authenticated while offline
          final isOfflineAuthenticated =
              authProvider.status == AuthStatus.authenticated;

          return Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: isOfflineAuthenticated ? Colors.orange : Colors.red,
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  isOfflineAuthenticated
                      ? 'Offline mode - using cached data'
                      : 'You are offline',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    // Show loading indicator while checking auth status
    if (authProvider.status == AuthStatus.loading ||
        authProvider.status == AuthStatus.initial) {
      return Scaffold(
        body: Column(
          children: [
            buildOfflineIndicator(),
            Expanded(
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Show login screen if not authenticated
    if (authProvider.status == AuthStatus.unauthenticated ||
        authProvider.status == AuthStatus.error) {
      return Scaffold(
        body: Column(
          children: [
            buildOfflineIndicator(),
            const Expanded(child: LoginScreen()),
          ],
        ),
      );
    }

    // Show the dashboard if authenticated
    return Scaffold(
      body: Column(
        children: [
          buildOfflineIndicator(),
          const Expanded(child: DashboardScreen()),
        ],
      ),
    );
  }
}
