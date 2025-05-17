import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../../models/user_model.dart';

class LecturerDashboard extends StatelessWidget {
  const LecturerDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final lecturer = authProvider.currentUser as Lecturer?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lecturer Dashboard'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => authProvider.signOut(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, ${lecturer?.fullName}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text('Staff ID: ${lecturer?.staffId ?? 'N/A'}'),
                    Text('Department: ${lecturer?.department ?? 'N/A'}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Features section
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            
            // Feature grid
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildFeatureCard(
                  context,
                  title: 'My Courses',
                  icon: Icons.book,
                  onTap: () {},
                ),
                _buildFeatureCard(
                  context,
                  title: 'Create Assignments',
                  icon: Icons.assignment_add,
                  onTap: () {},
                ),
                _buildFeatureCard(
                  context,
                  title: 'Timetable',
                  icon: Icons.calendar_today,
                  onTap: () {},
                ),
                _buildFeatureCard(
                  context,
                  title: 'Student Grades',
                  icon: Icons.grading,
                  onTap: () {},
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Logout button
            CustomButton(
              text: 'Sign Out',
              backgroundColor: Colors.red,
              onPressed: () => authProvider.signOut(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
} 