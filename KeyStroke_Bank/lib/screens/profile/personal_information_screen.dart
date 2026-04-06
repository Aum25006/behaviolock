import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../../services/profile_service.dart';
import '../auth/mpin_screens.dart';

class PersonalInformationScreen extends StatelessWidget {
  const PersonalInformationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final user = auth.currentUser;
    final profile = context.watch<ProfileService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Personal Information')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Name'),
              subtitle: Text(profile.name ?? user?.name ?? 'Unknown'),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () async {
                  final ctrl = TextEditingController(
                    text: profile.name ?? user?.name ?? '',
                  );
                  final newName = await showDialog<String>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Update Name'),
                      content: TextField(controller: ctrl),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(context, ctrl.text.trim()),
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  );
                  if (newName != null &&
                      newName.isNotEmpty &&
                      context.mounted) {
                    await context.read<ProfileService>().saveProfile(
                      name: newName,
                    );
                  }
                },
              ),
            ),
            const Divider(height: 1),
            // Profile photo
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Profile Photo'),
              subtitle: const Text('Tap to update'),
              onTap: () async {
                final picker = ImagePicker();
                final img = await picker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 800,
                );
                if (img != null && context.mounted) {
                  final bytes = await img.readAsBytes();
                  final b64 = base64Encode(bytes);
                  if (context.mounted) {
                    await context.read<ProfileService>().saveProfile(
                      photoBase64: b64,
                    );
                  }
                }
              },
              trailing: (profile.photoBase64 != null)
                  ? CircleAvatar(
                      backgroundImage: MemoryImage(
                        base64Decode(profile.photoBase64!),
                      ),
                    )
                  : const CircleAvatar(child: Icon(Icons.person)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Email'),
              subtitle: Text(user?.email ?? 'Unknown'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.phone_outlined),
              title: const Text('Phone Number'),
              subtitle: Text(profile.phone ?? user?.phoneNumber ?? 'Not set'),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () async {
                  final ctrl = TextEditingController(text: profile.phone ?? '');
                  final value = await showDialog<String>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Update Phone Number'),
                      content: TextField(
                        controller: ctrl,
                        keyboardType: TextInputType.phone,
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(context, ctrl.text.trim()),
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  );
                  if (value != null && value.isNotEmpty && context.mounted) {
                    await context.read<ProfileService>().saveProfile(
                      phone: value,
                    );
                  }
                },
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('Address'),
              subtitle: Text(profile.address ?? 'Not set'),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () async {
                  final ctrl = TextEditingController(
                    text: profile.address ?? '',
                  );
                  final value = await showDialog<String>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Update Address'),
                      content: TextField(controller: ctrl, maxLines: 3),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(context, ctrl.text.trim()),
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  );
                  if (value != null && value.isNotEmpty && context.mounted) {
                    await context.read<ProfileService>().saveProfile(
                      address: value,
                    );
                  }
                },
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('MPIN (4 digits)'),
              subtitle: const Text('Required before transactions'),
              trailing: ElevatedButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MpinSetupScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.inverseSurface,
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onInverseSurface,
                ),
                child: const Text('Set/Update'),
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 12),
            const Text(
              'Your details are stored locally for demo.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
