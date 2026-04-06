import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../services/transaction_service.dart';
import '../../../services/bank_account_service.dart';
import '../../../services/api_service.dart';
import '../../../models/bank_account_model.dart';
import '../../../services/auth_service.dart';
import '../auth/mpin_screens.dart';

class EnhancedTransferScreen extends StatefulWidget {
  const EnhancedTransferScreen({super.key});

  @override
  State<EnhancedTransferScreen> createState() => _EnhancedTransferScreenState();
}

class _EnhancedTransferScreenState extends State<EnhancedTransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _searchController = TextEditingController();

  int _currentStep = 0;
  bool _isLoading = false;
  String? _error;

  // Form data
  BankAccount? _selectedFromAccount;
  Map<String, dynamic>? _selectedRecipient;
  BankAccount? _selectedRecipientAccount;

  // Data lists
  List<BankAccount> _userAccounts = [];
  List<Map<String, dynamic>> _recipients = [];
  List<Map<String, dynamic>> _filteredRecipients = [];
  List<BankAccount> _recipientAccounts = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() => _isLoading = true);

      // Load user accounts
      final bankAccountService = context.read<BankAccountService>();
      await bankAccountService.initialize();

      if (mounted) {
        setState(() {
          _userAccounts = bankAccountService.accounts;
          if (_userAccounts.isNotEmpty) {
            _selectedFromAccount = _userAccounts.first;
          }
        });
      }

      // Load initial recipients list
      await _loadRecipients();
    } catch (e) {
      setState(() => _error = 'Failed to load data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadRecipients() async {
    try {
      setState(() => _isLoading = true);

      final apiService = context.read<ApiService>();
      final response = await apiService.get('/api/users');

      if (response['status'] == 'success' && mounted) {
        final List<dynamic> users = response['data'] ?? [];
        setState(() {
          _recipients = users.map<Map<String, dynamic>>((user) {
            return {
              'id': user['id'],
              'name': '${user['firstName']} ${user['lastName']}',
              'email': user['email'],
            };
          }).toList();
          _filteredRecipients = List.from(_recipients);
        });
      }
    } catch (e) {
      setState(() => _error = 'Failed to load recipients: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ... (rest of the implementation will be in the next part)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Transfer'), elevation: 0),
      body: _isLoading && _userAccounts.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : Stepper(
              currentStep: _currentStep,
              onStepContinue: _onStepContinue,
              onStepCancel: _onStepCancel,
              onStepTapped: _onStepTapped,
              controlsBuilder: _buildStepControls,
              steps: _buildSteps(),
            ),
    );
  }

  List<Step> _buildSteps() {
    return [
      Step(
        title: const Text('From Account'),
        content: _buildFromAccountStep(),
        isActive: _currentStep >= 0,
        state: _currentStep > 0 ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: const Text('To Recipient'),
        content: _buildRecipientStep(),
        isActive: _currentStep >= 1,
        state: _currentStep > 1 ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: const Text('Amount & Details'),
        content: _buildAmountStep(),
        isActive: _currentStep >= 2,
        state: _currentStep > 2 ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: const Text('Confirm'),
        content: _buildConfirmationStep(),
        isActive: _currentStep >= 3,
      ),
    ];
  }

  Widget _buildFromAccountStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Select account to transfer from:',
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 16),
        RadioGroup<BankAccount>(
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedFromAccount = value);
            }
          },
          child: Column(
            children: _userAccounts.map((account) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: RadioListTile<BankAccount>(
                  title: Text(
                    '${account.accountType.toString().split('.').last} ••••${account.accountNumber.substring(account.accountNumber.length - 4)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Balance: ₹${account.balance.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  value: account,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildRecipientStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            labelText: 'Search recipient',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onChanged: _onSearchChanged,
        ),
        const SizedBox(height: 16),
        _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _filteredRecipients.isEmpty
            ? const Center(child: Text('No recipients found'))
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredRecipients.length,
                itemBuilder: (context, index) {
                  final recipient = _filteredRecipients[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(recipient['name'][0].toUpperCase()),
                      ),
                      title: Text(recipient['name']),
                      subtitle: Text(recipient['email']),
                      onTap: () async {
                        setState(() => _selectedRecipient = recipient);
                        await _loadRecipientAccounts(recipient['id']);
                        if (_recipientAccounts.isNotEmpty) {
                          setState(() {
                            _selectedRecipientAccount =
                                _recipientAccounts.first;
                            _currentStep = 2; // Move to next step
                          });
                        }
                      },
                    ),
                  );
                },
              ),
      ],
    );
  }

  Widget _buildAmountStep() {
    debugPrint('\n=== _buildAmountStep() ===');
    debugPrint('Recipient Accounts Count: ${_recipientAccounts.length}');
    debugPrint('Selected Account ID: ${_selectedRecipientAccount?.id}');

    // Log all recipient accounts for debugging
    for (var account in _recipientAccounts) {
      debugPrint(
        'Recipient Account: ${account.id} - ${account.accountNumber} (${account.accountType})',
      );
    }

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Recipient Account:', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          _recipientAccounts.isEmpty
              ? const Text(
                  'No recipient accounts available',
                  style: TextStyle(color: Colors.grey),
                )
              : _buildAccountDropdown(),

          const SizedBox(height: 16),

          const Text('Amount:', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Enter amount',
              prefixText: '₹ ',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter an amount';
              }
              final amount = double.tryParse(value);
              if (amount == null) {
                return 'Please enter a valid number';
              }
              if (amount <= 0) {
                return 'Amount must be greater than zero';
              }
              if (_selectedFromAccount != null &&
                  amount > _selectedFromAccount!.balance) {
                return 'Insufficient funds';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          const Text('Note (optional):', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _noteController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Add a note for this transfer',
            ),
            maxLines: 2,
          ),

          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: _submitTransfer,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Transfer'),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountDropdown() {
    // Create a local copy of the accounts list to ensure we're working with the latest data
    final accounts = List<BankAccount>.from(_recipientAccounts);

    // Debug logging
    debugPrint('Building dropdown with ${accounts.length} accounts');
    if (_selectedRecipientAccount != null) {
      debugPrint('Selected account ID: ${_selectedRecipientAccount!.id}');
    }

    // Find the index of the currently selected account in the accounts list
    int? selectedIndex;
    if (_selectedRecipientAccount != null) {
      selectedIndex = accounts.indexWhere(
        (a) => a.id == _selectedRecipientAccount!.id,
      );
      debugPrint('Found selected account at index: $selectedIndex');

      // If the selected account is not in the list, select the first one
      if (selectedIndex == -1 && accounts.isNotEmpty) {
        debugPrint(
          'Selected account not found in list, selecting first account',
        );
        selectedIndex = 0;
        _selectedRecipientAccount = accounts.first;
      }
    }

    // If no selection and we have accounts, select the first one
    if ((_selectedRecipientAccount == null || selectedIndex == -1) &&
        accounts.isNotEmpty) {
      debugPrint('No valid selection, selecting first account');
      _selectedRecipientAccount = accounts.first;
      selectedIndex = 0;
    }

    // If we still don't have a valid selection, return a disabled dropdown
    if (accounts.isEmpty) {
      return const Text(
        'No accounts available',
        style: TextStyle(color: Colors.grey),
      );
    }

    return DropdownButtonHideUnderline(
      child: ButtonTheme(
        alignedDropdown: true,
        child: DropdownButtonFormField<BankAccount>(
          isExpanded: true,
          initialValue: _selectedRecipientAccount,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            hintText: 'Select an account',
          ),
          items: accounts.map<DropdownMenuItem<BankAccount>>((account) {
            final displayText =
                '${account.accountType.toString().split('.').last} ••••${account.accountNumber.substring(account.accountNumber.length - 4)}';
            return DropdownMenuItem<BankAccount>(
              value: account,
              key: ValueKey<String>('account_${account.id}'),
              child: Text(displayText, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (BankAccount? newValue) {
            if (newValue != null) {
              debugPrint('Account selected: ${newValue.id}');
              setState(() {
                _selectedRecipientAccount = newValue;
              });
            }
          },
          // Use a custom validator that always returns null (we handle validation elsewhere)
          validator: (value) => null,
          // Ensure we're using the correct equality comparison
          selectedItemBuilder: (BuildContext context) {
            return accounts.map<Widget>((BankAccount account) {
              final displayText =
                  '${account.accountType.toString().split('.').last} ••••${account.accountNumber.substring(account.accountNumber.length - 4)}';
              return Text(displayText, overflow: TextOverflow.ellipsis);
            }).toList();
          },
        ),
      ),
    );
  }

  Widget _buildConfirmationRow(
    String label,
    String value, {
    bool isBold = false,
    bool isSecondary = false,
    Color? textColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isSecondary ? Colors.grey[600] : null,
              fontSize: isSecondary ? 14 : 16,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: textColor ?? (isSecondary ? Colors.grey[600] : null),
              fontSize: isSecondary ? 14 : 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationStep() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final fee = 0.0; // You can calculate a fee here if needed
    final total = amount + fee;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Review Transfer Details',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // From Account
          _buildConfirmationRow(
            'From Account:',
            '${_selectedFromAccount?.accountType.toString().split('.').last} ••••${_selectedFromAccount?.accountNumber.substring(_selectedFromAccount!.accountNumber.length - 4)}',
            isBold: true,
          ),
          _buildConfirmationRow(
            '',
            'Balance: ₹${_selectedFromAccount?.balance.toStringAsFixed(2)}',
            isSecondary: true,
          ),

          const Divider(height: 32, thickness: 1),

          // To Recipient
          _buildConfirmationRow(
            'To:',
            _selectedRecipient?['name'] ?? '',
            isBold: true,
          ),
          _buildConfirmationRow(
            '',
            _selectedRecipient?['email'] ?? '',
            isSecondary: true,
          ),
          if (_selectedRecipientAccount != null) ...[
            _buildConfirmationRow(
              '',
              '${_selectedRecipientAccount!.accountType.toString().split('.').last} ••••${_selectedRecipientAccount!.accountNumber.substring(_selectedRecipientAccount!.accountNumber.length - 4)}',
              isSecondary: true,
            ),
          ],

          const Divider(height: 32, thickness: 1),

          // Amount and Fee
          _buildConfirmationRow('Amount:', '₹${amount.toStringAsFixed(2)}'),
          if (fee > 0)
            _buildConfirmationRow('Fee:', '₹${fee.toStringAsFixed(2)}'),
          _buildConfirmationRow(
            'Total:',
            '₹${total.toStringAsFixed(2)}',
            isBold: true,
            textColor: Theme.of(context).primaryColor,
          ),

          if (_noteController.text.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildConfirmationRow(
              'Note:',
              _noteController.text,
              isSecondary: true,
            ),
          ],

          const SizedBox(height: 32),

          ElevatedButton(
            onPressed: _submitTransfer,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Confirm Transfer'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _currentStep--;
              });
            },
            child: const Text('Back'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadRecipientAccounts(String userId) async {
    if (!mounted) return;

    try {
      setState(() => _isLoading = true);

      final apiService = context.read<ApiService>();
      final response = await apiService.get('/api/users/$userId/accounts');

      debugPrint('Loading recipient accounts for user: $userId');

      if (response['status'] == 'success' && mounted) {
        final List<dynamic> accounts = response['data'] ?? [];
        final uniqueAccounts = <String, BankAccount>{};

        debugPrint('Received ${accounts.length} accounts from API');

        // Ensure unique accounts by account number
        for (var account in accounts) {
          try {
            final bankAccount = BankAccount.fromMap(account);
            uniqueAccounts[bankAccount.accountNumber] = bankAccount;
          } catch (e) {
            debugPrint('Error parsing account: $e');
          }
        }

        final newRecipientAccounts = uniqueAccounts.values.toList();
        debugPrint('Parsed ${newRecipientAccounts.length} valid accounts');

        setState(() {
          _recipientAccounts = newRecipientAccounts;

          if (newRecipientAccounts.isNotEmpty) {
            // If we have a selected account, try to find it in the new list
            if (_selectedRecipientAccount != null) {
              final existingAccountIndex = newRecipientAccounts.indexWhere(
                (a) => a.id == _selectedRecipientAccount!.id,
              );

              if (existingAccountIndex != -1) {
                // Found the existing selected account in the new list
                _selectedRecipientAccount =
                    newRecipientAccounts[existingAccountIndex];
                debugPrint(
                  'Maintained selection of account: ${_selectedRecipientAccount!.id}',
                );
              } else {
                // Selected account not found, select the first one
                _selectedRecipientAccount = newRecipientAccounts.first;
                debugPrint(
                  'Selected account not found, defaulting to first account: ${_selectedRecipientAccount!.id}',
                );
              }
            } else {
              // If no account was selected, select the first one
              _selectedRecipientAccount = newRecipientAccounts.first;
              debugPrint(
                'No previous selection, defaulting to first account: ${_selectedRecipientAccount!.id}',
              );
            }
          } else {
            _selectedRecipientAccount = null;
            debugPrint('No accounts available for selection');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load recipient accounts: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _filteredRecipients = _recipients.where((recipient) {
        final name = recipient['name'].toLowerCase();
        final email = recipient['email'].toLowerCase();
        final searchLower = query.toLowerCase();
        return name.contains(searchLower) || email.contains(searchLower);
      }).toList();
    });
  }

  Future<void> _submitTransfer() async {
    if (!_formKey.currentState!.validate()) return;

    // ======== SECURITY INTERCEPT ========
    final authService = context.read<AuthService>();
    await authService
        .fetchCurrentUser(); // Ask the database! Stop using local cache!
    final user = authService.currentUser;
    if (user != null && !user.hasMpin) {
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
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MpinSetupScreen()),
        );
      }
      return;
    }

    // Prompt the 3-Strike MPIN Pad
    final isVerified = await MpinVerificationModal.show(context);
    if (!isVerified) return; // Halt transaction gracefully
    // =====================================

    try {
      setState(() => _isLoading = true);

      final transactionService = context.read<TransactionService>();
      final amount = double.parse(_amountController.text);

      // Create transaction
      await transactionService.createTransfer(
        fromAccountId: _selectedFromAccount!.id,
        toAccountId: _selectedRecipientAccount!.id,
        amount: amount,
        description: _noteController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Transfer successful!')));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Transfer failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onStepContinue() {
    if (_currentStep == 0 && _selectedFromAccount == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select an account')));
      return;
    }

    if (_currentStep == 1 && _selectedRecipient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a recipient')),
      );
      return;
    }

    if (_currentStep == 2) {
      if (!_formKey.currentState!.validate()) return;
    }

    if (_currentStep < 3) {
      setState(() => _currentStep += 1);
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep -= 1);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _onStepTapped(int step) {
    if (step < _currentStep) {
      setState(() => _currentStep = step);
    }
  }

  Widget _buildStepControls(BuildContext context, ControlsDetails details) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            OutlinedButton(
              onPressed: details.onStepCancel,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Back'),
            )
          else
            const SizedBox(width: 80),

          if (_currentStep < 3)
            ElevatedButton(
              onPressed: details.onStepContinue,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Continue'),
            )
          else
            const SizedBox(width: 80),
        ],
      ),
    );
  }
}
