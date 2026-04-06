import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

class MpinSetupScreen extends StatefulWidget {
  const MpinSetupScreen({super.key});

  @override
  State<MpinSetupScreen> createState() => _MpinSetupScreenState();
}

class _MpinSetupScreenState extends State<MpinSetupScreen> {
  String _mpin = '';
  String _confirmMpin = '';
  bool _isConfirming = false;
  bool _isLoading = false;

  void _onNumberTap(String num) {
    setState(() {
      if (!_isConfirming) {
        if (_mpin.length < 4) _mpin += num;
        if (_mpin.length == 4) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) setState(() => _isConfirming = true);
          });
        }
      } else {
        if (_confirmMpin.length < 4) _confirmMpin += num;
        if (_confirmMpin.length == 4) {
          _submit();
        }
      }
    });
  }

  void _onBackspace() {
    setState(() {
      if (!_isConfirming) {
        if (_mpin.isNotEmpty) _mpin = _mpin.substring(0, _mpin.length - 1);
      } else {
        if (_confirmMpin.isNotEmpty) {
          _confirmMpin = _confirmMpin.substring(0, _confirmMpin.length - 1);
        }
      }
    });
  }

  Future<void> _submit() async {
    if (_mpin != _confirmMpin) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('MPINs do not match!')));
      setState(() {
        _mpin = '';
        _confirmMpin = '';
        _isConfirming = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final api = context.read<ApiService>();
      final res = await api.post('/api/auth/mpin/setup', data: {'mpin': _mpin});
      if (!mounted) return;
      if (res['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('MPIN Setup Successfully!')),
        );

        // Force refresh user model to update hasMpin flag
        final authService = context.read<AuthService>();
        await authService.fetchCurrentUser(); // Sync with database immediately

        if (mounted) Navigator.pop(context, true);
      } else {
        throw Exception(res['message'] ?? 'Failed');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() {
        _mpin = '';
        _confirmMpin = '';
        _isConfirming = false;
        _isLoading = false;
      });
    }
  }

  Widget _buildDot(bool isFilled) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: isFilled ? Theme.of(context).primaryColor : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).primaryColor, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentText = _isConfirming ? _confirmMpin : _mpin;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: const Text('Setup MPIN'), elevation: 0),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _isConfirming
                      ? 'Confirm your 4-digit MPIN'
                      : 'Enter a 4-digit MPIN',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    4,
                    (i) => _buildDot(i < currentText.length),
                  ),
                ),
                const SizedBox(height: 60),
                _buildNumpad(),
              ],
            ),
    );
  }

  Widget _buildNumpad() {
    return Column(
      children: [
        for (int row = 0; row < 3; row++)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(3, (col) {
              final num = row * 3 + col + 1;
              return _buildNumpadButton(
                num.toString(),
                () => _onNumberTap(num.toString()),
              );
            }),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 80, height: 80),
            _buildNumpadButton('0', () => _onNumberTap('0')),
            _buildNumpadButton('⌫', _onBackspace, isIcon: true),
          ],
        ),
      ],
    );
  }

  Widget _buildNumpadButton(
    String label,
    VoidCallback onTap, {
    bool isIcon = false,
  }) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: Container(
          width: 80,
          height: 80,
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isIcon ? Colors.red : null,
            ),
          ),
        ),
      ),
    );
  }
}

class MpinVerificationModal extends StatefulWidget {
  const MpinVerificationModal({super.key});

  static Future<bool> show(BuildContext context) async {
    final result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'MPIN',
      pageBuilder: (ctx, a1, a2) => const MpinVerificationModal(),
      transitionBuilder: (ctx, a1, a2, child) {
        return SlideTransition(
          position: Tween(
            begin: const Offset(0, 1),
            end: const Offset(0, 0),
          ).animate(a1),
          child: child,
        );
      },
    );
    return result ?? false;
  }

  @override
  State<MpinVerificationModal> createState() => _MpinVerificationModalState();
}

