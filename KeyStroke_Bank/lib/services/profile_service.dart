import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'auth_service.dart';
import 'api_service.dart';
import '../screens/auth/mpin_screens.dart';

class ProfileService extends ChangeNotifier {
  final AuthService _auth;
  final ApiService _api;
  final _logger = Logger('ProfileService');

  ProfileService({
    required AuthService authService,
    required ApiService apiService,
  }) : _auth = authService,
       _api = apiService;

  Map<String, dynamic> _profile = {};
  bool _isLoading = false;
  String? _error;

  Map<String, dynamic> get profile => _profile;
  String? get name => _profile['name'] as String?;
  String? get phone => _profile['phone'] as String?;
  String? get address => _profile['address'] as String?;
  String? get photoBase64 => _profile['photo'] as String?;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> initialize() async {
    final user = _auth.currentUser;
    if (user == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.get('/api/profiles');
      _logger.fine('Profile API response: $response');

      if (response['status'] == 'success') {
        _profile = Map<String, dynamic>.from(response['data'] ?? {});
        _logger.info('Loaded profile from API');
      } else {
        throw Exception(response['message'] ?? 'Failed to load profile');
      }
    } catch (e) {
      _error = 'Failed to load profile: ${e.toString()}';
      _logger.severe('Error loading profile', e);
      // Don't rethrow - allow app to work with empty profile
      _profile = {};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveProfile({
    String? name,
    String? phone,
    String? address,
    String? photoBase64,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final requestData = <String, dynamic>{};
      if (name != null) requestData['name'] = name;
      if (phone != null) requestData['phone'] = phone;
      if (address != null) requestData['address'] = address;
      if (photoBase64 != null) requestData['photo'] = photoBase64;

      final response = await _api.post('/api/profiles', data: requestData);
      _logger.fine('Save profile response: $response');

      if (response['status'] == 'success') {
        // Update local profile with response data
        _profile = Map<String, dynamic>.from(response['data'] ?? {});
        _logger.info('Profile saved successfully');
      } else {
        throw Exception(response['message'] ?? 'Failed to save profile');
      }
    } catch (e) {
      _error = 'Failed to save profile: ${e.toString()}';
      _logger.severe('Error saving profile', e);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> hasMpin() async {
    await _auth.fetchCurrentUser(); // Ensure 100% sync from live database
    final user = _auth.currentUser;
    return user?.hasMpin ?? false;
  }

  Future<bool> requireMpin(BuildContext context) async {
    if (!await hasMpin()) {
      if (context.mounted) {
        final result = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.security, color: Colors.blueAccent),
                SizedBox(width: 8),
                Text('MPIN Required'),
              ],
            ),
            content: const Text(
              'You must set up a secure 4-digit MPIN before transferring funds. Do you want to set it up now?',
            ),
            actions: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.pop(ctx, false),
              ),
              ElevatedButton(
                child: const Text('Setup MPIN'),
                onPressed: () => Navigator.pop(ctx, true),
              ),
            ],
          ),
        );

        if (result == true) {
          if (context.mounted) {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MpinSetupScreen()),
            );
            final user = _auth.currentUser;
            if (user == null || !user.hasMpin) return false;
          } else {
            return false;
          }
        } else {
          return false;
        }
      } else {
        return false;
      }
    }

    // Launch secure 3-strike modal
    if (context.mounted) {
      return await MpinVerificationModal.show(context);
    }
    return false;
  }
}
