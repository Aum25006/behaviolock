import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'auth_service.dart';

class ApiService {
  final Dio _dio = Dio();
  final _logger = Logger('ApiService');
  AuthService? _authService;

  // Initialize with base URL and optional auth service
  ApiService({required String baseUrl, AuthService? authService}) 
      : _authService = authService {
    // Always use the provided base URL for direct backend connection
    String normalizedBaseUrl = baseUrl.endsWith('/') 
        ? baseUrl.substring(0, baseUrl.length - 1) 
        : baseUrl;
    _dio.options.baseUrl = normalizedBaseUrl;
    _logger.info('Initialized with base URL: $normalizedBaseUrl');
    _dio.options.connectTimeout = const Duration(seconds: 30); // Increased timeout
    _dio.options.receiveTimeout = const Duration(seconds: 30); // Increased timeout
    _dio.options.responseType = ResponseType.json;
    _dio.options.followRedirects = true;
    _dio.options.validateStatus = (status) => status! < 500;
    
    // Configure default headers (only client headers, not CORS headers)
    _dio.options.headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    // Add request interceptor for logging
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        _logger.fine('Request: ${options.method} ${options.uri}');
        _logger.fine('Headers: ${options.headers}');
        if (options.data != null) {
          _logger.fine('Request Data: ${options.data}');
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        _logger.fine('Response: ${response.statusCode} ${response.statusMessage}');
        _logger.fine('Response Data: ${response.data}');
        return handler.next(response);
      },
      onError: (DioException e, handler) {
        _logger.severe('API Error: ${e.message}');
        _logger.severe('Error Response: ${e.response?.data}');
        _logger.severe('Error Headers: ${e.response?.headers}');
        return handler.next(e);
      },
    ));
    _logger.info('Initialized ApiService with base URL: ${_dio.options.baseUrl}');
  }

  void setAuthToken(String? token) {
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
      _logger.info('Auth token set in API service: Bearer ${token.substring(0, 10)}...');
      _logger.info('Headers after setting token: ${_dio.options.headers}');
    } else {
      _dio.options.headers.remove('Authorization');
      _logger.info('Auth token removed from API service');
    }
  }
  
  bool get hasAuthToken {
    return _dio.options.headers['Authorization'] != null;
  }
  
  String? get authToken {
    return _dio.options.headers['Authorization'] as String?;
  }
  
  // Method to set the auth service after initialization
  void setAuthService(AuthService authService) {
    _authService = authService;
  }

  // Generic request handler with retry and token refresh logic
  Future<dynamic> _makeRequest(
    Future<Response<dynamic>> Function() request, {
    bool retryOnAuthError = true,
  }) async {
    // Log the current auth token for debugging
    final authHeader = _dio.options.headers['Authorization'] as String?;
    _logger.fine('Making request with auth token: ${authHeader != null ? '${authHeader.substring(0, 15)}...' : 'none'}');
    try {
      final response = await request();
      _logger.fine('API request successful: ${response.requestOptions.path}');
      _logger.fine('Response data type: ${response.data.runtimeType}');
      _logger.fine('Response data: ${response.data}');
      
      return response.data;
    } on DioException catch (e) {
      // Handle 401 Unauthorized errors with token refresh
      if (e.response?.statusCode == 401 && retryOnAuthError && _authService != null) {
        _logger.warning('Authentication error, attempting to refresh token...');
        
        try {
          // Attempt to refresh the token
          final refreshed = await _authService!.refreshToken();
          
          if (refreshed) {
            _logger.info('Token refreshed successfully, retrying original request');
            // Retry the original request with the new token
            return _makeRequest(request, retryOnAuthError: false);
          } else {
            _logger.warning('Token refresh failed, clearing auth state');
            // If refresh fails, clear auth state and rethrow
            await _authService!.signOut();
            throw Exception('Session expired. Please log in again.');
          }
        } catch (refreshError) {
          _logger.severe('Error during token refresh', refreshError);
          await _authService?.signOut();
          throw Exception('Session expired. Please log in again.');
        }
      }
      
      _logger.severe('API request failed', e);
      throw _handleError(e);
    } catch (e) {
      _logger.severe('Unexpected error in API request', e);
      rethrow;
    }
  }

  Future<dynamic> get(String endpoint, {Map<String, dynamic>? queryParameters}) async {
    _logger.info('GET $endpoint');
    _logger.info('Base URL: ${_dio.options.baseUrl}');
    _logger.info('Full URL: ${_dio.options.baseUrl}$endpoint');
    _logger.info('Request headers: ${_dio.options.headers}');
    return _makeRequest(
      () => _dio.get<dynamic>(
        endpoint,
        queryParameters: queryParameters,
        options: Options(
          headers: _dio.options.headers, // Ensure headers are included
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> post(String endpoint, {dynamic data}) async {
    _logger.fine('POST $endpoint');
    _logger.fine('Request headers: ${_dio.options.headers}');
    _logger.fine('Request data: $data');
    
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        endpoint,
        data: data,
        options: Options(
          headers: _dio.options.headers,
          responseType: ResponseType.json,
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      
      _logger.fine('Response status: ${response.statusCode}');
      _logger.fine('Response data: ${response.data}');
      
      if (response.data == null) {
        throw Exception('Empty response from server');
      }
      
      return response.data!;
    } on DioException catch (e) {
      _logger.severe('API request failed', e);
      throw _handleError(e);
    } catch (e) {
      _logger.severe('Unexpected error in POST request', e);
      throw Exception('An unexpected error occurred');
    }
  }

  Future<dynamic> put(String endpoint, {dynamic data}) async {
    return _makeRequest(
      () => _dio.put<dynamic>(
        endpoint,
        data: data,
      ),
    );
  }

  Future<dynamic> delete(String endpoint, {dynamic data}) async {
    return _makeRequest(
      () => _dio.delete<dynamic>(
        endpoint,
        data: data,
      ),
    );
  }

  Exception _handleError(DioException error) {
    _logger.severe(
      'API Error: ${error.type} - ${error.message}',
      error,
      error.stackTrace,
    );

    if (error.response != null) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final message = data['message'] ?? data['error'] ?? 'An error occurred';
        return Exception(message);
      }
      return Exception('Server error: ${error.response?.statusCode}');
    } else {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
          return Exception('Connection timeout. Please check your internet connection.');
        case DioExceptionType.receiveTimeout:
          return Exception('Server took too long to respond. Please try again.');
        case DioExceptionType.sendTimeout:
          return Exception('Request timed out. Please check your internet connection.');
        case DioExceptionType.badCertificate:
          return Exception('Security certificate error. Please try again later.');
        case DioExceptionType.connectionError:
          return Exception('Connection error. Please check your internet connection.');
        default:
          return Exception('Network error: ${error.message}');
      }
    }
  }
}
