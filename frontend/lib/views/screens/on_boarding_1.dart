import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';

class OnBoarding1 extends StatefulWidget {
  const OnBoarding1({super.key});

  @override
  State<OnBoarding1> createState() => _OnBoarding1State();
}

class _OnBoarding1State extends State<OnBoarding1> {
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
    return Scaffold();
  }
}
