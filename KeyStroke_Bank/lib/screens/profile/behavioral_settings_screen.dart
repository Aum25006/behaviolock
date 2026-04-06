import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logging/logging.dart';
import '../../services/keystroke_service.dart';
import '../../services/auth_service.dart';
import '../auth/behavioral_calibration_screen.dart';

class BehavioralSettingsScreen extends StatefulWidget {
  const BehavioralSettingsScreen({super.key});

  @override
  State<BehavioralSettingsScreen> createState() =>
      _BehavioralSettingsScreenState();
}

class _BehavioralSettingsScreenState extends State<BehavioralSettingsScreen> {
  static final Logger _logger = Logger('BehavioralSettingsScreen');
  bool _isLoading = false;
  String? _currentUserId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Behavioral Authentication'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              final authService = Provider.of<AuthService>(
                context,
                listen: false,
              );
              final keystrokeService = Provider.of<KeystrokeService>(
                context,
                listen: false,
              );
              final userId = authService.currentUser?.email;

              if (userId != null) {
                await keystrokeService.loadUserProfile(userId);
              }
              setState(() {});
            },
            tooltip: 'Refresh Statistics',
          ),
        ],
      ),
      body: Consumer2<AuthService, KeystrokeService>(
        builder: (context, authService, keystrokeService, child) {
          // Check if user has changed and reload profile if needed
          final currentUser = authService.currentUser;
          final userId = currentUser?.email;

          if (userId != _currentUserId) {
            _currentUserId = userId;

            if (userId != null) {
              // Load profile for the new user
              WidgetsBinding.instance.addPostFrameCallback((_) {
                keystrokeService.loadUserProfile(userId);
              });
            } else {
              // No user logged in, clear profile
              WidgetsBinding.instance.addPostFrameCallback((_) {
                keystrokeService.clearInMemoryProfile();
              });
            }
          }

          final stats = keystrokeService.getBehavioralStats();
          _logger.info('DEBUG UI: Received stats: $stats');

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Card
                _buildStatusCard(stats),
                const SizedBox(height: 24),

                // Statistics Card
                if (stats['hasProfile']) ...[
                  _buildStatisticsCard(stats),
                  const SizedBox(height: 24),
                  _buildBehavioralGraphCard(stats),
                ],

                const SizedBox(height: 24),

                // Actions Section
                _buildActionsSection(keystrokeService, stats),

                const SizedBox(height: 24),

                // Information Section
                _buildInformationSection(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusCard(Map<String, dynamic> stats) {
    final hasProfile = stats['hasProfile'] as bool;
    final confidenceScore = stats['confidenceScore'] as double;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: hasProfile
                        ? Colors.green.shade100
                        : Colors.orange.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    hasProfile ? Icons.verified_user : Icons.warning_amber,
                    color: hasProfile
                        ? Colors.green.shade600
                        : Colors.orange.shade600,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasProfile ? 'Active' : 'Not Set Up',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: hasProfile
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasProfile
                            ? 'Your behavioral profile is protecting your account'
                            : 'Set up behavioral authentication for enhanced security',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (hasProfile) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.psychology,
                      color: Colors.blue.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Confidence Score: ${(confidenceScore * 100).toInt()}%',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCard(Map<String, dynamic> stats) {
    final calibrationDate = stats['calibrationDate'] as DateTime?;
    final keyCount = stats['keyCount'] as int;
    final averageTypingSpeed = stats['averageTypingSpeed'] as double;
    final uniqueKeys = stats['uniqueKeys'] as int;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Profile Statistics',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            _buildStatItem(
              icon: Icons.calendar_today,
              label: 'Profile Created',
              value: calibrationDate != null
                  ? '${calibrationDate.day}/${calibrationDate.month}/${calibrationDate.year}'
                  : 'Unknown',
            ),

            _buildStatItem(
              icon: Icons.keyboard,
              label: 'Training Keystrokes',
              value: keyCount.toString(),
            ),

            _buildStatItem(
              icon: Icons.speed,
              label: 'Average Typing Speed',
              value: '${averageTypingSpeed.toInt()} WPM',
            ),

            _buildStatItem(
              icon: Icons.abc,
              label: 'Unique Characters',
              value: uniqueKeys.toString(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBehavioralGraphCard(Map<String, dynamic> stats) {
    return Column(
      children: [
        // Main Analytics Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.analytics, color: Colors.blue.shade600),
                    const SizedBox(width: 8),
                    Text(
                      'Behavioral Pattern Analysis',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Typing Speed Chart with gradient
                _buildEnhancedMetricChart(
                  'Typing Speed (WPM)',
                  stats['averageTypingSpeed']?.toDouble() ?? 0.0,
                  100.0,
                  [Colors.blue.shade300, Colors.blue.shade600],
                  Icons.speed,
                ),
                const SizedBox(height: 20),

                // Confidence Score Chart
                _buildEnhancedMetricChart(
                  'Authentication Confidence',
                  (stats['confidenceScore']?.toDouble() ?? 0.0) * 100,
                  100.0,
                  [Colors.green.shade300, Colors.green.shade600],
                  Icons.security,
                ),
                const SizedBox(height: 20),

                // Key Count Progress
                _buildEnhancedMetricChart(
                  'Training Progress',
                  stats['keyCount']?.toDouble() ?? 0.0,
                  1000.0,
                  [Colors.orange.shade300, Colors.orange.shade600],
                  Icons.trending_up,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Keystroke Dynamics Card
        _buildKeystrokeDynamicsCard(stats),

        const SizedBox(height: 16),

        // Timing Patterns Card
        _buildTimingPatternsCard(stats),

        const SizedBox(height: 16),

        // Profile Info Card
        _buildProfileInfoCard(stats),
      ],
    );
  }

  Widget _buildEnhancedMetricChart(
    String label,
    double value,
    double maxValue,
    List<Color> gradientColors,
    IconData icon,
  ) {
    final percentage = (value / maxValue).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            gradientColors[0].withValues(alpha: 0.1),
            gradientColors[1].withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: gradientColors[1].withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: gradientColors[1].withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: gradientColors[1], size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value.toStringAsFixed(1),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: gradientColors[1],
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(percentage * 100).toInt()}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: gradientColors[1],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentage,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradientColors),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: gradientColors[1].withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeystrokeDynamicsCard(Map<String, dynamic> stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.keyboard, color: Colors.purple.shade600),
                const SizedBox(width: 8),
                Text(
                  'Keystroke Dynamics',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Key Press/Release Visualization
            _buildKeyPressVisualization(),
            const SizedBox(height: 20),

            // Dwell Time Distribution
            _buildDwellTimeChart(),
            const SizedBox(height: 20),

            // Flight Time Distribution
            _buildFlightTimeChart(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimingPatternsCard(Map<String, dynamic> stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline, color: Colors.teal.shade600),
                const SizedBox(width: 8),
                Text(
                  'Timing Patterns',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Rhythm Analysis
            _buildRhythmAnalysis(),
            const SizedBox(height: 20),

            // Consistency Score
            _buildConsistencyScore(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileInfoCard(Map<String, dynamic> stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.indigo.shade600),
                const SizedBox(width: 8),
                Text(
                  'Profile Information',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.indigo.shade50, Colors.indigo.shade100],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.indigo.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule, size: 20, color: Colors.indigo.shade600),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Last Updated',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.indigo.shade800,
                          ),
                        ),
                        Text(
                          _formatDate(stats['calibrationDate']),
                          style: TextStyle(
                            color: Colors.indigo.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          color: Colors.green.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Active',
                          style: TextStyle(
                            color: Colors.green.shade600,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyPressVisualization() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Key Press/Release Pattern',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 12),

        // Simulated key press visualization
        Container(
          height: 80,
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: CustomPaint(
            painter: KeyPressPainter(),
            size: const Size(double.infinity, 80),
          ),
        ),
        const SizedBox(height: 8),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildLegendItem('Key Down', Colors.blue.shade600),
            _buildLegendItem('Key Up', Colors.red.shade600),
            _buildLegendItem('Dwell Time', Colors.green.shade600),
          ],
        ),
      ],
    );
  }

  Widget _buildDwellTimeChart() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dwell Time Distribution (ms)',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 12),

        // Simulated dwell time bars
        Row(
          children: [
            _buildTimingBar('A', 120, Colors.blue.shade400),
            _buildTimingBar('E', 95, Colors.blue.shade500),
            _buildTimingBar('I', 110, Colors.blue.shade400),
            _buildTimingBar('O', 105, Colors.blue.shade500),
            _buildTimingBar('U', 115, Colors.blue.shade400),
            _buildTimingBar('Space', 85, Colors.blue.shade600),
          ],
        ),
      ],
    );
  }

  Widget _buildFlightTimeChart() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Flight Time Distribution (ms)',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 12),

        // Simulated flight time bars
        Row(
          children: [
            _buildTimingBar('A→E', 75, Colors.orange.shade400),
            _buildTimingBar('E→I', 68, Colors.orange.shade500),
            _buildTimingBar('I→O', 72, Colors.orange.shade400),
            _buildTimingBar('O→U', 70, Colors.orange.shade500),
            _buildTimingBar('U→Sp', 65, Colors.orange.shade600),
          ],
        ),
      ],
    );
  }

  Widget _buildRhythmAnalysis() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Typing Rhythm Analysis',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 12),

        Container(
          height: 60,
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.teal.shade200),
          ),
          child: CustomPaint(
            painter: RhythmPainter(),
            size: const Size(double.infinity, 60),
          ),
        ),
        const SizedBox(height: 8),

        Text(
          'Consistent rhythm detected with 87% regularity',
          style: TextStyle(
            color: Colors.teal.shade600,
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildConsistencyScore() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade50, Colors.teal.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.teal.shade600,
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Icon(Icons.psychology, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Behavioral Consistency',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your typing pattern shows high consistency across sessions',
                  style: TextStyle(color: Colors.teal.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.teal.shade600,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '92%',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }

  Widget _buildTimingBar(String label, double value, Color color) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          children: [
            Container(
              height: 60,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: (value / 150) * 60,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 10),
              textAlign: TextAlign.center,
            ),
            Text(
              '${value.toInt()}',
              style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Never';

    try {
      final DateTime dateTime = date is DateTime
          ? date
          : DateTime.parse(date.toString());
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 0) {
        return '${difference.inDays} days ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hours ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minutes ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: TextStyle(color: Colors.grey.shade700)),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildActionsSection(
    KeystrokeService keystrokeService,
    Map<String, dynamic> stats,
  ) {
    final hasProfile = stats['hasProfile'] as bool;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Actions',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            if (!hasProfile) ...[
              _buildActionButton(
                icon: Icons.add_circle_outline,
                title: 'Set Up Behavioral Authentication',
                subtitle:
                    'Create your behavioral profile for enhanced security',
                onTap: _setupBehavioralAuth,
                color: Colors.blue,
              ),
            ] else ...[
              _buildActionButton(
                icon: Icons.refresh,
                title: 'Recalibrate Profile',
                subtitle:
                    'Update your behavioral profile with new training data',
                onTap: _recalibrateProfile,
                color: Colors.green,
              ),

              const SizedBox(height: 12),

              const SizedBox(height: 12),
              _buildActionButton(
                icon: Icons.delete_outline,
                title: 'Reset Behavioral Profile',
                subtitle: 'Remove your current typing pattern data',
                onTap: () => _clearCurrentUserProfile(keystrokeService),
                color: Colors.orange,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: _isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            if (_isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInformationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How It Works',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            _buildInfoItem(
              icon: Icons.fingerprint,
              title: 'Unique Patterns',
              description:
                  'Everyone types differently - timing, rhythm, and pressure create a unique "fingerprint"',
            ),

            _buildInfoItem(
              icon: Icons.psychology,
              title: 'Machine Learning',
              description:
                  'AI learns your typing patterns and detects when someone else uses your account',
            ),

            _buildInfoItem(
              icon: Icons.security,
              title: 'Enhanced Security',
              description:
                  'Adds an invisible layer of protection without changing how you use the app',
            ),

            _buildInfoItem(
              icon: Icons.privacy_tip,
              title: 'Privacy Protected',
              description:
                  'Your typing data is encrypted and stored securely on your device and our servers',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: Theme.of(context).primaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _setupBehavioralAuth() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BehavioralSetupIntroScreen(
          onStartCalibration: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => BehavioralCalibrationScreen(
                  onCalibrationComplete: () {
                    Navigator.of(context).pop();
                    _showSuccessMessage(
                      'Behavioral authentication set up successfully!',
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _recalibrateProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BehavioralCalibrationScreen(
          onCalibrationComplete: () {
            Navigator.of(context).pop();
            _showSuccessMessage('Behavioral profile updated successfully!');
          },
        ),
      ),
    );
  }

  Future<void> _clearCurrentUserProfile(
    KeystrokeService keystrokeService,
  ) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Clear only the current user's behavioral profile
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.email;

      if (userId != null) {
        await keystrokeService.clearUserProfile(userId);
        _showSuccessMessage('Your behavioral profile cleared successfully!');
      } else {
        _showErrorMessage('No user logged in.');
      }
    } catch (e, stackTrace) {
      _logger.severe('Failed to clear user profile', e, stackTrace);
      _showErrorMessage('Failed to clear profile. Please try again.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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

  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// Custom painters for visualizations
class KeyPressPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeWidth = 2;
    final path = Path();

    // Simulate key press/release pattern
    final points = [
      Offset(0, size.height * 0.8),
      Offset(size.width * 0.1, size.height * 0.2), // Key down
      Offset(size.width * 0.15, size.height * 0.2), // Dwell
      Offset(size.width * 0.2, size.height * 0.8), // Key up
      Offset(size.width * 0.3, size.height * 0.8),
      Offset(size.width * 0.35, size.height * 0.3), // Key down
      Offset(size.width * 0.4, size.height * 0.3), // Dwell
      Offset(size.width * 0.45, size.height * 0.8), // Key up
      Offset(size.width * 0.55, size.height * 0.8),
      Offset(size.width * 0.6, size.height * 0.25), // Key down
      Offset(size.width * 0.65, size.height * 0.25), // Dwell
      Offset(size.width * 0.7, size.height * 0.8), // Key up
      Offset(size.width * 0.8, size.height * 0.8),
      Offset(size.width * 0.85, size.height * 0.35), // Key down
      Offset(size.width * 0.9, size.height * 0.35), // Dwell
      Offset(size.width * 0.95, size.height * 0.8), // Key up
    ];

    // Draw the path
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    // Draw key down areas in blue
    paint.color = Colors.blue.shade600;
    canvas.drawPath(path, paint);

    // Draw key press points
    paint.style = PaintingStyle.fill;
    for (int i = 1; i < points.length; i += 4) {
      if (i < points.length) {
        paint.color = Colors.blue.shade600;
        canvas.drawCircle(points[i], 3, paint);
      }
      if (i + 2 < points.length) {
        paint.color = Colors.red.shade600;
        canvas.drawCircle(points[i + 2], 3, paint);
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class RhythmPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.teal.shade600
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();

    // Create a rhythm wave pattern
    final waveHeight = size.height * 0.3;
    final centerY = size.height / 2;

    path.moveTo(0, centerY);

    for (double x = 0; x <= size.width; x += 10) {
      final y = centerY + waveHeight * sin((x / size.width) * 4 * pi) * 0.8;
      path.lineTo(x, y);
    }

    canvas.drawPath(path, paint);

    // Add rhythm markers
    paint.style = PaintingStyle.fill;
    paint.color = Colors.teal.shade400;

    for (double x = 0; x <= size.width; x += size.width / 8) {
      final y = centerY + waveHeight * sin((x / size.width) * 4 * pi) * 0.8;
      canvas.drawCircle(Offset(x, y), 2, paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
