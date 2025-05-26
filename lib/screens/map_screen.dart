
import 'dart:async';

import 'package:driver_map/authentication/login_screen.dart';
import 'package:driver_map/methods/common_methods.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../global/global_var.dart';
import '../pages/dashboard.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late MapController _mapController;
  LatLng _currentLocation= LatLng(48.8583,2.2944);
  bool _isLoading = true;
  String? _errorMessage;
  bool _serviceEnabled = false;
  CommonMethods cMethods = CommonMethods();

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Check if location services are enabled
      _serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!_serviceEnabled) {
        _serviceEnabled = await Geolocator.openLocationSettings();
        if (!_serviceEnabled) {
          throw Exception('Location services are disabled. Please enable them in settings.');
        }
      }

      // 2. Check and request location permissions
      await _checkLocationPermission();

      // 3. Get current position
      await _getCurrentPosition();

    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('LateInitializationError:', '').trim();
        if (_errorMessage!.contains('Field')) {
          _errorMessage = 'Location service initialization failed. Please restart the app.';
        }
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkLocationPermission() async {

    final status = await Geolocator.checkPermission();

    if (status==LocationPermission.denied) {
      final result = await Geolocator.requestPermission();
      if (result==LocationPermission.denied) {
        throw Exception('Location permission denied');
      }
    }

    if (status==LocationPermission.deniedForever) {
      await openAppSettings();
      await Future.delayed(const Duration(seconds: 1));
      throw Exception('Location permission permanently denied. Please enable in app settings.');
    }
  }

  Future<void> _getCurrentPosition() async {
    try {
      Position position  = await Geolocator.getCurrentPosition();
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);

      });
      WidgetsBinding.instance.addPostFrameCallback((_){
        _mapController.move(_currentLocation, 15.0);
      });
    } on TimeoutException{
      throw Exception('Location request timed out. Please try again.');
    } catch (e) {
      throw Exception('Failed to get location: ${e.toString()}');
    }
    await getUserInfoAndCheckBlockStatus();
  }

  getUserInfoAndCheckBlockStatus() async{
    DatabaseReference userRef = FirebaseDatabase.instance.ref()
        .child("drivers")
        .child(FirebaseAuth.instance.currentUser!.uid);

    await userRef.once().then((snap) {
      if (snap.snapshot.value != null) {
        if ((snap.snapshot.value as Map)["blockStatus"] == "no") {
          setState(() {
            userName = (snap.snapshot.value as Map)["name"];

          });
        } else {
          FirebaseAuth.instance.signOut();
          Navigator.push(context, MaterialPageRoute(builder: (c)=> LoginScreen()));
          cMethods.displaySnackbar("You are blocked. Contact admin: khushi@gmail.com", context);
        }
      } else {
        FirebaseAuth.instance.signOut();
        Navigator.push(context, MaterialPageRoute(builder: (c)=> LoginScreen()));

      }
    });
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 50, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Location error occurred',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _getCurrentLocation,
              child: const Text('Retry'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => openAppSettings(),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ResQTrack'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _getCurrentLocation,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _buildErrorView()
          : FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _currentLocation,
          initialZoom: 15.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.resqtrack1',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: _currentLocation,
                width: 40,
                height: 40,
                child: const Icon(
                  Icons.location_pin,
                  color: Colors.red,
                  size: 40,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}