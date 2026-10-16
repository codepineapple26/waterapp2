import 'package:flutter/material.dart';
import 'create_order_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? selectedPlace;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Column(
        children: [
          // Replace this with your app's actual place selector.
          DropdownButton<String>(
            hint: const Text('Select a place'),
            value: selectedPlace,
            items: const [
              DropdownMenuItem(value: 'Place 1', child: Text('Place 1')),
              DropdownMenuItem(value: 'Place 2', child: Text('Place 2')),
            ],
            onChanged: (place) {
              setState(() => selectedPlace = place);
            },
          ),

          if (selectedPlace != null)
            const Expanded(child: CreateOrderScreen()),
        ],
      ),
    );
  }
}
