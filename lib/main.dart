import 'package:driver_map/pages/dashboard.dart';
import 'package:driver_map/pages/home_page.dart';
import 'package:driver_map/screens/map_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'authentication/login_screen.dart';
import 'authentication/signup_screen.dart';



Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ResQTrack1',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      // initialRoute: '/login',
      // routes: {
      //   '/login': (context) => LoginScreen(),
      //   '/signup': (context) => SignupScreen(),
      //   '/map': (context) => const MapScreen(),
      // },
      home: FirebaseAuth.instance.currentUser==null ? LoginScreen() : Dashboard(),
    );
  }
}

