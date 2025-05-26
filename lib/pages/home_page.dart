import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

import '../authentication/login_screen.dart';
import '../global/global_var.dart';
import '../methods/common_methods.dart';

class HomePage extends StatefulWidget {
  final Map<String, dynamic>? patientData;

  const HomePage({super.key, this.patientData});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late MapController _mapController;
  LatLng _currentLocation = LatLng(48.8583, 2.2944);
  bool _isLoading = true;
  String? _errorMessage;
  CommonMethods cMethods = CommonMethods();
  bool _autofollow = true;
  StreamSubscription<Position>? _positionStream;
  String userId = FirebaseAuth.instance.currentUser!.uid;
  late DatabaseReference userRef;

  LatLng? _patientLocation;
  List<LatLng> _routePolyline = [];
  static const String _orsApiKey = '5b3ce3597851110001cf62489d0fc290e5e14ae8abf8e2f63ee8fab0';

  bool _patientAccepted = false;
  DatabaseReference? _acceptedPatientRef;
  DatabaseReference? _patientUserNodeRef;

  String? _firebaseOtp;
  bool _otpDialogShown = false;
  LatLng? _hospitalLocation;
  bool _navigateToHospital = false;
  List<LatLng> _hospitalRoutePolyline = [];


  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    userRef = FirebaseDatabase.instance.ref().child("drivers").child(userId);

    if (widget.patientData != null) {
      double? lat = widget.patientData!['latitude'];
      double? lng = widget.patientData!['longitude'];
      if (lat != null && lng != null) {
        _patientLocation = LatLng(lat, lng);
      }
    }

    _getCurrentLocation();
    _listenForOtp();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  void _listenForOtp() {
    DatabaseReference otpRef = FirebaseDatabase.instance
        .ref()
        .child("otp")
        .child("xlFT4NSVFCSUqaamJs5Z6aHFvPi1")
        .child("otp");

    otpRef.onValue.listen((event) {
      if (event.snapshot.value != null) {
        _firebaseOtp = event.snapshot.value.toString();
      }
    });
  }

