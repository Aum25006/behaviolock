import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/settings_service.dart';
import '../../services/bank_account_service.dart';
import '../../services/card_service.dart';

class AddCardResult {
  final String brand;
  final String numberGroup1;
  final String numberGroup2;
  final String numberGroup3;
  final String numberGroup4;
  final String holderName;
  final String month;
  final String year;
  final String type; // Debit, Credit, Forex
  final String network; // Visa or Mastercard

  AddCardResult({
    required this.brand,
    required this.numberGroup1,
    required this.numberGroup2,
    required this.numberGroup3,
    required this.numberGroup4,
    required this.holderName,
    required this.month,
    required this.year,
    required this.type,
    required this.network,
  });
}

class AddCardScreen extends StatefulWidget {
  const AddCardScreen({super.key});

  @override
  State<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends State<AddCardScreen>
    with SingleTickerProviderStateMixin {
  final _g1 = TextEditingController();
  final _g2 = TextEditingController();
  final _g3 = TextEditingController();
  final _g4 = TextEditingController();
  final _name = TextEditingController();

  String? _month;
  String? _year;
  String _network = 'Visa';

  final _debitFormKey = GlobalKey<FormState>();
  final _creditFormKey = GlobalKey<FormState>();
  final _forexFormKey = GlobalKey<FormState>();

  // Account balance tracking
  double _totalAccountBalance = 0.0;
  bool _isLoadingBalance = true;
  static const double _premiumCardThreshold = 100000.0; // 1 Lakh rupees

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthService>(context, listen: false);
    _name.text = auth.currentUser?.name ?? '';
    _loadAccountBalance();
  }

