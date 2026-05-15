import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  bool _autoSaveScans = true;
  String _selectedLanguage = 'English';
  String _selectedUnitSystem = 'Metric';
  double _imageQuality = 80;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Preferences Section
            _buildSectionHeader('Preferences', Icons.person_outline),
            _buildSwitchTile(
              icon: Icons.notifications_active,
              title: 'Push Notifications',
              subtitle: 'Get alerts about disease outbreaks and tips',
              value: _notificationsEnabled,
              onChanged: (value) {
                setState(() {
                  _notificationsEnabled = value;
                });
                _showSnackBar(context, 'Notifications ${value ? "enabled" : "disabled"}');
              },
            ),
            _buildSwitchTile(
              icon: Icons.dark_mode,
              title: 'Dark Mode',
              subtitle: 'Switch to dark theme',
              value: _darkModeEnabled,
              onChanged: (value) {
                setState(() {
                  _darkModeEnabled = value;
                });
                _showSnackBar(context, 'Dark mode ${value ? "enabled" : "disabled"}');
              },
            ),
            _buildSwitchTile(
              icon: Icons.save,
              title: 'Auto-save Scans',
              subtitle: 'Automatically save disease scan results',
              value: _autoSaveScans,
              onChanged: (value) {
                setState(() {
                  _autoSaveScans = value;
                });
                _showSnackBar(context, 'Auto-save ${value ? "enabled" : "disabled"}');
              },
            ),

            _buildDivider(),

            // Appearance Section
            _buildSectionHeader('Appearance', Icons.palette_outlined),
            _buildDropdownTile(
              icon: Icons.language,
              title: 'Language',
              value: _selectedLanguage,
              items: ['English', 'Spanish', 'French', 'Hindi', 'Chinese'],
              onChanged: (value) {
                setState(() {
                  _selectedLanguage = value!;
                });
                _showSnackBar(context, 'Language changed to $_selectedLanguage');
              },
            ),
            _buildDropdownTile(
              icon: Icons.straighten,
              title: 'Unit System',
              value: _selectedUnitSystem,
              items: ['Metric', 'Imperial'],
              onChanged: (value) {
                setState(() {
                  _selectedUnitSystem = value!;
                });
                _showSnackBar(context, 'Unit system changed to $_selectedUnitSystem');
              },
            ),

            // Image Quality Slider
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.image, color: Colors.green[600], size: 24),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Image Quality',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Higher quality takes more storage',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${_imageQuality.round()}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _imageQuality,
                    min: 30,
                    max: 100,
                    activeColor: Colors.green[700],
                    onChanged: (value) {
                      setState(() {
                        _imageQuality = value;
                      });
                    },
                  ),
                ],
              ),
            ),

            _buildDivider(),

            // Data & Storage Section
            _buildSectionHeader('Data & Storage', Icons.storage),
            _buildActionTile(
              icon: Icons.delete_sweep,
              title: 'Clear Cache',
              subtitle: 'Free up storage space',
              onTap: () => _showDeleteDialog(context, 'cache'),
              iconColor: Colors.orange,
            ),
            _buildActionTile(
              icon: Icons.delete_forever,
              title: 'Delete All Scan History',
              subtitle: 'This action cannot be undone',
              onTap: () => _showDeleteDialog(context, 'all scans'),
              iconColor: Colors.red,
            ),

            _buildDivider(),

            // About Section
            _buildSectionHeader('About', Icons.info_outline),
            _buildInfoTile(
              title: 'App Version',
              value: '1.0.0',
            ),
            _buildInfoTile(
              title: 'Build Number',
              value: '2026.01',
            ),
            _buildInfoTile(
              title: 'Privacy Policy',
              value: 'View →',
              onTap: () => _showSnackBar(context, 'Opening Privacy Policy...'),
            ),
            _buildInfoTile(
              title: 'Terms of Service',
              value: 'View →',
              onTap: () => _showSnackBar(context, 'Opening Terms of Service...'),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.grey[100],
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.green[700]),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(icon, color: Colors.green[600]),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
      activeColor: Colors.green[700],
    );
  }

  Widget _buildDropdownTile({
    required IconData icon,
    required String title,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.green[600]),
      title: Text(title),
      trailing: DropdownButton<String>(
        value: value,
        items: items.map((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item),
          );
        }).toList(),
        onChanged: onChanged,
        underline: const SizedBox(),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? Colors.green[600]),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }

  Widget _buildInfoTile({
    required String title,
    required String value,
    VoidCallback? onTap,
  }) {
    return ListTile(
      title: Text(title),
      trailing: Text(
        value,
        style: TextStyle(
          color: onTap != null ? Colors.green[700] : Colors.grey[600],
          fontWeight: onTap != null ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey[200],
    );
  }

  void _showDeleteDialog(BuildContext context, String type) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete $type?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showSnackBar(context, '$type deleted successfully');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
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