  void _showOtpDialog() {
    if (_otpDialogShown) return;

    _otpDialogShown = true;
    TextEditingController otpController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Enter OTP"),
        content: TextField(
          controller: otpController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: "Enter OTP to proceed to hospital",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _otpDialogShown = false;
            },
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (otpController.text == _firebaseOtp) {
                Navigator.pop(context);
                cMethods.displaySnackbar("OTP verified! Proceeding to hospital.", context);
                //FirebaseDatabase.instance.ref().child("otp").child(userId).remove();

                await FirebaseDatabase.instance
                    .ref()
                    .child("otp")
                    .child("xlFT4NSVFCSUqaamJs5Z6aHFvPi1")
                    .update({
                  "connectedHospital": "Yes",
                });
                _patientAccepted = false;
                _patientLocation = null;
                _routePolyline.clear();
                _acceptedPatientRef = null;
                _patientUserNodeRef = null;

                // Wait for hospital location
                _listenForHospitalCoordinates();
              } else {
                cMethods.displaySnackbar("Incorrect OTP. Try again.", context);
              }
              _otpDialogShown = false;
            },
            child: const Text("Submit"),
          ),
        ],
      ),
    );
  }
  void _listenForHospitalCoordinates() {
    final hospitalRef = FirebaseDatabase.instance
        .ref()
        .child("otp")
        .child("xlFT4NSVFCSUqaamJs5Z6aHFvPi1");

    hospitalRef.onValue.listen((event) async {
      final data = event.snapshot.value;
      if (data is Map && data.containsKey("hospital_lat") && data.containsKey("hospital_lon")) {
        double? lat = double.tryParse(data["hospital_lat"].toString());
        double? lng = double.tryParse(data["hospital_lon"].toString());
        if (lat != null && lng != null) {
          setState(() {
            _hospitalLocation = LatLng(lat, lng);
            _navigateToHospital = true;
          });

          await _fetchHospitalRoute(_currentLocation, _hospitalLocation!);
        }
      }
    });
  }
  Future<void> _fetchHospitalRoute(LatLng start, LatLng end) async {
    final url = Uri.parse(
        'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$_orsApiKey&start=${start.longitude},${start.latitude}&end=${end.longitude},${end.latitude}');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List coords = data['features'][0]['geometry']['coordinates'];
        setState(() {
          _hospitalRoutePolyline = coords.map<LatLng>((coord) => LatLng(coord[1], coord[0])).toList();
        });
      }
    } catch (e) {
      print('Error fetching hospital route: $e');
    }
  }



  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        await Geolocator.openLocationSettings();
        throw Exception('Location services are disabled.');
      }

      await _checkLocationPermission();
      await _getCurrentPosition();
      _startLiveTracking();

      if (_patientLocation != null) {
        await _fetchRoutePolyline(_currentLocation, _patientLocation!);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('LateInitializationError:', '').trim();
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkLocationPermission() async {
    final status = await Geolocator.checkPermission();

    if (status == LocationPermission.denied) {
      final result = await Geolocator.requestPermission();
      if (result == LocationPermission.denied) {
        throw Exception('Location permission denied');
      }
    }

    if (status == LocationPermission.deniedForever) {
      await openAppSettings();
      throw Exception('Location permission permanently denied.');
    }
  }

  Future<void> _getCurrentPosition() async {
    Position position = await Geolocator.getCurrentPosition();
    _currentLocation = LatLng(position.latitude, position.longitude);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.move(_currentLocation, 15.0);
    });

    await userRef.update({
      "latitude": position.latitude,
      "longitude": position.longitude,
    });

    await getUserInfoAndCheckBlockStatus();
  }

  void _startLiveTracking() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 1,
    );

    _positionStream?.cancel();
    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) async {
        final newLocation = LatLng(position.latitude, position.longitude);
        if (_currentLocation != newLocation) {
          _currentLocation = newLocation;

          if (_autofollow) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _mapController.move(_currentLocation, _mapController.camera.zoom);
            });

            await userRef.update({
              "latitude": position.latitude,
              "longitude": position.longitude,
            });

            if (_patientUserNodeRef != null) {
              await _patientUserNodeRef!.update({
                "driverLat": position.latitude,
                "driverLng": position.longitude,
                "timestamp": ServerValue.timestamp,
              });
            }
          }
        }

        if (_patientLocation != null) {
          await _fetchRoutePolyline(_currentLocation, _patientLocation!);

          final distance = Geolocator.distanceBetween(
            _currentLocation.latitude,
            _currentLocation.longitude,
            _patientLocation!.latitude,
            _patientLocation!.longitude,
          );

          if (distance <= 100 && _firebaseOtp != null && !_otpDialogShown) {
            _showOtpDialog();
          }
        }

        if (_patientAccepted && _acceptedPatientRef != null) {
          await _acceptedPatientRef!.update({
            "driverLat": position.latitude,
            "driverLng": position.longitude,
            "timestamp": ServerValue.timestamp,
          });
        }
      },
      onError: (e) {
        setState(() {
          _errorMessage = 'Live Tracking Error: ${e.toString()}';
        });
      },
    );
  }

  Future<void> _fetchRoutePolyline(LatLng start, LatLng end) async {
    final url = Uri.parse(
        'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$_orsApiKey&start=${start.longitude},${start.latitude}&end=${end.longitude},${end.latitude}'
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List coords = data['features'][0]['geometry']['coordinates'];
        setState(() {
          _routePolyline = coords.map<LatLng>((coord) => LatLng(coord[1], coord[0])).toList();
        });
      }
    } catch (e) {
      print('Exception fetching route: $e');
    }
  }

  Future<void> _acceptPatient() async {
    if (widget.patientData == null) return;

    final patientId = widget.patientData!['id'];
    final initialData = {
      "patientId": patientId,
      "patientLat": widget.patientData!['latitude'],
      "patientLng": widget.patientData!['longitude'],
      "driverId": userId,
      "driverLat": _currentLocation.latitude,
      "driverLng": _currentLocation.longitude,
      "timestamp": ServerValue.timestamp,
    };

    try {
      _acceptedPatientRef = FirebaseDatabase.instance.ref().child("drivers").child(userId).child("PatientAccepted");
      await _acceptedPatientRef!.set(initialData);

      _patientUserNodeRef = FirebaseDatabase.instance
          .ref()
          .child("users")
          .child("xlFT4NSVFCSUqaamJs5Z6aHFvPi1")
          .child("DriverDetails");

      await _patientUserNodeRef!.set(initialData);

      setState(() => _patientAccepted = true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Patient Accepted and live tracking started.")),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to accept patient: $e")),
      );
    }
  }

  getUserInfoAndCheckBlockStatus() async {
    final userSnapshot = await userRef.once();
    final data = userSnapshot.snapshot.value as Map?;

    if (data != null) {
      if (data["blockStatus"] == "no") {
        setState(() {
          userName = data["name"];
        });
      } else {
        FirebaseAuth.instance.signOut();
        Navigator.push(context, MaterialPageRoute(builder: (c) => LoginScreen()));
        cMethods.displaySnackbar("You are blocked. Contact admin.", context);
      }
    } else {
      FirebaseAuth.instance.signOut();
      Navigator.push(context, MaterialPageRoute(builder: (c) => LoginScreen()));
    }
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

  Widget _buildAcceptPatientBar() {
    if (widget.patientData == null || _patientAccepted) return const SizedBox.shrink();

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(12),
        child: ElevatedButton(
          onPressed: _acceptPatient,
          child: const Text("Accept Patient"),
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
          : Stack(
        children: [
          FlutterMap(
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
                    child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
                  ),
                  if (_patientLocation != null)
                    Marker(
                      point: _patientLocation!,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 40),
                    ),
                  if (_hospitalLocation != null)
                    Marker(
                      point: _hospitalLocation!,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.local_hospital, color: Colors.red, size: 40),
                    ),

                ],
              ),
              PolylineLayer(
                polylines: [
                  if (_routePolyline.isNotEmpty)
                    Polyline(points: _routePolyline, color: Colors.green, strokeWidth: 4.0),
                  if (_hospitalRoutePolyline.isNotEmpty)
                    Polyline(points: _hospitalRoutePolyline, color: Colors.blue, strokeWidth: 4.0),

                ],
              ),
            ],
          ),
          _buildAcceptPatientBar(),
        ],
      ),
    );
  }
}
