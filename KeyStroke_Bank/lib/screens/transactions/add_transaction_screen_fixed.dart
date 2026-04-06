import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:logging/logging.dart';
import '../../services/profile_service.dart';

import '../../../models/transaction_model.dart';
import '../../../models/bank_account_model.dart';
import '../../../models/card_model.dart';
import '../../../services/transaction_service.dart';
import '../../../services/bank_account_service.dart';
import '../../../services/card_service.dart';
import '../../../theme/app_colors.dart';
import '../../../services/auth_service.dart';
import '../../../services/api_service.dart';
import '../../../screens/profile/add_card_screen.dart';

class AddTransactionScreen extends StatefulWidget {
  final String? accountId;
  final TransactionType? initialTransactionType;
  final String? preselectedRecipientId;
  final String? preselectedRecipientAccountId;

  const AddTransactionScreen({
    super.key, 
    this.accountId, 
    this.initialTransactionType,
    this.preselectedRecipientId,
    this.preselectedRecipientAccountId,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}



class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  int _selectedPaymentMethod = 0;

  // Recipient selection (for transfers)
  String? _selectedRecipientUserId;
  String? _selectedRecipientAccountId;
  List<Map<String, String>> _recipientUsers = [];
  List<BankAccount> _recipientAccounts = [];
  bool _loadingRecipients = false;
  bool _loadingRecipientAccounts = false;
  
  // User cards for payment methods
  List<CardModel> _userCards = [];
  
  bool isLoading = true;
  bool isSubmitting = false;
  String? _selectedAccountId;
  List<BankAccount> accounts = [];
  final _logger = Logger('AddTransactionScreen');
  
  static const List<Map<String, dynamic>> _transactionTypes = [
    {
      'type': TransactionType.withdrawal,
      'label': 'Withdraw',
      'icon': Icons.arrow_upward_rounded,
      'color': Colors.red,
    },
    {
      'type': TransactionType.deposit,
      'label': 'Deposit',
      'icon': Icons.arrow_downward_rounded,
      'color': Colors.green,
    },
    {
      'type': TransactionType.transfer,
      'label': 'Transfer',
      'icon': Icons.swap_horiz_rounded,
      'color': Colors.blue,
    },
    {
      'type': TransactionType.payment,
      'label': 'Payment',
      'icon': Icons.payment_rounded,
      'color': Colors.purple,
    },
  ];

  TransactionType selectedTransactionType = TransactionType.withdrawal;

  @override
  void initState() {
    super.initState();
    // Set initial transaction type if provided
    if (widget.initialTransactionType != null) {
      selectedTransactionType = widget.initialTransactionType!;
    }

    // Prefill email from authenticated user
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthService>(context, listen: false);
      _emailController.text = auth.currentUser?.email ?? '';
    });
    _loadAccounts();
    _loadUserCards();
  }

  Future<void> _loadAccounts() async {
    try {
      // First check if user is authenticated
      final authService = Provider.of<AuthService>(context, listen: false);
      if (!authService.isAuthenticated) {
        _logger.warning('User not authenticated, cannot load accounts');
        setState(() => isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please log in to access your accounts'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      _logger.info('User authenticated, loading accounts...');
      final accountService = Provider.of<BankAccountService>(context, listen: false);
      
      await accountService.initialize();
      
      if (mounted) {
        setState(() {
          accounts = accountService.accounts.toSet().toList();
          // No dummy accounts; show selector only when accounts exist
          
          if (widget.accountId != null && accounts.any((a) => a.id == widget.accountId)) {
            _selectedAccountId = widget.accountId;
          } else if (accounts.isNotEmpty) {
            _selectedAccountId = accounts.first.id;
          }
          isLoading = false;
        });
      }
    } catch (e) {
      _logger.severe('Error loading accounts: $e');
      setState(() => isLoading = false);
      if (mounted) {
        // Show a more helpful error message based on the error type
        String errorMessage = 'Failed to load accounts';
        String errorDetails = e.toString();
        
        if (errorDetails.contains('401') || errorDetails.contains('Unauthorized')) {
          errorMessage = 'Authentication required. Please log in again.';
        } else if (errorDetails.contains('network') || errorDetails.contains('connection')) {
          errorMessage = 'Network error. Please check your connection.';
        } else if (errorDetails.contains('timeout')) {
          errorMessage = 'Request timed out. Please try again.';
        } else if (errorDetails.contains('500') || errorDetails.contains('Internal Server Error')) {
          errorMessage = 'Server error. Please try again later.';
        } else {
          errorMessage = 'Failed to load accounts: ${e.toString()}';
        }
        
        _logger.warning('Showing error to user: $errorMessage');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () {
                _loadAccounts();
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadUserCards() async {
    try {
      final cardService = Provider.of<CardService>(context, listen: false);
      await cardService.initialize();
      
      if (mounted) {
        setState(() {
          _userCards = cardService.cards.toList();
        });
      }
    } catch (e) {
      _logger.severe('Failed to load user cards', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load cards: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _recipientController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    if (isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            'New Transaction',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.black,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary card removed as per request
                  _buildDetailsSection(theme),
                  const SizedBox(height: 16),
                  _buildEmailRow(theme),
                  const SizedBox(height: 16),
                  _buildPaymentMethods(theme),
                  const SizedBox(height: 24),
                  // Account Selector
                  Text(
                    'From Account',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildAccountSelector(theme, size),

                  const SizedBox(height: 24),

                  // Transaction Type Selector
                  _buildTypeSelector(theme),

                  const SizedBox(height: 24),

                  // Recipient Field
                  if (selectedTransactionType == TransactionType.transfer) ...[
                    _buildRecipientUserDropdown(theme),
                    const SizedBox(height: 12),
                    _buildRecipientAccountDropdown(theme),
                    const SizedBox(height: 12),
                  ] else if (selectedTransactionType == TransactionType.payment) ...[
                    _buildRecipientField(theme),
                    const SizedBox(height: 12),
                  ],

                  const SizedBox(height: 20),

                  // Amount Field
                  _buildAmountField(theme),

                  const SizedBox(height: 20),

                  // Description Field
                  _buildDescriptionField(theme),

                  const SizedBox(height: 32),

                  // Submit Button
                  _buildSubmitButton(theme),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    // Ask for 6-digit MPIN before any transaction
    final profile = context.read<ProfileService>();
    final ok = await profile.requireMpin(context);
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('MPIN verification required')),
        );
      }
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSubmitting = true);

    try {
      final now = DateTime.now();
      final transaction = TransactionModel(
        id: const Uuid().v4(),
        accountId: _selectedAccountId!,
        type: selectedTransactionType,
        amount: double.parse(_amountController.text),
        description: _descriptionController.text,
        date: now,
        createdAt: now,
        updatedAt: now,
        recipientAccountId: selectedTransactionType == TransactionType.transfer
            ? (_selectedRecipientAccountId ?? '')
            : (_recipientController.text.isNotEmpty ? _recipientController.text : ''),
        status: 'completed',
      );

      if (mounted) {
        final transactionService = Provider.of<TransactionService>(
          context,
          listen: false,
        );
        await transactionService.addTransaction(transaction);
      }

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Transaction completed successfully!'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );

        // Navigate back after a short delay
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      _logger.severe('Error submitting transaction: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to submit transaction. Please try again.'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  Widget _buildTypeSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transaction Type',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _transactionTypes.map((type) {
            final isSelected = selectedTransactionType == type['type'];
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() {
                  selectedTransactionType = type['type'] as TransactionType;
                  if (selectedTransactionType == TransactionType.transfer) {
                    _fetchRecipientUsers();
                  }
                }),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? type['color'].withAlpha(30) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? type['color'] : Colors.grey.shade300,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        type['icon'],
                        color: isSelected ? type['color'] : Colors.grey,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        type['label'],
                        style: TextStyle(
                          color: isSelected ? type['color'] : Colors.grey,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAccountSelector(ThemeData theme, Size size) {
    if (accounts.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('From Account', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: theme.hintColor)),
            const SizedBox(height: 8),
            Text('No accounts found for your user. Add one from Dashboard → My Accounts → Add Account.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
          ],
        ),
      );
    }

    final selectedAccount = accounts.firstWhere(
      (a) => a.id == _selectedAccountId,
      orElse: () => accounts.first,
    );

    return GestureDetector(
      onTap: () => _showAccountSelection(theme, size),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(12),
          color: theme.cardColor,
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha((255 * 0.1).toInt()),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedAccount.accountHolderName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _maskedLast4(selectedAccount.accountNumber),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.black,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipientField(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'To',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _recipientController,
          decoration: _inputDecoration(
            theme: theme,
            hintText: 'Recipient Account ID',
            icon: Icons.person_outline_rounded,
          ),
          keyboardType: TextInputType.text,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a recipient';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildAmountField(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Amount',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _amountController,
          decoration: _inputDecoration(
            theme: theme,
            hintText: '0.00',
            icon: Icons.attach_money_rounded,
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter an amount';
            }
            if (double.tryParse(value) == null) {
              return 'Please enter a valid number';
            }
            if (double.parse(value) <= 0) {
              return 'Amount must be greater than zero';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDescriptionField(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _descriptionController,
          decoration: _inputDecoration(
            theme: theme,
            hintText: 'e.g., Dinner with friends',
            icon: Icons.edit_note_rounded,
          ),
          keyboardType: TextInputType.text,
          maxLines: 3,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a description';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSubmitButton(ThemeData theme) {
    final isTransfer = selectedTransactionType == TransactionType.transfer;
    final canSubmitTransfer = !isSubmitting &&
        _selectedAccountId != null &&
        _selectedRecipientAccountId != null &&
        _amountController.text.trim().isNotEmpty &&
        double.tryParse(_amountController.text.trim()) != null &&
        double.parse(_amountController.text.trim()) > 0;
    final enabled = isTransfer ? canSubmitTransfer : !isSubmitting;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: enabled ? _submitForm : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: isSubmitting
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                _buildSettleLabel(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required ThemeData theme,
    required String hintText,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Colors.black54),
      prefixIcon: Icon(icon, color: theme.hintColor, size: 22),
      filled: true,
      fillColor: theme.cardColor,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.dividerColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.dividerColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
      ),
    );
  }

  void _showAccountSelection(ThemeData theme, Size size) {
    // Debug: Print current selected account ID
    _logger.info('Current _selectedAccountId: $_selectedAccountId');
    _logger.info('Number of accounts: ${accounts.length}');
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        // Initialize with the currently selected account ID
        String? selectedIdInModal = _selectedAccountId;
        _logger.info('Modal selectedIdInModal: $selectedIdInModal');
        
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter modalSetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              maxChildSize: 0.9,
              minChildSize: 0.4,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Select Account', style: theme.textTheme.headlineSmall?.copyWith(color: Colors.black)),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: accounts.length,
                          itemBuilder: (context, index) {
                            final account = accounts[index];
                            final isSelected = selectedIdInModal != null && account.id.isNotEmpty && selectedIdInModal == account.id;
                            
                            // Debug: Print each account's selection state
                            _logger.info('Account ${index + 1} - ID: ${account.id}, Name: ${account.accountHolderName}, isSelected: $isSelected');

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                                child: InkWell(
                                  onTap: () {
                                    _logger.info('Tapped account ${account.accountHolderName} with ID: ${account.id}');
                                    // Update the modal state
                                    modalSetState(() {
                                      selectedIdInModal = account.id;
                                    });
                                    // Update the main widget state
                                    setState(() {
                                      _selectedAccountId = account.id;
                                    });
                                    _logger.info('Updated _selectedAccountId to: $_selectedAccountId');
                                    // Close the modal
                                    Navigator.pop(context);
                                  },
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primary.withAlpha((255 * 0.07).toInt())
                                          : theme.cardColor,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.primary.withAlpha((255 * 0.3).toInt())
                                            : theme.dividerColor.withAlpha((255 * 0.5).toInt()),
                                        width: isSelected ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? AppColors.primary.withAlpha((255 * 0.1).toInt())
                                                : theme.highlightColor,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isSelected
                                                  ? AppColors.primary.withAlpha((255 * 0.3).toInt())
                                                  : theme.dividerColor,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.account_balance_wallet_outlined,
                                            color: isSelected
                                                ? AppColors.primary
                                                : theme.iconTheme.color?.withAlpha((255 * 0.8).toInt()),
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                account.accountHolderName,
                                                style: theme.textTheme.titleMedium?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '•••• ${account.accountNumber.substring(account.accountNumber.length - 4)} • ${account.bankName}',
                                                style: theme.textTheme.bodySmall?.copyWith(
                                                  color: Colors.black,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Only show checkmark for the selected account
                                        if (isSelected)
                                          const Icon(
                                            Icons.check_circle,
                                            color: AppColors.primary,
                                            size: 24,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // Summary card removed

  Widget _buildDetailsSection(ThemeData theme) {
    final period = _currentPeriodString();
    final payee = _recipientController.text.trim().isEmpty
        ? '-'
        : _recipientController.text.trim();
    final amountText = _currentAmountString();
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: [
          _kvRow(theme, 'Payee', payee),
          Divider(height: 1, color: theme.dividerColor),
          _kvRow(theme, 'Over', period),
          Divider(height: 1, color: theme.dividerColor),
          _kvRow(theme, 'Amount', amountText, valueColor: Colors.red, isBold: true),
        ],
      ),
    );
  }

  Widget _buildEmailRow(ThemeData theme) {
    return TextFormField(
      controller: _emailController,
      decoration: _inputDecoration(
        theme: theme,
        hintText: 'email@example.com',
        icon: Icons.email_outlined,
      ),
      keyboardType: TextInputType.emailAddress,
    );
  }

  Widget _buildPaymentMethods(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Payment method',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            TextButton(
              onPressed: () => _navigateToAddCard(context),
              child: const Text('+ Add new'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildUserCards(theme),
      ],
    );
  }

  Widget _buildUserCards(ThemeData theme) {
    if (_userCards.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.credit_card_outlined, size: 48, color: theme.hintColor),
              const SizedBox(height: 8),
              Text(
                'No cards available',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _navigateToAddCard(context),
                child: const Text('Add your first card'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _userCards.asMap().entries.map((entry) {
        final index = entry.key;
        final card = entry.value;
        final selected = _selectedPaymentMethod == index;
        
        return Padding(
          padding: EdgeInsets.only(bottom: index < _userCards.length - 1 ? 12 : 0),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _selectedPaymentMethod = index),
            child: Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? AppColors.primary : theme.dividerColor,
                  width: selected ? 1.5 : 1,
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    selected ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: selected ? AppColors.primary : theme.hintColor,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '•••• ${card.last4}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.black,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getCardTypeColor(card.type).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                card.type.toUpperCase(),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: _getCardTypeColor(card.type),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${card.network} • ${card.holder}',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Balance: ${card.formattedBalance}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _navigateToEditCard(context, card),
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    tooltip: 'Edit card',
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _getCardTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'credit':
        return Colors.orange;
      case 'forex':
        return Colors.purple;
      case 'debit':
      default:
        return Colors.blue;
    }
  }

  void _navigateToAddCard(BuildContext context) {
    // Navigate directly using MaterialPageRoute for now to avoid routing issues
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddCardScreen(),
      ),
    ).then((_) {
      // Refresh cards when returning from add card screen
      _loadUserCards();
    });
  }

  void _navigateToEditCard(BuildContext context, CardModel card) {
    // Navigate to edit card screen or show card details
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Edit ${card.type} card ending in ${card.last4}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _kvRow(ThemeData theme, String k, String v, {Color? valueColor, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black)),
          Text(
            v,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: valueColor ?? Colors.black,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _currentAmountString() {
    final raw = _amountController.text.trim();
    final s = raw.isEmpty ? '0' : raw;
    return '₹$s';
  }

  String _currentPeriodString() {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month - 1, now.day);
    String fmt(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return '${fmt(from)} to ${fmt(now)}';
  }

  String _buildSettleLabel() {
    final amount = _currentAmountString();
    return 'Settle $amount';
  }

  // Recipient loaders
  Future<void> _fetchRecipientUsers() async {
    try {
      setState(() {
        _loadingRecipients = true;
        _recipientUsers = [];
        _selectedRecipientUserId = null;
        _recipientAccounts = [];
        _selectedRecipientAccountId = null;
      });
      final api = Provider.of<ApiService>(context, listen: false);
      final resp = await api.get('/api/users');
      if (!mounted) return;
      final data = (resp is Map && resp['data'] is List) ? List<Map<String, dynamic>>.from(resp['data']) : <Map<String, dynamic>>[];
      if (mounted) {
        setState(() {
          _recipientUsers = data
              .map((e) => {
                    'id': (e['_id'] ?? e['id']).toString(),
                    'name': (e['name'] ?? '').toString(),
                    'email': (e['email'] ?? '').toString(),
                  })
              .toList();
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load users: $e')));
    } finally {
      if (mounted) setState(() => _loadingRecipients = false);
    }
  }

  Future<void> _fetchRecipientAccounts(String userId) async {
    try {
      setState(() {
        _loadingRecipientAccounts = true;
        _recipientAccounts = [];
        _selectedRecipientAccountId = null;
      });
      final api = Provider.of<ApiService>(context, listen: false);
      final resp = await api.get('/api/users/$userId/accounts');
      if (!mounted) return;
      final list = (resp is Map && resp['data'] is List) ? List<Map<String, dynamic>>.from(resp['data']) : <Map<String, dynamic>>[];
      if (mounted) {
        setState(() {
          _recipientAccounts = list.map((e) => BankAccount.fromMap(e)).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load accounts: $e')));
      }
    } finally {
      if (mounted) setState(() => _loadingRecipientAccounts = false);
    }
  }

  // Recipient UI
  Widget _buildRecipientUserDropdown(ThemeData theme) {
    if (_loadingRecipients) {
      return const Center(child: CircularProgressIndicator());
    }
    return DropdownButtonFormField<String>(
      initialValue: _selectedRecipientUserId,
      decoration: _inputDecoration(theme: theme, hintText: 'Select recipient user', icon: Icons.person_outline),
      items: _recipientUsers
          .map((u) => DropdownMenuItem<String>(
                value: u['id'],
                child: Text('${u['name']} (${u['email']})', style: const TextStyle(color: Colors.black)),
              ))
          .toList(),
      onChanged: (val) {
        setState(() {
          _selectedRecipientUserId = val;
          _recipientAccounts = [];
          _selectedRecipientAccountId = null;
        });
        if (val != null) {
          _fetchRecipientAccounts(val);
        }
      },
    );
  }

  Widget _buildRecipientAccountDropdown(ThemeData theme) {
    if (_loadingRecipientAccounts) {
      return const Center(child: CircularProgressIndicator());
    }
    return DropdownButtonFormField<String>(
      initialValue: _selectedRecipientAccountId,
      decoration: _inputDecoration(theme: theme, hintText: 'Select recipient account', icon: Icons.account_balance),
      items: _recipientAccounts
          .map((a) => DropdownMenuItem<String>(
                value: a.id,
                child: Text('•••• ${a.accountNumber.length > 4 ? a.accountNumber.substring(a.accountNumber.length - 4) : a.accountNumber} • ${a.bankName}', style: const TextStyle(color: Colors.black)),
              ))
          .toList(),
      onChanged: (val) {
        setState(() => _selectedRecipientAccountId = val);
      },
    );
  }

  String _maskedLast4(String accountNumber) {
    final n = accountNumber;
    if (n.isEmpty) return '••••';
    if (n.length <= 4) return '•••• $n';
    return '•••• ${n.substring(n.length - 4)}';
  }
}
