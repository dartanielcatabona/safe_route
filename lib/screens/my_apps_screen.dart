import 'package:flutter/material.dart';
import '../screens/profile_screen.dart';
import '../screens/saved_routes_screen.dart';
import '../screens/route_history_screen.dart';
import '../screens/settings_screen.dart';

class MyAppsScreen extends StatelessWidget {
  const MyAppsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Apps'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: [
            _buildAppCard(
              'Profile',
              'Manage your account information and preferences',
              Icons.person,
              Colors.blue[600]!,
              () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
              },
            ),
            _buildAppCard(
              'Saved Routes',
              'Access your favorite and frequently used routes',
              Icons.bookmark,
              Colors.green[600]!,
              () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const SavedRoutesScreen(),
                  ),
                );
              },
            ),
            _buildAppCard(
              'Route History',
              'View your complete navigation history',
              Icons.history,
              Colors.orange[600]!,
              () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const RouteHistoryScreen(),
                  ),
                );
              },
            ),
            _buildAppCard(
              'Settings',
              'Customize your app experience and preferences',
              Icons.settings,
              Colors.purple[600]!,
              () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
            ),
            _buildAppCard(
              'Emergency SOS',
              'Quick access to emergency contacts and services',
              Icons.emergency,
              Colors.red[600]!,
              () {
                // TODO: Implement SOS features
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('SOS features coming soon!')),
                );
              },
            ),
            _buildAppCard(
              'Safety Report',
              'Report incidents and safety concerns',
              Icons.report_problem,
              Colors.teal[600]!,
              () {
                // TODO: Implement safety reporting
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Safety reporting coming soon!')),
                );
              },
            ),
            _buildAppCard(
              'Trip Planner',
              'Plan your multi-modal journeys in advance',
              Icons.calendar_month,
              Colors.indigo[600]!,
              () {
                // TODO: Implement trip planner
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Trip planner coming soon!')),
                );
              },
            ),
            _buildAppCard(
              'Transport Guide',
              'Learn about different transport options',
              Icons.directions_bus,
              Colors.amber[600]!,
              () {
                // TODO: Implement transport guide
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Transport guide coming soon!')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppCard(
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Icon(
                  icon,
                  size: 40,
                  color: color,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