  Future<void> _loadAccountBalance() async {
    // Store context before async operations
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      setState(() => _isLoadingBalance = true);
      
      final accountService = Provider.of<BankAccountService>(context, listen: false);
      await accountService.initialize();
      
      if (mounted) {
        final totalBalance = accountService.accounts.fold<double>(
          0.0, 
          (sum, account) => sum + account.balance
        );
        
        setState(() {
          _totalAccountBalance = totalBalance;
          _isLoadingBalance = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _totalAccountBalance = 0.0; // Default to 0 if loading fails
          _isLoadingBalance = false;
        });
        // Show a more user-friendly message
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Account balance unavailable - you can still add cards'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _g1.dispose();
    _g2.dispose();
    _g3.dispose();
    _g4.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final years = List<String>.generate(
      12,
      (i) => (DateTime.now().year + i).toString(),
    );
    final months = List<String>.generate(12, (i) => (i + 1).toString().padLeft(2, '0'));

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Add New Card'),
          actions: [
            if (!_isLoadingBalance)
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.account_balance_wallet,
                      size: 16,
                      color: Colors.green.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '₹${_totalAccountBalance.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
          ],
                     bottom: TabBar(
             isScrollable: true,
            tabs: [
                             Tab(
                 child: Container(
                   constraints: const BoxConstraints(maxWidth: 120),
                   child: const Text(
                     'DEBIT CARD',
                     textAlign: TextAlign.center,
                     style: TextStyle(fontSize: 12),
                   ),
                 ),
               ),
                             Tab(
                 child: Container(
                   constraints: const BoxConstraints(maxWidth: 120),
                   child: Row(
                     mainAxisAlignment: MainAxisAlignment.center,
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       Flexible(
                         child: Text(
                           'CREDIT CARD',
                           overflow: TextOverflow.ellipsis,
                           style: const TextStyle(fontSize: 12),
                         ),
                       ),
                       if (_totalAccountBalance < _premiumCardThreshold) ...[
                         const SizedBox(width: 2),
                         Icon(
                           Icons.lock,
                           size: 14,
                           color: Colors.orange.shade700,
                         ),
                       ],
                     ],
                   ),
                 ),
               ),
               Tab(
                 child: Container(
                   constraints: const BoxConstraints(maxWidth: 120),
                   child: Row(
                     mainAxisAlignment: MainAxisAlignment.center,
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       Flexible(
                         child: Text(
                           'FOREX CARD',
                           overflow: TextOverflow.ellipsis,
                           style: const TextStyle(fontSize: 12),
                         ),
                       ),
                       if (_totalAccountBalance < _premiumCardThreshold) ...[
                         const SizedBox(width: 2),
                         Icon(
                           Icons.lock,
                           size: 14,
                           color: Colors.orange.shade700,
                         ),
                       ],
                     ],
                   ),
                 ),
               ),
            ],
          ),
        ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildForm(context, months, years, 'Debit', _debitFormKey),
            _buildPremiumCardForm(context, months, years, 'Credit', _creditFormKey, 'Credit Card'),
            _buildPremiumCardForm(context, months, years, 'Forex', _forexFormKey, 'Forex Card'),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    List<String> months,
    List<String> years,
    String type,
    GlobalKey<FormState> formKey,
  ) {
    final inputFmt = <TextInputFormatter>[
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(4),
    ];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text('Card Number'),
            const SizedBox(height: 8),
            Row(
              children: [
                _groupField(_g1, inputFmt, onFilled: () => _focusNext(context)),
                const SizedBox(width: 12),
                _groupField(_g2, inputFmt, onFilled: () => _focusNext(context)),
                const SizedBox(width: 12),
                _groupField(_g3, inputFmt, onFilled: () => _focusNext(context)),
                const SizedBox(width: 12),
                _groupField(_g4, inputFmt),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Select Month',
                      border: OutlineInputBorder(),
                    ),
                    dropdownColor: Colors.white,
                    iconEnabledColor: Colors.black,
                    style: const TextStyle(color: Colors.black),
                    items: months
                        .map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(
                                m,
                                style: const TextStyle(color: Colors.black),
                              ),
                            ))
                        .toList(),
                    initialValue: _month,
                    onChanged: (v) => setState(() => _month = v),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Select Year',
                      border: OutlineInputBorder(),
                    ),
                    dropdownColor: Colors.white,
                    iconEnabledColor: Colors.black,
                    style: const TextStyle(color: Colors.black),
                    items: years
                        .map((y) => DropdownMenuItem(
                              value: y,
                              child: Text(
                                y,
                                style: const TextStyle(color: Colors.black),
                              ),
                            ))
                        .toList(),
                    initialValue: _year,
                    onChanged: (v) => setState(() => _year = v),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Card Holder Name',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(color: Colors.black),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _network,
              decoration: const InputDecoration(
                labelText: 'Network',
                border: OutlineInputBorder(),
              ),
              dropdownColor: Colors.white,
              iconEnabledColor: Colors.black,
              style: const TextStyle(color: Colors.black),
              items: _networkOptions(context)
                  .map((n) => DropdownMenuItem(
                        value: n.key,
                        child: Text(n.label, style: const TextStyle(color: Colors.black)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _network = v ?? 'Visa'),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _submit(context, type),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('ADD CARD'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumCardForm(
    BuildContext context,
    List<String> months,
    List<String> years,
    String type,
    GlobalKey<FormState> formKey,
    String cardTypeName,
  ) {
    // Check if user has sufficient balance for premium cards
    if (_totalAccountBalance < _premiumCardThreshold) {
      return _buildPremiumCardLocked(context, cardTypeName);
    }

    // If unlocked, show the normal form
    return _buildForm(context, months, years, type, formKey);
  }

  Widget _buildPremiumCardLocked(BuildContext context, String cardTypeName) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_outline,
            size: 80,
            color: Colors.orange.shade400,
          ),
          const SizedBox(height: 24),
          Text(
            '$cardTypeName Locked',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade700,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'You need a minimum balance of ₹1,00,000 to unlock $cardTypeName features.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(
              children: [
                Text(
                  'Current Total Balance',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '₹${_totalAccountBalance.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Required: ₹1,00,000',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.orange.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Add more money to your accounts to unlock premium card features!',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupField(TextEditingController c, List<TextInputFormatter> fmt,
      {VoidCallback? onFilled}) {
    return Expanded(
      child: TextFormField(
        controller: c,
        keyboardType: TextInputType.number,
        inputFormatters: fmt,
        textAlign: TextAlign.center,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
        ),
        onChanged: (v) {
          if (v.length == 4 && onFilled != null) onFilled();
        },
        validator: (v) => (v == null || v.length != 4) ? 'xxxx' : null,
      ),
    );
  }

  void _focusNext(BuildContext context) {
    FocusScope.of(context).nextFocus();
  }

  Future<void> _submit(BuildContext context, String type) async {
    final formKey = switch (type) {
      'Debit' => _debitFormKey,
      'Credit' => _creditFormKey,
      _ => _forexFormKey,
    };
    if (!formKey.currentState!.validate()) return;
    
    // Create a flag to track if the operation was successful
    bool isSuccess = false;
    String? errorMessage;
    
    // Store the context before async operation
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
    
    try {
      // Get the card service and add the card
      final cardService = Provider.of<CardService>(context, listen: false);
      
      // Execute the async operation
      await cardService.addCard(
        type: type,
        network: _network,
        numberGroup4: _g4.text,
        holder: _name.text.trim(),
        month: _month!,
        year: _year!,
        initialBalance: 0.0,
      );
      
      // Set success flag
      isSuccess = true;
    } catch (e) {
      // Set error message
      errorMessage = e.toString();
    }
    
    // After async operation, check if widget is still mounted
    if (!mounted) return;
    
    // Close loading dialog
    navigator.pop(); // Close loading dialog
    
    if (isSuccess) {
      // Show success message
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('$type card added successfully!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
      
      // Navigate to my cards page
      navigator.pushReplacementNamed('/my-cards');
    } else {
      // Show error message
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Failed to add card: $errorMessage'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }



  // Derive network options from SettingsService toggles
  List<_Option> _networkOptions(BuildContext context) {
    final settings = context.read<SettingsService>();
    final available = settings.networks; // e.g., ['Visa','Mastercard',...]
    return available.map((n) => _Option(key: n, label: _prettyNetwork(n))).toList();
  }

  String _prettyNetwork(String code) {
    switch (code) {
      case 'Amex':
        return 'American Express (Amex)';
      case 'PayPal':
        return 'PayPal';
      default:
        return code;
    }
  }
}

class _Option {
  final String key;
  final String label;
  _Option({required this.key, required this.label});
}