class _MpinVerificationModalState extends State<MpinVerificationModal> {
  String _mpin = '';
  bool _isLoading = false;
  String _errorText = '';
  int _lockoutSecondsLeft = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _checkLockout();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkLockout() async {
    final prefs = await SharedPreferences.getInstance();
    final lockoutEndStr = prefs.getString('mpin_lockout_end');
    if (lockoutEndStr != null) {
      final lockoutEnd = DateTime.parse(lockoutEndStr);
      final now = DateTime.now();
      if (now.isBefore(lockoutEnd)) {
        setState(() {
          _lockoutSecondsLeft = lockoutEnd.difference(now).inSeconds;
        });
        _startTimer();
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_lockoutSecondsLeft > 0) {
        setState(() => _lockoutSecondsLeft--);
      } else {
        timer.cancel();
      }
    });
  }

  void _onNumberTap(String num) {
    if (_lockoutSecondsLeft > 0 || _isLoading) return;
    setState(() {
      _errorText = '';
      if (_mpin.length < 4) _mpin += num;
      if (_mpin.length == 4) {
        _verifyMpin();
      }
    });
  }

  void _onBackspace() {
    if (_lockoutSecondsLeft > 0 || _isLoading) return;
    setState(() {
      if (_mpin.isNotEmpty) _mpin = _mpin.substring(0, _mpin.length - 1);
    });
  }

  Future<void> _verifyMpin() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    int strikes = prefs.getInt('mpin_strikes') ?? 0;

    if (!mounted) return;
    try {
      final api = context.read<ApiService>();
      final res = await api.post(
        '/api/auth/mpin/verify',
        data: {'mpin': _mpin},
      );

      if (!mounted) return;
      if (res['status'] == 'success') {
        await prefs.setInt('mpin_strikes', 0); // Reset strikes
        if (mounted) Navigator.pop(context, true);
        return;
      }
    } catch (e) {
      strikes++;
      await prefs.setInt('mpin_strikes', strikes);

      if (strikes == 1) {
        setState(() {
          _mpin = '';
          _isLoading = false;
          _errorText = 'Incorrect MPIN. Try again.';
        });
      } else if (strikes == 2) {
        final lockEnd = DateTime.now().add(const Duration(minutes: 1));
        await prefs.setString('mpin_lockout_end', lockEnd.toIso8601String());
        setState(() {
          _mpin = '';
          _isLoading = false;
          _errorText = 'Locked out for 1 min due to failed attempts.';
          _lockoutSecondsLeft = 60;
        });
        _startTimer();
      } else if (strikes >= 3) {
        await prefs.setInt('mpin_strikes', 0); // Reset for next login
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('SECURITY BREACH. FORCE LOGOUT INITIATED.'),
            ),
          );
          final auth = context.read<AuthService>();
          await auth.signOut();
          if (!mounted) return;
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    }
  }

  Widget _buildDot(bool isFilled) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: isFilled ? Theme.of(context).primaryColor : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).primaryColor, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                children: [
                  Icon(Icons.shield, color: Colors.blueAccent),
                  SizedBox(width: 10),
                  Text(
                    'Security Verification',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              if (_lockoutSecondsLeft > 0)
                Text(
                  'LOCKED: Try again in $_lockoutSecondsLeft s',
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                )
              else
                const Text(
                  'Enter your 4-digit MPIN',
                  style: TextStyle(fontSize: 16),
                ),

              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) => _buildDot(i < _mpin.length)),
              ),
              if (_errorText.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(_errorText, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 30),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                _buildNumpad(),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel Transfer',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    return IgnorePointer(
      ignoring: _lockoutSecondsLeft > 0,
      child: Opacity(
        opacity: _lockoutSecondsLeft > 0 ? 0.3 : 1.0,
        child: Column(
          children: [
            for (int row = 0; row < 3; row++)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(3, (col) {
                  final num = row * 3 + col + 1;
                  return _buildNumpadButton(
                    num.toString(),
                    () => _onNumberTap(num.toString()),
                  );
                }),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const SizedBox(width: 60, height: 60),
                _buildNumpadButton('0', () => _onNumberTap('0')),
                _buildNumpadButton('⌫', _onBackspace, isIcon: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumpadButton(
    String label,
    VoidCallback onTap, {
    bool isIcon = false,
  }) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          width: 60,
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isIcon ? Colors.red : null,
            ),
          ),
        ),
      ),
    );
  }
}
