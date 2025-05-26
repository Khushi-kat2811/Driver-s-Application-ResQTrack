import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class CommonMethods {
  Future<void> checkConnectivity(BuildContext context) async {
    try {
      var connectionResult = await Connectivity().checkConnectivity();

      if (connectionResult == ConnectivityResult.none) {
        displaySnackbar("No network connection. Try Again.", context);
        return;
      }

      // Check if the internet is actually reachable
      final result = await InternetAddress.lookup('example.com');
      if (result.isEmpty || result[0].rawAddress.isEmpty) {
        displaySnackbar("Internet connection is not available. Try Again.", context);
      }

    } catch (e) {
      displaySnackbar("Internet connection is not available. Try Again.", context);
    }
  }

  void displaySnackbar(String messageText, BuildContext context) {
    final snackBar = SnackBar(content: Text(messageText));
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}
