import 'package:flutter/material.dart';

class EarningPage extends StatefulWidget {
  const EarningPage({super.key});

  @override
  State<EarningPage> createState() => _EarningPageState();
}

class _EarningPageState extends State<EarningPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          "EarningPage",
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,

          ),
        ),
      ),
    );
  }
}
