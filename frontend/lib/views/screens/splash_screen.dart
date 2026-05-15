import 'dart:async';

import 'package:flutter/material.dart';
import 'package:frontend/core/routes/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    Timer(const Duration(seconds: 2),(){
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    });

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.greenAccent,
      body: Center(

        child: Image.asset('assets/images/splash_img.jpeg'),
      ),
    );
  }
}
