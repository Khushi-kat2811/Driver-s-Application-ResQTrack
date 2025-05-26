import 'dart:io';
import 'package:driver_map/pages/dashboard.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../methods/common_methods.dart';
import '../screens/map_screen.dart';
import '../widgets/loading_dialog.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  TextEditingController userNametextEditingController = TextEditingController();
  TextEditingController userPhonetextEditingController = TextEditingController();
  TextEditingController emailtextEditingController = TextEditingController();
  TextEditingController passwordtextEditingController = TextEditingController();
  TextEditingController vehicleModeltextEditingController = TextEditingController();
  TextEditingController HospitalAssociatedtextEditingController = TextEditingController();
  TextEditingController vehicleNumbertextEditingController = TextEditingController();
  CommonMethods cMethods = CommonMethods();
  XFile? imageFile;
  String urlOfUploadedImage = "";

  checkIfNetworkIsAvailable() {
    cMethods.checkConnectivity(context);
    if(imageFile != null){
      signUpFormAvailable();
    }
    else{
      cMethods.displaySnackbar("Please choose image first.", context);
    }
  }

  // uploadImageToStorage() async{
  //   String imageIDName = DateTime.now().millisecondsSinceEpoch.toString();
  //   Reference referenceImage =FirebaseStorage.instance.ref().child("Images").child(imageIDName);
  //
  //   UploadTask uploadTask = referenceImage.putFile(File(imageFile!.path));
  //   TaskSnapshot snapshot = await uploadTask;
  //   urlOfUploadedImage = await snapshot.ref.getDownloadURL();
  //
  //   setState(() {
  //     urlOfUploadedImage;
  //   });
  //   registerNewDriver();
  //
  // }


  signUpFormAvailable() {
    if (userNametextEditingController.text.trim().length < 3) {
      cMethods.displaySnackbar("Your name must be at least 4 letters long.", context);
    } else if (userPhonetextEditingController.text.trim().length < 7) {
      cMethods.displaySnackbar("Invalid Phone Number.", context);
    } else if (!emailtextEditingController.text.contains("@")) {
      cMethods.displaySnackbar("Invalid Email Format", context);
    } else if (passwordtextEditingController.text.trim().length < 5) {
      cMethods.displaySnackbar("Your password must be at least 8 characters.", context);
    } else if (vehicleModeltextEditingController.text.trim().isEmpty) {
      cMethods.displaySnackbar("Please write your ambulance model.", context);
    } else if (HospitalAssociatedtextEditingController.text.trim().isEmpty) {
      cMethods.displaySnackbar("Please enter your ambulance model.", context);
    } else if (vehicleNumbertextEditingController.text.trim().isEmpty) {
      cMethods.displaySnackbar("Please enter your ambulance number.", context);
    }
    else {
      registerNewDriver();
    }
  }

  registerNewDriver() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext) => LoadingDialog(messageText: "Registering your account..."),
    );

    final User? userFirebase = (await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: emailtextEditingController.text.trim(),
      password: passwordtextEditingController.text.trim(),
    ).catchError((errorMsg) {
      cMethods.displaySnackbar(errorMsg.toString(), context);
    })).user;

    if (!context.mounted) return;
    Navigator.pop(context);

    DatabaseReference userRef = FirebaseDatabase.instance.ref().child("drivers").child(userFirebase!.uid);

    Map driverAmbulanceInfo = {
      "Hospital": HospitalAssociatedtextEditingController.text.trim(),
      "ambulanceModel": vehicleModeltextEditingController.text.trim(),
      "ambulanceNumber": vehicleNumbertextEditingController.text.trim(),
    };

    Map driverDataMap = {
      "photo": urlOfUploadedImage,
      "ambulance_details": driverAmbulanceInfo,
      "name": userNametextEditingController.text.trim(),
      "email": emailtextEditingController.text.trim(),
      "phone": userPhonetextEditingController.text.trim(),
      "id": userFirebase.uid,
      "blockStatus": "no",
    };
    userRef.set(driverDataMap);

    Navigator.push(context, MaterialPageRoute(builder: (c) => Dashboard()));
  }

  chooseImageFromGallery() async{
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);

    if(pickedFile != null){
      setState(() {
        imageFile = pickedFile;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              const SizedBox(
                height: 40,
              ),
              imageFile == null ?
              const CircleAvatar(
                radius: 86,
                backgroundImage: AssetImage("assets/images/user2.png.jpg"),
              ) : Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey,
                  image: DecorationImage(
                    fit: BoxFit.fitHeight,
                    image: FileImage(
                      File(
                        imageFile!.path,
                      ),
                    )
                  ),
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              GestureDetector(
                onTap: (){
                  chooseImageFromGallery();
                },
                child: const Text(
                  "Choose Image",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    TextField(
                      controller: userNametextEditingController,
                      keyboardType: TextInputType.text,
                      decoration: const InputDecoration(
                        labelText: "Your Name",
                        labelStyle: TextStyle(fontSize: 14),
                      ),
                      style: const TextStyle(color: Colors.grey, fontSize: 15),
                    ),
                    const SizedBox(height: 22),
                    TextField(
                      controller: emailtextEditingController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: "Your Email",
                        labelStyle: TextStyle(fontSize: 14),
                      ),
                      style: const TextStyle(color: Colors.grey, fontSize: 15),
                    ),
                    const SizedBox(height: 22),
                    TextField(
                      controller: userPhonetextEditingController,
                      keyboardType: TextInputType.text,
                      decoration: const InputDecoration(
                        labelText: "Your Phone",
                        labelStyle: TextStyle(fontSize: 14),
                      ),
                      style: const TextStyle(color: Colors.grey, fontSize: 15),
                    ),
                    const SizedBox(height: 22),
                    TextField(
                      controller: passwordtextEditingController,
                      obscureText: true,
                      keyboardType: TextInputType.text,
                      decoration: const InputDecoration(
                        labelText: "Your Password",
                        labelStyle: TextStyle(fontSize: 14),
                      ),
                      style: const TextStyle(color: Colors.grey, fontSize: 15),
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: vehicleModeltextEditingController,
                      keyboardType: TextInputType.text,
                      decoration: const InputDecoration(
                        labelText: "Your Ambulance Model",
                        labelStyle: TextStyle(fontSize: 14),
                      ),
                      style: const TextStyle(color: Colors.grey, fontSize: 15),
                    ),
                    const SizedBox(height: 22),
                    TextField(
                      controller: HospitalAssociatedtextEditingController,
                      keyboardType: TextInputType.text,
                      decoration: const InputDecoration(
                        labelText: "Hospital associated with",
                        labelStyle: TextStyle(fontSize: 14),
                      ),
                      style: const TextStyle(color: Colors.grey, fontSize: 15),
                    ),
                    const SizedBox(height: 22),
                    TextField(
                      controller: vehicleNumbertextEditingController,
                      keyboardType: TextInputType.text,
                      decoration: const InputDecoration(
                        labelText: "Ambulance number",
                        labelStyle: TextStyle(fontSize: 14),
                      ),
                      style: const TextStyle(color: Colors.grey, fontSize: 15),
                    ),
                    const SizedBox(height: 22),
                    ElevatedButton(
                      onPressed: () {
                        checkIfNetworkIsAvailable();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 20),
                      ),
                      child: const Text("Sign up"),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (c) => const LoginScreen()));
                },
                child: const Text(
                  "Already have an account? Login here.",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
