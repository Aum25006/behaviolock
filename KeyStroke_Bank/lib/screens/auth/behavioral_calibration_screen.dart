import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logging/logging.dart';
import '../../services/keystroke_service.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/behavioral_text_field.dart';

class BehavioralCalibrationScreen extends StatefulWidget {
  final VoidCallback? onCalibrationComplete;
  final VoidCallback? onSkip;

  const BehavioralCalibrationScreen({
    super.key,
    this.onCalibrationComplete,
    this.onSkip,
  });

  @override
  State<BehavioralCalibrationScreen> createState() =>
      _BehavioralCalibrationScreenState();
}

class _BehavioralCalibrationScreenState
    extends State<BehavioralCalibrationScreen> {
  static final Logger _logger = Logger('BehavioralCalibrationScreen');

  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isProcessing = false;
  bool _showIntro = true;

  final List<String> _calibrationPrompts = [
    "The quick brown fox jumps over the lazy dog",
    "Banking security is very important for protecting your money",
    "Please type this sentence carefully and naturally",
    "Behavioral authentication learns your unique typing pattern",
    "This is the final calibration step for your security profile",
  ];

  final List<List<KeystrokeData>> _calibrationSessions = [];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPromptComplete(List<KeystrokeData> keystrokeData) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Store the keystroke session
      _calibrationSessions.add(keystrokeData);
      _logger.info('Completed calibration step ${_currentStep + 1}/5');

      // Move to next step or complete calibration
      if (_currentStep < 4) {
        _currentStep++;
        await _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        // Complete calibration
        await _completeCalibration();
      }
    } catch (e, stackTrace) {
      _logger.severe('Error processing calibration step', e, stackTrace);
      _showErrorDialog('Failed to process calibration step. Please try again.');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _completeCalibration() async {
    try {
      _logger.info(
        'Starting behavioral model training with ${_calibrationSessions.length} sessions',
      );

      final keystrokeService = Provider.of<KeystrokeService>(
        context,
        listen: false,
      );
      final apiService = Provider.of<ApiService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.email ?? 'current_user';

      // 1. Train local ML model first
      _logger.info(
        'Starting local calibration with ${_calibrationSessions.length} sessions',
      );
      await keystrokeService.startCalibration(userId);

      for (int i = 0; i < _calibrationSessions.length; i++) {
        final session = _calibrationSessions[i];
        _logger.info(
          'Processing calibration session ${i + 1} with ${session.length} keystrokes',
        );
        await keystrokeService.completeCalibrationStep(session);
      }

      // 2. Extract mathematical matrices
      final profile = keystrokeService.behavioralProfile;
      if (profile == null)
        throw Exception('Local modeling failed to generate profile');

      // 3. Convert raw keystroke data to API format
      final calibrationData = _calibrationSessions.map((session) {
        return session.map((keystroke) => keystroke.toJson()).toList();
      }).toList();

      // 4. Send calibration data and ML matrices to Supabase for synchronized persistence
      final response = await apiService.post(
        '/behavioral/calibrate',
        data: {
          'calibration_sessions': calibrationData,
          'average_timings': profile.averageTimings,
          'standard_deviations': profile.standardDeviations,
        },
      );

      if (response['status'] == 'success') {
        _logger.info(
          'Behavioral calibration synchronized to backend successfully',
        );

        // Force refresh statistics
        final stats = keystrokeService.getBehavioralStats();
        _logger.info('Updated stats: $stats');

        // Show success dialog
        _showSuccessDialog();
      } else {
        throw Exception(
          response['message'] ?? 'Calibration backend sync failed',
        );
      }
    } catch (e, stackTrace) {
      _logger.severe('Error completing calibration', e, stackTrace);
      _showErrorDialog('Failed to complete calibration. Please try again.');
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
        title: const Text('Calibration Complete!'),
        content: const Text(
          'Your behavioral profile has been created successfully. '
          'BehavioLock will now learn and adapt to your unique typing patterns.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onCalibrationComplete?.call();
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.error, color: Colors.red, size: 48),
        title: const Text('Calibration Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _skipCalibration() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skip Calibration?'),
        content: const Text(
          'Skipping calibration will disable behavioral authentication. '
          'You can set it up later in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onSkip?.call();
            },
            child: const Text('Skip'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show intro screen first
    if (_showIntro) {
      return BehavioralSetupIntroScreen(
        onStartCalibration: () {
          setState(() {
            _showIntro = false;
          });
        },
        onSkip: widget.onSkip,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Behavioral Setup'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (widget.onSkip != null)
            TextButton(
              onPressed: _isProcessing ? null : _skipCalibration,
              child: const Text('Skip'),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Progress indicator
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: (_currentStep + 1) / 5,
                            backgroundColor: Colors.grey.shade300,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '${_currentStep + 1}/5',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Setting up your behavioral authentication profile',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              // Calibration prompts
              Flexible(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _calibrationPrompts.length,
                  itemBuilder: (context, index) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Instructions
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Instructions',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    '• Type naturally at your normal speed\n'
                                    '• Don\'t worry about mistakes - just type as you normally would\n'
                                    '• This helps BehavioLock learn your unique typing pattern\n'
                                    '• Each step takes about 30 seconds',
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Calibration prompt
                          CalibrationPromptWidget(
                            prompt: _calibrationPrompts[index],
                            currentStep: index + 1,
                            totalSteps: _calibrationPrompts.length,
                            onPromptComplete: _onPromptComplete,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Processing indicator
              if (_isProcessing)
                Container(
                  padding: const EdgeInsets.all(16),
                  child: const Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 8),
                      Text('Processing your typing pattern...'),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class BehavioralSetupIntroScreen extends StatelessWidget {
  final VoidCallback onStartCalibration;
  final VoidCallback? onSkip;

  const BehavioralSetupIntroScreen({
    super.key,
    required this.onStartCalibration,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),

              // Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.fingerprint,
                  size: 60,
                  color: Theme.of(context).primaryColor,
                ),
              ),

              const SizedBox(height: 32),

              // Title
              Text(
                'Behavioral Authentication',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Description
              Text(
                'BehavioLock learns your unique typing patterns to provide an extra layer of security. '
                'This takes just 2-3 minutes and makes your account much more secure.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Features
              Column(
                children: [
                  _FeatureItem(
                    icon: Icons.security,
                    title: 'Enhanced Security',
                    description:
                        'Detects if someone else is using your account',
                  ),
                  _FeatureItem(
                    icon: Icons.psychology,
                    title: 'Learns Your Style',
                    description:
                        'Adapts to your unique typing rhythm and speed',
                  ),
                  _FeatureItem(
                    icon: Icons.privacy_tip,
                    title: 'Privacy First',
                    description:
                        'All data stays on your device and our secure servers',
                  ),
                ],
              ),

              const Spacer(),

              // Action buttons
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onStartCalibration,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Set Up Behavioral Auth'),
                    ),
                  ),

                  if (onSkip != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: onSkip,
                        child: const Text('Skip for Now'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Theme.of(context).primaryColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
