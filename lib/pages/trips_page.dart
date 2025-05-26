import 'dart:async';

import 'package:driver_map/pages/home_page.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';


class TripPage extends StatefulWidget {
  @override
  _TripPageState createState() => _TripPageState();
}

class _TripPageState extends State<TripPage> {
  late DatabaseReference _userLocationsRef;
  late StreamSubscription<DatabaseEvent> _userLocationsSubscription;

  Map<String, dynamic>? _newPatientData;
  String? _newPatientUID;

  @override
  void initState() {
    super.initState();
    _userLocationsRef = FirebaseDatabase.instance.ref('user_locations');
    _startListeningForNewPatients();
  }

  void _startListeningForNewPatients() {
    _userLocationsSubscription = _userLocationsRef.onChildAdded.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        setState(() {
          _newPatientUID = event.snapshot.key;
          _newPatientData = Map<String, dynamic>.from(data);
        });
      }
    });
  }

  @override
  void dispose() {
    _userLocationsSubscription.cancel();
    super.dispose();
  }

  void _acceptPatient() {
    if (_newPatientData != null) {
      // Navigate to map screen or perform desired action
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => HomePage(
            patientData: _newPatientData!,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Trip Page'),
      ),
      body: Center(
        child: _newPatientData != null
            ? ElevatedButton(
          onPressed: _acceptPatient,
          child: Text('Accept Patient'),
        )
            : Text('Waiting for patient requests...'),
      ),
    );
  }
}

