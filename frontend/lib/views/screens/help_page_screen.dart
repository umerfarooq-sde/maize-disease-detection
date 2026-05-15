import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactSocialScreen extends StatelessWidget {
  const ContactSocialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact & Social'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Contact Section
            _buildHeroSection(),

            // Contact Methods
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Get in Touch', Icons.contact_phone),
                  const SizedBox(height: 16),

                  _buildContactCard(
                    icon: Icons.email,
                    title: 'Email Us',
                    subtitle: 'support@maizecrop.com',
                    description: 'We\'ll respond within 24 hours',
                    color: Colors.blue,
                    onTap: () => _launchEmail('support@maizecrop.com'),
                  ),

                  const SizedBox(height: 12),

                  _buildContactCard(
                    icon: Icons.phone,
                    title: 'Call Us',
                    subtitle: '+1 (555) 123-4567',
                    description: 'Mon-Fri, 9AM - 6PM',
                    color: Colors.green,
                    onTap: () => _launchPhone('+15551234567'),
                  ),

                  const SizedBox(height: 12),

                  _buildContactCard(
                    icon: Icons.chat,
                    title: 'Live Chat',
                    subtitle: 'Chat with our support team',
                    description: 'Available 24/7',
                    color: Colors.orange,
                    onTap: () => _showSnackBar(context, 'Starting live chat...'),
                  ),
                ],
              ),
            ),

            // Social Media Section
            Container(
              padding: const EdgeInsets.all(20),
              color: Colors.grey[50],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Follow Us', Icons.share),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildSocialButton(
                        icon: Icons.facebook,
                        label: 'Facebook',
                        color: 0xFF1877F2,
                        onTap: () => _launchURL('https://facebook.com/maizecrop'),
                      ),
                      _buildSocialButton(
                        icon: Icons.photo_camera,
                        label: 'Instagram',
                        color: 0xFFE4405F,
                        onTap: () => _launchURL('https://instagram.com/maizecrop'),
                      ),
                      _buildSocialButton(
                        icon: Icons.chat,
                        label: 'Twitter',
                        color: 0xFF1DA1F2,
                        onTap: () => _launchURL('https://twitter.com/maizecrop'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildSocialButton(
                        icon: Icons.play_circle_filled,
                        label: 'YouTube',
                        color: 0xFFFF0000,
                        onTap: () => _launchURL('https://youtube.com/maizecrop'),
                      ),
                      _buildSocialButton(
                        icon: Icons.work,
                        label: 'LinkedIn',
                        color: 0xFF0077B5,
                        onTap: () => _launchURL('https://linkedin.com/company/maizecrop'),
                      ),
                      _buildSocialButton(
                        icon: Icons.code,
                        label: 'GitHub',
                        color: 0xFF333333,
                        onTap: () => _launchURL('https://github.com/maizecrop'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // FAQ Section
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Frequently Asked Questions', Icons.help_outline),
                  const SizedBox(height: 16),

                  _buildFAQItem(
                    question: 'How does disease detection work?',
                    answer: 'Our AI model analyzes maize leaf images to detect common diseases like Northern Leaf Blight, Gray Leaf Spot, and Rust.',
                  ),

                  _buildFAQItem(
                    question: 'Is my data secure?',
                    answer: 'Yes, all scans are encrypted and we never share your personal data with third parties.',
                  ),

                  _buildFAQItem(
                    question: 'Can I use the app offline?',
                    answer: 'Basic features work offline, but disease detection requires an internet connection.',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[700]!, Colors.green[500]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const CircleAvatar(
              radius: 40,
              backgroundColor: Colors.white,
              child: Icon(
                Icons.agriculture,
                size: 45,
                color: Colors.green,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'MaizeCrop Support',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We\'re here to help you grow healthy crops',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.green[700], size: 24),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required int color,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color(color),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildFAQItem({required String question, required String answer}) {
    return ExpansionTile(
      title: Text(
        question,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            answer,
            style: TextStyle(color: Colors.grey[700]),
          ),
        ),
      ],
    );
  }

  void _launchEmail(String email) async {
    final Uri emailUri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      //_showSnackBar(ScaffoldMessengerKey.of(navigatorKey.currentContext!), 'Could not launch email');
    }
  }

  void _launchPhone(String phone) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      //_showSnackBar(ScaffoldMessengerKey.of(navigatorKey.currentContext!), 'Could not launch phone');
    }
  }

  void _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      //_showSnackBar(ScaffoldMessengerKey.of(navigatorKey.currentContext!), 'Could not launch $url');
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

