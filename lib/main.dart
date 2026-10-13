import 'package:flutter/material.dart';
import 'services/pocketbase_service.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart'; // customer dashboard (existing)
import 'screens/driver_dashboard.dart'; // new

void main() => runApp(const WaterDeliveryApp());

class WaterDeliveryApp extends StatefulWidget {
  const WaterDeliveryApp({super.key});

  @override
  State<WaterDeliveryApp> createState() => _WaterDeliveryAppState();
}

class _WaterDeliveryAppState extends State<WaterDeliveryApp> {
  final PocketBaseService _service = PocketBaseService();

  bool get _isLoggedIn => _service.isLoggedIn;

  Widget _homeForRole() {
    final user = _service.currentUser;
    final role = user?.data['role']?.toString().toLowerCase() ?? 'customer';
    if (role == 'driver') {
      return DriverDashboard(service: _service, onLogout: _handleLogout);
    } else {
      return DashboardScreen(service: _service, onLogout: _handleLogout);
    }
  }

  Future<void> _handleLogout() async {
    await _service.logout();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Water Delivery',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: _isLoggedIn ? _homeForRole() : LoginScreen(service: _service, onLoginSuccess: () => setState(() {})),
    );
  }
}
