import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'services/supabase_service.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/student/student_dashboard.dart';
import 'screens/lecturer/lecturer_dashboard.dart';
import 'models/user_model.dart';

// Replace these with your own Supabase project credentials
// You can find these in your Supabase project settings > API
const String supabaseUrl = 'https://zxjswdmjhbeqnjaxlxbn.supabase.co';
const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp4anN3ZG1qaGJlcW5qYXhseGJuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDY4NzIyNDYsImV4cCI6MjA2MjQ0ODI0Nn0.80JpWfHlffBlpb-M8g0Fvxp677b0jLLO8bAzZ0ts3RI';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  final supabaseService = await SupabaseService.init(
    supabaseUrl: supabaseUrl,
    supabaseKey: supabaseAnonKey,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(supabaseService),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduConnect',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Listen to auth state changes
    final authProvider = Provider.of<AuthProvider>(context);

    // Show loading indicator while checking auth status
    if (authProvider.status == AuthStatus.loading || 
        authProvider.status == AuthStatus.initial) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Show login screen if not authenticated
    if (authProvider.status == AuthStatus.unauthenticated) {
      return const LoginScreen();
    }

    // Show different dashboards based on user type
    if (authProvider.currentUser is Student) {
      return const StudentDashboard();
    } else if (authProvider.currentUser is Lecturer) {
      return const LecturerDashboard();
    }

    // Fallback to login screen
    return const LoginScreen();
  }
}
