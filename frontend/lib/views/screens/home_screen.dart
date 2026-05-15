import 'package:flutter/material.dart';
import 'package:frontend/core/themes/app_colors.dart';
import 'package:frontend/views/screens/crop_screen.dart';
import 'package:frontend/views/screens/profile_screen.dart';
import 'package:frontend/views/widgets/home_app_bar_menu.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [CropScreen(), ProfileScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.white,
        title: const Text("MaizeDoctor", style: TextStyle(color: Colors.black)),
        centerTitle: false,
        automaticallyImplyLeading: false,
        actionsPadding: const EdgeInsets.only(right: 10),
        actions: const [HomeAppBarMenu()],
      ),
      body: _screens[_selectedIndex],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },

        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: "Your Crop",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_2_outlined),
            label: "You",
          ),
        ],

        //backgroundColor: Colors.white24,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.black54,
      ),

      floatingActionButton: FloatingActionButton.extended(
        label: Text(
          "AI",
          style: TextStyle(
            color: Colors.green.shade600,
            fontWeight: FontWeight.bold,
          ),
        ),

        backgroundColor: Colors.green.shade50,

        onPressed: () {},
        icon: Icon(Icons.smart_toy_outlined, color: Colors.green.shade600),
      ),
    );
  }
}
