import 'package:flutter/material.dart';

import 'screens/dashboard_screen.dart';
import 'screens/driver_dashboard.dart';
import 'screens/login_screen.dart';
import 'services/pocketbase_service.dart';

void main() {
  runApp(const WaterDeliveryApp());
}

class WaterDeliveryApp extends StatefulWidget {
  const WaterDeliveryApp({super.key});

  @override
  State<WaterDeliveryApp> createState() => _WaterDeliveryAppState();
}

class _WaterDeliveryAppState extends State<WaterDeliveryApp> {
  final PocketBaseService _service = PocketBaseService();

  bool get _isLoggedIn => _service.isLoggedIn;

  Future<void> _handleLogout() async {
    await _service.logout();
    if (mounted) {
      setState(() {});
    }
  }

  Widget _buildHomeScreen() {
    final role =
        (_service.currentUser?.data['role'] ?? 'customer').toString().toLowerCase();

    if (role == 'driver') {
      return DriverDashboard(
        service: _service,
        onLogout: _handleLogout,
      );
    }

    return DashboardScreen(
      service: _service,
      onLogout: _handleLogout,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Water Delivery',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue.shade700),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: false),
      ),
      home: _isLoggedIn ? _buildHomeScreen() : LoginScreen(
        service: _service,
        onLoginSuccess: () => setState(() {}),
      ),
    );
  }
}
