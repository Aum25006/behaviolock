import 'package:flutter/material.dart';
import 'dart:math';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import '../../models/bank_account_model.dart';
import '../../services/bank_account_service.dart';
import '../../services/auth_service.dart';

final _logger = Logger('AddAccountScreen');

final Map<String, String> bankIfscPrefixes = {
  'State Bank of India': 'SBIN',
  'HDFC Bank': 'HDFC',
  'ICICI Bank': 'ICIC',
  'Punjab National Bank': 'PUNB',
  'Axis Bank': 'UTIB',
  'Kotak Mahindra Bank': 'KKBK',
  'Bank of Baroda': 'BARB',
  'IndusInd Bank': 'INDB',
  'IDBI Bank': 'IBKL',
  'Yes Bank': 'YESB',
};

final List<String> popularIndianBanks = bankIfscPrefixes.keys.toList();

class AddAccountScreen extends StatefulWidget {
  const AddAccountScreen({super.key});

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accountHolderNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _ifscCodeController = TextEditingController();
  final _confirmAccountNumberController = TextEditingController();

  String _selectedBank = popularIndianBanks.first;
  AccountType _selectedAccountType = AccountType.savings;
  bool _isPrimary = true;
  bool _isLoading = false;
  String? _error;

  late final BankAccountService _bankAccountService;
  late final AuthService _authService;
  final Random _random = Random();
  String? _authToken;

  @override
  void initState() {
    super.initState();
    // Initialize the form fields
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bankAccountService = Provider.of<BankAccountService>(
        context,
        listen: false,
      );
      _authService = Provider.of<AuthService>(context, listen: false);
      _authToken = _authService.token;
      _initializeForm();
    });
  }

  // Generate a random account number
  String _generateAccountNumber() {
    return '9${_random.nextInt(9)}${_random.nextInt(9)}${_random.nextInt(9)}${_random.nextInt(9)}${_random.nextInt(9)}${_random.nextInt(9)}${_random.nextInt(9)}${_random.nextInt(9)}${_random.nextInt(9)}${_random.nextInt(9)}${_random.nextInt(9)}${_random.nextInt(9)}';
  }

  // Generate IFSC code based on bank
  String _generateIfscCode(String bankName) {
    final prefix = bankIfscPrefixes[bankName] ?? 'BANK';
    final branchCode = _random.nextInt(100000).toString().padLeft(6, '0');
    return '${prefix}0$branchCode';
  }

  // Update form fields when bank or account type changes
  void _updateFormFields() {
    // Generate new account number and IFSC code
    final newAccountNumber = _generateAccountNumber();
    final newIfscCode = _generateIfscCode(_selectedBank);

    setState(() {
      _accountNumberController.text = newAccountNumber;
      _confirmAccountNumberController.text = newAccountNumber;
      _ifscCodeController.text = newIfscCode;
    });
  }

  Future<void> _initializeForm() async {
    if (_authToken == null) {
      setState(() {
        _error = 'Authentication required. Please log in again.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Initialize the service
      await _bankAccountService.initialize();
      // Update form fields with generated values
      _updateFormFields();
    } catch (e) {
      setState(() {
        _error = 'Failed to initialize: ${e.toString()}';
      });
      _logger.severe('Error initializing form', e);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _accountHolderNameController.dispose();
    _accountNumberController.dispose();
    _ifscCodeController.dispose();
    _confirmAccountNumberController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_authToken == null) {
      setState(() {
        _error = 'Authentication required. Please log in again.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get current user info
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
          _error = 'User not authenticated. Please log in again.';
        });
        return;
      }

      // Create a new bank account
      final newAccount = BankAccount(
        id: '', // Will be set by the backend
        userId: user.id,
        accountNumber: _accountNumberController.text.trim(),
        accountHolderName: _accountHolderNameController.text.trim(),
        email: user.email,
        bankName: _selectedBank,
        ifscCode: _ifscCodeController.text.trim(),
        accountType: _selectedAccountType,
        isPrimary: _isPrimary,
        balance: 0.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Add the account using the service
      final success = await _bankAccountService.addAccount(newAccount);

      if (success && mounted) {
        // Show success message and pop back
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account added successfully')),
        );
        Navigator.of(context).pop(true); // Return success
      } else if (mounted) {
        // Show error message if not successful
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_bankAccountService.error ?? 'Failed to add account'),
          ),
        );
      }
    } catch (e) {
      _logger.severe('Error adding account', e);
      if (mounted) {
        setState(() {
          _error = 'An error occurred: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Bank Account')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _accountHolderNameController,
                decoration: const InputDecoration(
                  labelText: 'Account Holder Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter account holder name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _accountNumberController,
                decoration: const InputDecoration(
                  labelText: 'Account Number',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter account number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmAccountNumberController,
                decoration: const InputDecoration(
                  labelText: 'Confirm Account Number',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm account number';
                  }
                  if (value != _accountNumberController.text) {
                    return 'Account numbers do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ifscCodeController,
                decoration: const InputDecoration(
                  labelText: 'IFSC Code',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter IFSC code';
                  }
                  // Basic IFSC code validation (4 letters + 7 digits)
                  if (!RegExp(
                    r'^[A-Za-z]{4}0[A-Za-z0-9]{6}$',
                  ).hasMatch(value)) {
                    return 'Please enter a valid IFSC code';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedBank,
                decoration: const InputDecoration(
                  labelText: 'Bank Name',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                dropdownColor: Colors.white,
                style: const TextStyle(color: Colors.black),
                items: popularIndianBanks.map((String bank) {
                  return DropdownMenuItem<String>(
                    value: bank,
                    child: Text(
                      bank,
                      style: const TextStyle(color: Colors.black),
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedBank = newValue;
                    });
                    _updateFormFields();
                  }
                },
                isExpanded: true,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<AccountType>(
                initialValue: _selectedAccountType,
                decoration: const InputDecoration(
                  labelText: 'Account Type',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                dropdownColor: Colors.white,
                style: const TextStyle(color: Colors.black),
                items: AccountType.values.map((AccountType type) {
                  return DropdownMenuItem<AccountType>(
                    value: type,
                    child: Text(
                      type.toString().split('.').last,
                      style: const TextStyle(color: Colors.black),
                    ),
                  );
                }).toList(),
                onChanged: (AccountType? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedAccountType = newValue;
                    });
                    _updateFormFields();
                  }
                },
                isExpanded: true,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: _isPrimary,
                    onChanged: (bool? value) {
                      if (value != null) {
                        setState(() {
                          _isPrimary = value;
                        });
                      }
                    },
                  ),
                  const Text('Set as Primary Account'),
                ],
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Text(
                  _error!,
                  style: const TextStyle(
                    color: Color.fromARGB(255, 11, 11, 11),
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Add Account',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
              if (MediaQuery.of(context).viewInsets.bottom > 0)
                SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
            ],
          ),
        ),
      ),
    );
  }
}
