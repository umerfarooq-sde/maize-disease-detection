// import 'package:flutter/material.dart';
// import 'package:frontend/core/routes/app_routes.dart';
// import 'package:frontend/core/themes/app_theme.dart';
// import 'package:frontend/views/screens/splash_screen.dart';
//
// void main() {
//   runApp(const MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   // This widget is the root of your application.
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'MAIZEDOCTOR',
//
//       theme: AppTheme.lightTheme,
//
//       debugShowCheckedModeBanner: false,
//
//       initialRoute: AppRoutes.splashScreen,
//
//       onGenerateRoute: AppRoutes.generateRoute,
//
//     );
//   }
// }
//
import 'package:flutter/material.dart';
import 'package:frontend/views/screens/home_screen.dart';
import 'package:frontend/views/widgets/home_app_bar_menu.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MaizeCrop',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
