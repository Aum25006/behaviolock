import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:jwt_decoder/jwt_decoder.dart' as jwt_decoder;
import 'package:logging/logging.dart';
import 'package:dio/dio.dart';
import '../models/user_model.dart';
import 'api_service.dart';

final _logger = Logger('AuthService');

class AuthService with ChangeNotifier {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'current_user';

  final LocalAuthentication _localAuth = LocalAuthentication();
  late ApiService _apiService;

  String? _token;
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

  // Constructor that accepts ApiService
  AuthService({required ApiService apiService}) {
    _apiService = apiService;
  }

  // Method to update the ApiService reference (for circular dependency resolution)
  void updateApiService(ApiService apiService) {
    _apiService = apiService;
  }

  // Getters
  UserModel? get currentUser => _currentUser;

  /// Attempts to refresh the authentication token using the refresh token
  /// Returns true if the token was successfully refreshed, false otherwise
  Future<bool> refreshToken() async {
    if (_isLoading) return false;

    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('refresh_token');

    if (refreshToken == null) {
      _logger.warning('No refresh token available');
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _logger.info('Attempting to refresh authentication token');

      // Call the refresh token endpoint
      final response = await _apiService.post(
        '/api/auth/refresh',
        data: {'refreshToken': refreshToken},
      );

      if (response['token'] != null) {
        // Save the new token
        await _saveToken(response['token']);
        _logger.info('Token refreshed successfully');
        return true;
      } else {
        _logger.warning('Token refresh failed: No token in response');
        return false;
      }
    } catch (e) {
      _logger.severe('Error refreshing token', e);
      _error = 'Failed to refresh session. Please log in again.';
      // Clear auth state on refresh failure
      await _clearAuthState();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveToken(String token) async {
    _logger.fine('Saving token to memory and shared preferences');
    _token = token;

    // Save token to shared preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);

    // Set token in API service
    _apiService.setAuthToken(token);
    _logger.fine('Token set in API service');

    // Decode token to get user info
    try {
      // Decode the JWT token to get user claims
      final Map<String, dynamic> decoded = jwt_decoder.JwtDecoder.decode(token);
      _logger.fine('Decoded token claims: $decoded');

      // Extract user data from the token claims and ensure all fields are non-null
      final userData = <String, dynamic>{
        'id': decoded['sub']?.toString() ?? '',
        'email': decoded['email']?.toString() ?? '',
        'name': decoded['name']?.toString() ?? '',
        'phoneNumber': decoded['phoneNumber']?.toString() ?? '',
      };

      // Create user model from the extracted data
      _currentUser = UserModel.fromMap(userData);

      // Save to shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);

      // Save user data
      if (_currentUser != null) {
        await prefs.setString(_userKey, _currentUser!.toJson());
      }
    } catch (e) {
      _logger.severe('Error parsing token', e);
      throw Exception('Invalid token format');
    }
  }

  Future<void> _clearAuthState() async {
    _logger.fine('Clearing authentication state');
    _token = null;
    _currentUser = null;

    // Clear token from API service
    _apiService.setAuthToken(null);
    _logger.fine('Cleared token from API service');

    // Clear from shared preferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
      _logger.fine('Cleared auth data from shared preferences');
    } catch (e) {
      _logger.severe('Error clearing auth data from shared preferences', e);
      // Don't rethrow - we want to continue even if clearing fails
    }

    notifyListeners();
  }

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null && _token != null;
  String? get token => _token;
  bool get isInitialized => _isInitialized;

  /// Initializes the authentication service by loading the token and user data from shared preferences.
  /// This should be called when the app starts.
  Future<void> initAuthService() async {
    if (_isInitialized) return;

    _logger.fine('Initializing AuthService');
    _isLoading = true;
    _error = null;

    try {
      final prefs = await SharedPreferences.getInstance();

      // Load token from shared preferences
      final token = prefs.getString(_tokenKey);

      if (token != null) {
        _logger.info('Found stored token, loading user data');
        _token = token;

        // Set the token in the API service immediately
        _apiService.setAuthToken(token);
        _logger.info(
          'Token set in API service: ${_apiService.hasAuthToken ? 'YES' : 'NO'}',
        );

        // Load user data
        final userJson = prefs.getString(_userKey);
        if (userJson != null) {
          try {
            dynamic decoded = jsonDecode(userJson);
            // If decoded is a String, decode again (handles double-encoded cases)
            if (decoded is String) {
              decoded = jsonDecode(decoded);
            }
            final userMap = Map<String, dynamic>.from(decoded as Map);
            _currentUser = UserModel.fromMap(userMap);
            _logger.info('Loaded user data for ${_currentUser?.email}');
          } catch (e) {
            _logger.warning('Failed to parse stored user data', e);
            // If we can't parse the user data, clear everything
            await _clearAuthState();
          }
        }
      } else {
        _logger.fine('No stored token found');
      }

      _isInitialized = true;
      _logger.info('AuthService initialized');
    } catch (e, stackTrace) {
      _logger.severe('Error initializing AuthService', e, stackTrace);
      _error = 'Failed to initialize authentication';
      await _clearAuthState();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sign up a new user
  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    String phoneNumber = '',
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _logger.fine('Attempting to register user: $email');

      final response = await _apiService.post(
        '/api/auth/signup',
        data: {
          'first_name': name.split(' ').first,
          'last_name': name.split(' ').length > 1
              ? name.split(' ').skip(1).join(' ')
              : '',
          'email': email,
          'password': password,
          'phone': phoneNumber,
        },
      );

      _logger.fine('Registration response received');
      _logger.finest('Response data: $response');

      // Check if the response contains the expected data
      if (response['access_token'] == null) {
        throw Exception('No access token received from server');
      }

      // If we get here, the request was successful
      final token = response['access_token'] as String;
      _logger.info('Registration successful, token received');
      final userData = response['user'] as Map<String, dynamic>;

      if (token.isNotEmpty && userData.isNotEmpty) {
        // Create UserModel using our helper method
        final user = _createUserFromResponse(userData);
        await _saveAuthData(token, user);
        return true;
      } else {
        throw Exception('No token or user data received from server');
      }
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Initialize auth service
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      _logger.fine('Initializing AuthService, token exists: ${token != null}');

      if (token != null) {
        _token = token;
        // Verify token is not expired
        if (jwt_decoder.JwtDecoder.isExpired(token)) {
          _logger.info('Token expired, logging out');
          await _logout();
          return;
        }

        // Set the token in the API service
        _apiService.setAuthToken(token);

        // Get user data from SharedPreferences
        final userData = prefs.getString(_userKey);
        if (userData != null) {
          try {
            _logger.fine('Loading user data from SharedPreferences');
            final userMap = jsonDecode(userData) as Map<String, dynamic>;
            _currentUser = UserModel.fromMap(userMap);
            _logger.info(
              'User loaded from SharedPreferences: ${_currentUser?.email}',
            );
          } catch (e, stackTrace) {
            _logger.severe(
              'Error loading user data from SharedPreferences',
              e,
              stackTrace,
            );
            // If we can't load the user data, try to fetch it from the API
            await fetchCurrentUser();
          }
        } else {
          // If no user data in local storage, fetch from API
          _logger.fine('No user data in SharedPreferences, fetching from API');
          await fetchCurrentUser();
        }
      }
    } catch (e, stackTrace) {
      _error = 'Failed to initialize authentication';
      _logger.severe('AuthService initialization error', e, stackTrace);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Fetch current user from API
  Future<void> fetchCurrentUser() async {
    try {
      _logger.fine('Fetching current user from API');
      final response = await _apiService.get('/api/user/me');

      // Check if response is a string (error message) or Map
      if (response is String) {
        _logger.warning('API returned string instead of JSON: $response');
        // Check if it's an authentication error
        if (response.toLowerCase().contains('unauthorized') ||
            response.toLowerCase().contains('401') ||
            response.toLowerCase().contains('jwt')) {
          throw Exception(
            'Authentication required. Please check your credentials.',
          );
        }
        throw Exception(response);
      }

      // At this point, response should be a Map<String, dynamic>
      _currentUser = _createUserFromResponse(response);
      await _saveUser(_currentUser!);
      _logger.info('Successfully fetched current user: ${_currentUser?.email}');
    } catch (e, stackTrace) {
      _error = 'Failed to fetch user data';
      _logger.severe('Error fetching current user', e, stackTrace);
      rethrow;
    }
  }

  // Logout user
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    _currentUser = null;
    _apiService.setAuthToken(null);
    notifyListeners();
  }

  // Sign in with email and password
  Future<bool> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _logger.fine('Attempting to sign in user: $email');

      // Log the request details
      _logger.fine('Sending login request to /api/auth/login');
      _logger.finest('Request data: {"email": "$email", "password": "****"}');

      final response = await _apiService.post(
        '/api/auth/login',
        data: {'email': email, 'password': password},
      );

      _logger.fine('Login response received');
      _logger.finest('Full response data: $response');

      // Check if response is a string (error message) or Map
      if (response is String) {
        _logger.warning('API returned string instead of JSON: $response');
        // Check if it's an authentication error
        final responseStr = response as String;
        if (responseStr.toLowerCase().contains('unauthorized') ||
            responseStr.toLowerCase().contains('401') ||
            responseStr.toLowerCase().contains('jwt')) {
          throw Exception(
            'Authentication required. Please check your credentials.',
          );
        }
        throw Exception(response);
      }

      // Check if the response contains the expected data
      if (response['access_token'] == null) {
        _logger.warning(
          'No access_token in response. Response keys: ${response.keys}',
        );
        throw Exception('No access token received from server');
      }

      // If we get here, the request was successful
      final token = response['access_token'] as String;
      _logger.fine('Received access token: ${token.substring(0, 10)}...');

      // Handle different response structures
      Map<String, dynamic> userData;
      if (response['user'] != null) {
        _logger.fine('Found user data in response');
        userData = response['user'] as Map<String, dynamic>;
      } else {
        _logger.warning(
          'No user data in response, creating minimal user object',
        );
        // If user data is not in the response, create a minimal user object
        userData = {
          'id': response['user_id'] ?? 'unknown',
          'email': email,
          'name': response['name'] ?? email.split('@').first,
        };
      }

      if (token.isNotEmpty) {
        try {
          _logger.fine('Creating UserModel from response data');
          // Create UserModel using our helper method
          final user = _createUserFromResponse(userData);

          _logger.fine('Saving token and user data');
          // Save the token and user data
          await _saveToken(token);
          await _saveUser(user);

          // Set the token in the API service
          _apiService.setAuthToken(token);

          _logger.info('User ${user.email} signed in successfully');
          return true;
        } catch (e, stackTrace) {
          _logger.severe('Error processing login response', e, stackTrace);
          _error = 'Failed to process login response: ${e.toString()}';
          return false;
        }
      } else {
        _logger.warning('Received empty token in login response');
        _error = 'Invalid server response: Empty token';
        return false;
      }
    } on DioException catch (e) {
      _logger.severe('Dio error during login', e);
      if (e.response != null) {
        _logger.severe('Error response data: ${e.response?.data}');
        _logger.severe('Status code: ${e.response?.statusCode}');
        _error =
            e.response?.data['message'] ??
            'Login failed. Please check your credentials.';
      } else {
        _error = 'Network error. Please check your connection.';
      }
      return false;
    } catch (e, stackTrace) {
      _logger.severe('Unexpected error during login', e, stackTrace);
      _error = 'An unexpected error occurred: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sign out
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _logout();
    } catch (e) {
      _error = 'Failed to sign out';
      debugPrint('Sign out error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Biometric authentication
  Future<bool> authenticateWithBiometrics() async {
    try {
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      if (!canCheckBiometrics) return false;

      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to access your account',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      return didAuthenticate;
    } catch (e) {
      debugPrint('Biometric authentication error: $e');
      return false;
    }
  }

  // Create UserModel from API response data
  UserModel _createUserFromResponse(Map<String, dynamic> userData) {
    try {
      _logger.finest('Creating UserModel from response data: $userData');
      // Create UserModel directly from the map
      return UserModel.fromMap(userData);
    } catch (e, stackTrace) {
      _logger.severe('Error creating UserModel from response', e, stackTrace);
      rethrow;
    }
  }

  // Save user to shared preferences
  Future<void> _saveUser(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userMap = user.toMap();
      await prefs.setString(_userKey, jsonEncode(userMap));
      _currentUser = user;
      _logger.fine('User data saved to SharedPreferences: ${user.email}');
      notifyListeners();
    } catch (e, stackTrace) {
      _logger.severe('Error saving user to SharedPreferences', e, stackTrace);
      rethrow;
    }
  }

  // Save authentication data to SharedPreferences
  Future<void> _saveAuthData(String token, UserModel user) async {
    try {
      _logger.fine('Saving auth data for user: ${user.email}');

      // Debug log the user data before saving
      _logger.finest('User data to save: ${user.toJson()}');

      final prefs = await SharedPreferences.getInstance();

      // Save token
      await prefs.setString(_tokenKey, token);
      _logger.finest('Token saved successfully');

      // Convert user to JSON and save
      final userJsonString = user.toJson();
      await prefs.setString(_userKey, userJsonString);
      _logger.finest('User data saved successfully');

      // Update current user and authentication state
      _currentUser = user;
      _isLoading = false;
      _error = null;

      // Set the token in the API service for future requests
      _apiService.setAuthToken(token);

      _logger.info('Auth data saved successfully for user: ${user.email}');
      notifyListeners();
    } catch (e, stackTrace) {
      _logger.severe('Error saving auth data: $e', e, stackTrace);
      rethrow;
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // In a real app, this would call your backend API to send a password reset email
      // For demo purposes, we'll just simulate a network delay
      await Future.delayed(const Duration(seconds: 1));

      // Check if the email exists in the stored users
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString(_userKey);

      if (userData == null) {
        throw Exception('No account found with that email.');
      }

      // Decode stored user JSON
      dynamic decoded = jsonDecode(userData);
      if (decoded is String) {
        decoded = jsonDecode(decoded);
      }
      final userMap = Map<String, dynamic>.from(decoded as Map);

      final storedEmail = userMap['email'] as String?;
      if (storedEmail?.toLowerCase() != email.toLowerCase()) {
        throw Exception('No account found with that email.');
      }

      // In a real app, you would send a password reset email here
      debugPrint('Password reset email sent to $email');
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
