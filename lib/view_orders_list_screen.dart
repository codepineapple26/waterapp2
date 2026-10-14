import 'package:flutter/material.dart';

class ViewOrdersListScreen extends StatelessWidget {
  const ViewOrdersListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View Orders'),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'No orders yet.',
            style: TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }
}
