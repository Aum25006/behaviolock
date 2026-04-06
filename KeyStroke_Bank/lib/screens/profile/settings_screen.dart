import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/settings_service.dart';
import 'behavioral_settings_screen.dart';
import '../auth/mpin_screens.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Ensure initialization (already kicked in provider creation)
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Push Notifications'),
            value: settings.notifications,
            onChanged: (v) => settings.setNotifications(v),
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text('Dark Mode (demo only)'),
            value: settings.darkMode,
            onChanged: (v) => settings.setDarkMode(v),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Behavioral Authentication'),
            subtitle: const Text('Manage your typing pattern security'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const BehavioralSettingsScreen(),
                ),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.pin),
            title: const Text('MPIN Security'),
            subtitle: const Text('Setup or change your Transaction MPIN'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const MpinSetupScreen(),
                ),
              );
            },
          ),
          const Divider(height: 1),
          const ListTile(title: Text('Supported Card Networks')),
          _networkTile(settings, 'Visa'),
          _networkTile(settings, 'Mastercard'),
          _networkTile(settings, 'American Express (Amex)', keyName: 'Amex'),
          _networkTile(settings, 'Discover'),
          _networkTile(settings, 'RuPay'),
          _networkTile(settings, 'UnionPay'),
          const Divider(height: 1),
          const ListTile(title: Text('Supported Card Types')),
          _typeTile(settings, 'Debit'),
          _typeTile(settings, 'Credit'),
          _typeTile(settings, 'Forex'),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'KetStroke Bank',
              applicationVersion: '0.1.0',
              children: const [Text('Demo settings page.')],
            ),
          ),
        ],
      ),
    );
  }

  Widget _networkTile(
    SettingsService settings,
    String label, {
    String? keyName,
  }) {
    final name = keyName ?? label;
    final enabled = settings.networks.contains(name);
    return CheckboxListTile(
      value: enabled,
      title: Text(label),
      onChanged: (v) => settings.toggleNetwork(name, v ?? false),
    );
  }

  Widget _typeTile(SettingsService settings, String label) {
    final enabled = settings.cardTypes.contains(label);
    return CheckboxListTile(
      value: enabled,
      title: Text(label),
      onChanged: (v) => settings.toggleCardType(label, v ?? false),
    );
  }
}
