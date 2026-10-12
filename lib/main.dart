import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

// --- UPDATED LOCAL NETWORK CONNECTION ---
// Replace 10.X.X.X with your Chromebook's exact Wi-Fi IP address (e.g., http://10.0.0.5:8090)
const String pocketBaseUrl = 'http://10.253.154.218:8090'; 

const String ordersCollection = 'orders';
const double pricePerJug = 5.00;

final PocketBase pocketBase = PocketBase(pocketBaseUrl);

void main() {
  runApp(const WaterDeliveryApp());
}
