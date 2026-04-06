import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/keystroke_service.dart';

class BehavioralTextField extends StatefulWidget {
  final TextEditingController controller;
  final String? labelText;
  final String? hintText;
  final bool obscureText;
  final TextInputType keyboardType;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function()? onEditingComplete;
  final bool autofocus;
  final int? maxLines;
  final bool enableKeystrokeCapture;
  final void Function(List<KeystrokeData>)? onKeystrokeSession;

  const BehavioralTextField({
    super.key,
    required this.controller,
    this.labelText,
    this.hintText,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.onChanged,
    this.onEditingComplete,
    this.autofocus = false,
    this.maxLines = 1,
    this.enableKeystrokeCapture = true,
    this.onKeystrokeSession,
  });

  @override
  State<BehavioralTextField> createState() => _BehavioralTextFieldState();
}

class _BehavioralTextFieldState extends State<BehavioralTextField> {
  final FocusNode _focusNode = FocusNode();
  KeystrokeService? _keystrokeService;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!widget.enableKeystrokeCapture) return;

    _keystrokeService ??= Provider.of<KeystrokeService>(context, listen: false);

    if (_focusNode.hasFocus && !_isCapturing) {
      // Start keystroke capture when field gains focus
      _keystrokeService!.startCapture();
      _isCapturing = true;
    } else if (!_focusNode.hasFocus && _isCapturing) {
      // Stop keystroke capture when field loses focus
      final session = _keystrokeService!.stopCapture();
      _isCapturing = false;
      
      // Notify parent widget of keystroke session
      if (widget.onKeystrokeSession != null && session.isNotEmpty) {
        widget.onKeystrokeSession!(session);
      }
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!widget.enableKeystrokeCapture || _keystrokeService == null) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey.keyLabel;
    
    if (event is KeyDownEvent) {
      _keystrokeService!.onKeyPress(key);
    } else if (event is KeyUpEvent) {
      _keystrokeService!.onKeyRelease(key);
    }

    return KeyEventResult.ignored; // Allow normal text input processing
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: _handleKeyEvent,
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        validator: widget.validator,
        onChanged: widget.onChanged,
        onEditingComplete: widget.onEditingComplete,
        autofocus: widget.autofocus,
        maxLines: widget.maxLines,
        decoration: InputDecoration(
          labelText: widget.labelText,
          hintText: widget.hintText,
          prefixIcon: widget.prefixIcon,
          suffixIcon: widget.suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.grey.shade300,
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).primaryColor,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Colors.red,
              width: 1,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Colors.red,
              width: 2,
            ),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}

class BehavioralPasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String? labelText;
  final String? hintText;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function()? onEditingComplete;
  final bool autofocus;
  final bool enableKeystrokeCapture;
  final void Function(List<KeystrokeData>)? onKeystrokeSession;

  const BehavioralPasswordField({
    super.key,
    required this.controller,
    this.labelText,
    this.hintText,
    this.validator,
    this.onChanged,
    this.onEditingComplete,
    this.autofocus = false,
    this.enableKeystrokeCapture = true,
    this.onKeystrokeSession,
  });

  @override
  State<BehavioralPasswordField> createState() => _BehavioralPasswordFieldState();
}

class _BehavioralPasswordFieldState extends State<BehavioralPasswordField> {
  bool _obscureText = true;

  void _togglePasswordVisibility() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BehavioralTextField(
      controller: widget.controller,
      labelText: widget.labelText,
      hintText: widget.hintText,
      obscureText: _obscureText,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onEditingComplete: widget.onEditingComplete,
      autofocus: widget.autofocus,
      enableKeystrokeCapture: widget.enableKeystrokeCapture,
      onKeystrokeSession: widget.onKeystrokeSession,
      prefixIcon: const Icon(Icons.lock_outline),
      suffixIcon: IconButton(
        icon: Icon(
          _obscureText ? Icons.visibility : Icons.visibility_off,
          color: Colors.grey.shade600,
        ),
        onPressed: _togglePasswordVisibility,
      ),
    );
  }
}

class CalibrationPromptWidget extends StatefulWidget {
  final String prompt;
  final int currentStep;
  final int totalSteps;
  final void Function(List<KeystrokeData>) onPromptComplete;
  final VoidCallback? onSkip;

  const CalibrationPromptWidget({
    super.key,
    required this.prompt,
    required this.currentStep,
    required this.totalSteps,
    required this.onPromptComplete,
    this.onSkip,
  });

  @override
  State<CalibrationPromptWidget> createState() => _CalibrationPromptWidgetState();
}

class _CalibrationPromptWidgetState extends State<CalibrationPromptWidget> {
  final TextEditingController _controller = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isCompleted = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onKeystrokeSession(List<KeystrokeData> session) {
    if (_isCompleted || session.isEmpty) return;

    // Check if user has typed the complete prompt
    if (_controller.text.trim().toLowerCase() == widget.prompt.trim().toLowerCase()) {
      setState(() {
        _isCompleted = true;
      });
      
      // Delay slightly to ensure all keystrokes are captured
      Future.delayed(const Duration(milliseconds: 100), () {
        widget.onPromptComplete(session);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Progress indicator
              Row(
                children: [
                  Text(
                    'Calibration Step ${widget.currentStep}/${widget.totalSteps}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const Spacer(),
                  CircularProgressIndicator(
                    value: widget.currentStep / widget.totalSteps,
                    backgroundColor: Colors.grey.shade300,
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Instructions
              Text(
                'Please type the following text exactly as shown:',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              
              const SizedBox(height: 16),
              
              // Prompt text
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  widget.prompt,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Input field
              BehavioralTextField(
                controller: _controller,
                labelText: 'Type here',
                hintText: 'Start typing the text above...',
                maxLines: 3,
                autofocus: true,
                onKeystrokeSession: _onKeystrokeSession,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please type the prompt text';
                  }
                  if (value.trim().toLowerCase() != widget.prompt.trim().toLowerCase()) {
                    return 'Text must match the prompt exactly';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 24),
              
              // Action buttons
              Row(
                children: [
                  if (widget.onSkip != null)
                    TextButton(
                      onPressed: _isCompleted ? null : widget.onSkip,
                      child: const Text('Skip'),
                    ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _isCompleted ? null : () {
                      if (_formKey.currentState?.validate() ?? false) {
                        // Validation passed, keystroke session will be handled automatically
                      }
                    },
                    child: _isCompleted 
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check, size: 18),
                              SizedBox(width: 8),
                              Text('Completed'),
                            ],
                          )
                        : const Text('Validate'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
