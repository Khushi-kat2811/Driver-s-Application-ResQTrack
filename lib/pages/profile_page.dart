import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../authentication/login_screen.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _driverData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    fetchDriverData();
  }

  Future<void> fetchDriverData() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('User not logged in');

      final ref = FirebaseDatabase.instance.ref().child('drivers').child(uid);
      final snapshot = await ref.get();

      if (snapshot.exists) {
        setState(() {
          _driverData = Map<String, dynamic>.from(snapshot.value as Map);
          _isLoading = false;
        });
      } else {
        throw Exception('No data found for this driver');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Driver Profile')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : _buildProfileView(),
    );
  }

  Widget _buildProfileView() {
    final ambulanceDetails = _driverData!['ambulance_details'] ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CircleAvatar(
            radius: 70,
            backgroundImage: _driverData!['photo'] != null && _driverData!['photo'].isNotEmpty
                ? NetworkImage(_driverData!['photo'])
                : const AssetImage('assets/images/user2.png.jpg') as ImageProvider,
          ),
          const SizedBox(height: 16),
          _buildInfoTile("Name", _driverData!['name']),
          _buildInfoTile("Email", _driverData!['email']),
          _buildInfoTile("Phone", _driverData!['phone']),
          const Divider(),
          const Text("Ambulance Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          _buildInfoTile("Model", ambulanceDetails['ambulanceModel']),
          _buildInfoTile("Number", ambulanceDetails['ambulanceNumber']),
          _buildInfoTile("Hospital", ambulanceDetails['Hospital']),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(vertical: 12),
              textStyle: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String? value) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(value ?? 'N/A'),
    );
  }
}

