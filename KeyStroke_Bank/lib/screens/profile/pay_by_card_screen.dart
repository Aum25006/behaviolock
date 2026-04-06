import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/card_model.dart';
import '../../services/card_service.dart';
import '../../services/transaction_service.dart';
import '../../models/transaction_model.dart';
import '../../constants/app_theme.dart';

class PayByCardScreen extends StatefulWidget {
  const PayByCardScreen({super.key});

  @override
  State<PayByCardScreen> createState() => _PayByCardScreenState();
}

class _PayByCardScreenState extends State<PayByCardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _merchantController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  bool _isLoading = false;
  String? _selectedCardId;
  String? _selectedMerchant;
  List<CardModel> _userCards = [];
  
  // Predefined merchants for quick selection
  final List<String> _merchants = [
    'Amazon',
    'Flipkart',
    'Swiggy',
    'Zomato',
    'Uber',
    'Ola',
    'Netflix',
    'Spotify',
    'PhonePe',
    'Google Pay',
    'Paytm',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _loadUserCards();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadUserCards() async {
    try {
      final cardService = context.read<CardService>();
      await cardService.initialize();
      
      if (mounted) {
        setState(() {
          _userCards = cardService.cards;
          if (_userCards.isNotEmpty) {
            _selectedCardId = _userCards.first.id;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load cards: $e')),
        );
      }
    }
  }

  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCardId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a card'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) return;

    setState(() => _isLoading = true);

    try {
      final cardService = context.read<CardService>();
      final transactionService = context.read<TransactionService>();
      
      // Get the selected card
      final card = cardService.getCardById(_selectedCardId!);
      if (card == null) throw Exception('Selected card not found');

      // Check if card has sufficient balance
      if (!card.hasSufficientBalance(amount)) {
        throw Exception('Insufficient balance. Available: ${card.formattedBalance}, Required: ₹${amount.toStringAsFixed(2)}');
      }

      // Create payment description
      final merchant = _selectedMerchant ?? _merchantController.text.trim();
      final description = _descriptionController.text.trim().isNotEmpty 
          ? '$merchant: ${_descriptionController.text.trim()}'
          : 'Payment to $merchant';

      // Create transaction record
      final transaction = TransactionModel(
        id: '', // Will be set by service
        accountId: _selectedCardId!,
        amount: amount,
        type: TransactionType.payment,
        description: description,
        date: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Process the payment (this will deduct from card balance)
      await transactionService.addTransaction(transaction);

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment of ₹${amount.toStringAsFixed(2)} processed successfully!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      // Navigate back
      Navigator.pop(context, true);

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pay by Card'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _userCards.isEmpty 
          ? _buildNoCardsView(theme)
          : _buildPaymentForm(theme),
    );
  }

  Widget _buildNoCardsView(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.credit_card_off,
              size: 80,
              color: theme.hintColor,
            ),
            const SizedBox(height: 24),
            Text(
              'No Cards Available',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.hintColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'You need to add a card first to make payments.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.hintColor,
              ),
            ),
            const SizedBox(height: 24),
                          ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/add-card'),
                icon: const Icon(Icons.add),
                label: const Text('Add Card'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentForm(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Selection
            _buildCardSelection(theme),
            const SizedBox(height: 24),
            
            // Amount Input
            _buildAmountInput(theme),
            const SizedBox(height: 24),
            
            // Merchant Selection
            _buildMerchantSelection(theme),
            const SizedBox(height: 24),
            
            // Description
            _buildDescriptionInput(theme),
            const SizedBox(height: 32),
            
            // Pay Button
            _buildPayButton(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildCardSelection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Card',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        ...(_userCards.map((card) {
          final isSelected = _selectedCardId == card.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _selectedCardId = card.id),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppTheme.primaryColor : theme.dividerColor,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.credit_card,
                      color: isSelected ? AppTheme.primaryColor : theme.hintColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${card.network} •••• ${card.last4}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          Text(
                            'Balance: ${card.formattedBalance}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                                          if (isSelected)
                        Icon(
                          Icons.check_circle,
                          color: AppTheme.primaryColor,
                          size: 20,
                        ),
                  ],
                ),
              ),
            ),
          );
        }).toList()),
      ],
    );
  }

  Widget _buildAmountInput(ThemeData theme) {
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
        const SizedBox(height: 8),
        TextFormField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
          ],
          decoration: InputDecoration(
            hintText: 'Enter amount',
            prefixText: '₹ ',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: theme.cardColor,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter amount';
            }
            final amount = double.tryParse(value);
            if (amount == null || amount <= 0) {
              return 'Please enter a valid amount';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildMerchantSelection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Merchant/Service',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedMerchant,
          decoration: InputDecoration(
            hintText: 'Select merchant or enter custom',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: theme.cardColor,
          ),
          items: _merchants.map((merchant) {
            return DropdownMenuItem(
              value: merchant,
              child: Text(merchant),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedMerchant = value;
              if (value != 'Other') {
                _merchantController.clear();
              }
            });
          },
        ),
        if (_selectedMerchant == 'Other') ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _merchantController,
            decoration: InputDecoration(
              hintText: 'Enter merchant name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: theme.cardColor,
            ),
            validator: (value) {
              if (_selectedMerchant == 'Other' && (value == null || value.trim().isEmpty)) {
                return 'Please enter merchant name';
              }
              return null;
            },
          ),
        ],
      ],
    );
  }

  Widget _buildDescriptionInput(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description (Optional)',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _descriptionController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Add payment description...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: theme.cardColor,
          ),
        ),
      ],
    );
  }

  Widget _buildPayButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _processPayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
                'PAY NOW',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
