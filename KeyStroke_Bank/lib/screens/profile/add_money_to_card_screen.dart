import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/card_model.dart';
import '../../models/bank_account_model.dart';
import '../../models/transaction_model.dart';
import '../../services/card_service.dart';
import '../../services/bank_account_service.dart';
import '../../services/transaction_service.dart';
import '../../constants/app_theme.dart';

class AddMoneyToCardScreen extends StatefulWidget {
  final CardModel card;

  const AddMoneyToCardScreen({super.key, required this.card});

  @override
  State<AddMoneyToCardScreen> createState() => _AddMoneyToCardScreenState();
}

class _AddMoneyToCardScreenState extends State<AddMoneyToCardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  bool _isLoading = false;
  String? _selectedAccountId;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _addMoney() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a source account'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) return;

    setState(() => _isLoading = true);

    try {
      final cardService = Provider.of<CardService>(context, listen: false);
      final bankAccountService = Provider.of<BankAccountService>(context, listen: false);
      final transactionService = Provider.of<TransactionService>(context, listen: false);

      // Check if account has sufficient funds
      final account = bankAccountService.accounts.firstWhere(
        (acc) => acc.id == _selectedAccountId,
      );

      if (account.balance < amount) {
        throw Exception('Insufficient funds. Account has ₹${account.balance.toStringAsFixed(2)}, but transfer requires ₹${amount.toStringAsFixed(2)}');
      }

      // Create a transaction to deduct from bank account
      final transaction = TransactionModel(
        id: '', // Will be set by backend
        accountId: _selectedAccountId!,
        amount: amount, // Positive amount for withdrawal
        type: TransactionType.withdrawal,
        description: 'Add money to ${widget.card.network} card •••• ${widget.card.last4}',
        date: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Add the transaction (this will deduct from bank account)
      await transactionService.addTransaction(transaction);

      // Add money to the card
      await cardService.addBalance(widget.card.id, amount);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully added ₹${amount.toStringAsFixed(2)} to ${widget.card.network} card'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add money: ${e.toString()}'),
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
    final bankAccountService = context.watch<BankAccountService>();
    final accounts = bankAccountService.accounts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Money to Card'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Card Display
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: widget.card.network == 'Visa'
                      ? const LinearGradient(colors: [Color(0xFF6A5AE0), Color(0xFF6CC6FF)])
                      : const LinearGradient(colors: [Color(0xFFFF8A65), Color(0xFFFFB74D)]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.sim_card, color: Colors.white),
                        Text(
                          '${widget.card.network.toUpperCase()} • ${widget.card.type.toUpperCase()}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.card.maskedNumber,
                      style: const TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.card.holder.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildChip('VALID', '${widget.card.month}/${widget.card.year}'),
                        const Spacer(),
                        _buildChip('BALANCE', widget.card.formattedBalance),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Money will be transferred from your selected bank account to this card.',
                        style: TextStyle(color: Colors.blue.shade700),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Source Account Selection
              Text(
                'From Account',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              
              if (accounts.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No bank accounts available. Please add a bank account first.',
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                )
              else
                RadioGroup<String>(
                  onChanged: (value) {
                    setState(() {
                      _selectedAccountId = value;
                    });
                  },
                  child: Column(
                    children: accounts.map((account) => _buildAccountCard(account)).toList(),
                  ),
                ),
              
              const SizedBox(height: 24),
              
              // Amount Input
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Amount to Add',
                  hintText: '0.00',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                  filled: true,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid amount';
                  }
                  if (amount > 100000) {
                    return 'Amount cannot exceed ₹100,000';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 32),
              
              // Add Money Button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading || accounts.isEmpty ? null : _addMoney,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'ADD MONEY',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountCard(BankAccount account) {
    final isSelected = _selectedAccountId == account.id;
    final hasSufficientFunds = account.balance > 0;

    return GestureDetector(
      onTap: hasSufficientFunds ? () {
        setState(() {
          _selectedAccountId = account.id;
        });
      } : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.05) : null,
        ),
        child: RadioListTile<String>(
          value: account.id,
        title: Text(
          account.accountNumber,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: hasSufficientFunds ? null : Colors.grey,
          ),
        ),
        subtitle: Text(
          'Balance: ₹${account.balance.toStringAsFixed(2)}',
          style: TextStyle(
            color: hasSufficientFunds ? Colors.green.shade700 : Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        secondary: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.account_balance,
            color: Colors.white,
            size: 20,
          ),
        ),
        controlAffinity: ListTileControlAffinity.trailing,
        ),
      ),
    );
  }

  Widget _buildChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(width: 6),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
