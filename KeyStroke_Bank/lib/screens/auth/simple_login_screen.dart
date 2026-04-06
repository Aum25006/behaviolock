import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logging/logging.dart';
import '../../services/auth_service.dart';
// import '../../services/keystroke_service.dart'; // Handled in main app now
import 'behavioral_calibration_screen.dart';

class SimpleLoginScreen extends StatefulWidget {
  final VoidCallback? onSignUpPressed;
  final VoidCallback? onForgotPasswordPressed;

  const SimpleLoginScreen({
    super.key,
    this.onSignUpPressed,
    this.onForgotPasswordPressed,
  });

  @override
  State<SimpleLoginScreen> createState() => _SimpleLoginScreenState();
}

class _SimpleLoginScreenState extends State<SimpleLoginScreen> {
  static final Logger _logger = Logger('SimpleLoginScreen');
  
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _showBehavioralSetup = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);

      // Step 1: Traditional authentication
      _logger.info('Starting traditional authentication');
      final success = await authService.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (!success) {
        _showErrorSnackBar(authService.error);
        return;
      }

      // Step 2: Login successful - let main app handle behavioral setup
      _logger.info('Login successful, main app will handle behavioral setup check');

    } catch (e, stackTrace) {
      _logger.severe('Login error', e, stackTrace);
      if (!mounted) return;
      _showErrorSnackBar('An error occurred during login. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String? error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'An error occurred'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onBehavioralSetupComplete() {
    setState(() {
      _showBehavioralSetup = false;
    });
    _showSuccessMessage('Behavioral authentication is now active!');
  }

  void _onBehavioralSetupSkipped() {
    setState(() {
      _showBehavioralSetup = false;
    });
    _showSuccessMessage('You can set up behavioral authentication later in Settings');
  }

  @override
  Widget build(BuildContext context) {
    // Show behavioral setup screen if needed
    if (_showBehavioralSetup) {
      return BehavioralCalibrationScreen(
        onCalibrationComplete: _onBehavioralSetupComplete,
        onSkip: _onBehavioralSetupSkipped,
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo and Title
                const Icon(
                  Icons.security,
                  size: 80,
                  color: Colors.blue,
                ),
                const SizedBox(height: 24),
                const Text(
                  'BehavioLock',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Secure Banking with Behavioral Authentication',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // Email Field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!RegExp(r'^[^@]+@[^\s]+\.[^\s]+').hasMatch(value)) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Login Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Sign In',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
                const SizedBox(height: 16),

                // Sign Up Link
                if (widget.onSignUpPressed != null)
                  TextButton(
                    onPressed: widget.onSignUpPressed,
                    child: const Text('Don\'t have an account? Sign Up'),
                  ),

                // Forgot Password Link
                if (widget.onForgotPasswordPressed != null)
                  TextButton(
                    onPressed: widget.onForgotPasswordPressed,
                    child: const Text('Forgot Password?'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
