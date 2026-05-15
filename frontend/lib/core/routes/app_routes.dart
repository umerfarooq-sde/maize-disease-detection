import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:frontend/views/screens/home_screen.dart';
import 'package:frontend/views/screens/splash_screen.dart';
import '../../views/screens/on_boarding_1.dart';

class AppRoutes {

  static const String splashScreen = '/';
  static const String home = '/home';
  static const String onBoarding1 = '/onBoarding1';


  static Route<dynamic> generateRoute(RouteSettings settings){
    switch(settings.name){
      case splashScreen:
        return MaterialPageRoute(builder: (_)=>SplashScreen());
      case onBoarding1:
        return MaterialPageRoute(builder: (_)=>OnBoarding1());
      case home:
        return MaterialPageRoute(builder: (_)=>HomeScreen());
      default:
        return MaterialPageRoute(builder: (_)=>HomeScreen());
    }
  }


}