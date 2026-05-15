import 'package:flutter/material.dart';
import 'package:frontend/views/screens/feedback_screen.dart';
import 'package:frontend/views/screens/help_page_screen.dart';
import 'package:frontend/views/screens/settings_screen.dart';

class HomeAppBarMenu extends StatelessWidget {
  const HomeAppBarMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      color: Colors.white,
      elevation:2,
      icon: const Icon(Icons.more_vert,color: Colors.black,),
      onSelected: (value) {
        switch (value) {
          case 'feedback':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FeedbackScreen(),
              ),
            );
            break;

          case 'settings':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SettingsScreen(),
              ),
            );
            break;

          case 'contact':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ContactSocialScreen(),
              ),
            );
            break;
        }
      },

      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'feedback',
          child: Text('Feedback'),
        ),
        PopupMenuItem(
          value: 'settings',
          child: Text('Settings'),
        ),
        PopupMenuItem(
          value: 'contact',
          child: Text('Contact'),
        ),
      ],
    );
  }
}