import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';

import 'package:ket_stroke_bank/constants/app_theme.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:ket_stroke_bank/models/bank_account_model.dart';
import 'package:ket_stroke_bank/models/transaction_model.dart';
import 'package:ket_stroke_bank/services/auth_service.dart';
import 'package:ket_stroke_bank/services/bank_account_service.dart';
import 'package:ket_stroke_bank/services/transaction_service.dart';
import 'package:ket_stroke_bank/services/keystroke_service.dart';
import 'package:ket_stroke_bank/screens/accounts/add_account_screen.dart';
import 'package:ket_stroke_bank/screens/accounts/manage_accounts_screen.dart';
import 'package:ket_stroke_bank/screens/transactions/add_transaction_screen_fixed.dart';
import 'package:ket_stroke_bank/screens/qr/qr_generation_screen.dart';
import 'package:ket_stroke_bank/screens/qr/qr_scanner_screen.dart';
import 'package:ket_stroke_bank/screens/profile/personal_information_screen.dart';
import 'package:ket_stroke_bank/screens/profile/my_cards_screen.dart';
import 'package:ket_stroke_bank/screens/profile/pay_by_card_screen.dart';
import 'package:ket_stroke_bank/screens/profile/transaction_history_screen.dart';
import 'package:ket_stroke_bank/screens/profile/settings_screen.dart';
import 'package:ket_stroke_bank/screens/profile/help_support_screen.dart';

final _logger = Logger('DashboardScreen');

class DashboardScreen extends StatefulWidget {
  final Function(int)? onTabTapped;

  const DashboardScreen({super.key, this.onTabTapped});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    // Initialize any necessary data when the dashboard loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;

    try {
      // Access services using Provider
      final authService = Provider.of<AuthService>(context, listen: false);
      final bankAccountService = Provider.of<BankAccountService>(
        context,
        listen: false,
      );

      // Load initial data if needed
      if (authService.isAuthenticated) {
        // Initialize the bank account service which will load the accounts
        await bankAccountService.initialize();
      }
    } catch (e) {
      if (mounted) {
        final context = this.context;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Some data may be unavailable - app will work in offline mode',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        return Scaffold(
          key: _scaffoldKey,
          appBar: AppBar(
            title: const Text('KetStroke Bank'),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () => _handleSignOut(authService, context),
              ),
            ],
          ),
          body: IndexedStack(
            index: _selectedIndex,
            children: const [
              _HomeTab(),
              _TransactionsTab(),
              _CardsTab(),
              _ProfileTab(),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: _selectedIndex,
            selectedItemColor: AppTheme.primaryColor,
            unselectedItemColor: Colors.grey,
            showUnselectedLabels: true,
            onTap: _onItemTapped,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.swap_horiz_outlined),
                activeIcon: Icon(Icons.swap_horiz),
                label: 'Transactions',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.credit_card_outlined),
                activeIcon: Icon(Icons.credit_card),
                label: 'Cards',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
          floatingActionButton: _selectedIndex == 1
              ? FloatingActionButton(
                  onPressed: () async {
                    // Get the services before the async gap
                    final transactionService = Provider.of<TransactionService>(
                      context,
                      listen: false,
                    );
                    final bankAccountService = Provider.of<BankAccountService>(
                      context,
                      listen: false,
                    );

                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddTransactionScreen(),
                      ),
                    );

                    if (!mounted) return;

                    // Refresh both transactions and accounts so balances reflect
                    await transactionService.initialize();
                    await bankAccountService.initialize();
                  },
                  child: const Icon(Icons.add),
                )
              : null,
        );
      },
    );
  }

  Future<void> _handleSignOut(
    AuthService authService,
    BuildContext context,
  ) async {
    try {
      await authService.signOut();
      if (!mounted) return;
      final navigatorContext = this.context;
      if (navigatorContext.mounted) {
        Navigator.of(
          navigatorContext,
        ).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      if (!mounted) return;
      final scaffoldContext = this.context;
      if (scaffoldContext.mounted) {
        ScaffoldMessenger.of(scaffoldContext).showSnackBar(
          SnackBar(content: Text('Error signing out: ${e.toString()}')),
        );
      }
    }
  }

  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
}

class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  _HomeTabState createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  String? _authToken;
  String? _selectedAccountId; // null => All Accounts
  static const String _kSelectedAccountPrefKey = 'dashboard.selectedAccountId';

  // Helper method to safely update state
  void _safeSetState(VoidCallback fn) {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(fn);
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // Get auth token when widget initializes
    final authService = Provider.of<AuthService>(context, listen: false);
    _authToken = authService.token;

    // Load initial data after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTransactionData();
      _loadSelectedAccountPreference();
    });
  }

  // Load transaction data from the service
  Future<void> _loadTransactionData() async {
    if (!mounted || _authToken == null) return;

    try {
      final transactionService = Provider.of<TransactionService>(
        context,
        listen: false,
      );
      final bankAccountService = Provider.of<BankAccountService>(
        context,
        listen: false,
      );

      // Initialize services
      try {
        // Initialize transaction service first (no auth token needed)
        await transactionService.initialize();

        // Initialize bank account service
        await bankAccountService.initialize();
      } catch (e) {
        _logger.severe('Error initializing services', e);
        // Don't rethrow - let the app continue with empty data
        return;
      }

      if (mounted) {
        _safeSetState(() {});
      }
    } catch (e) {
      _logger.severe('Error loading data', e);
      if (mounted) {
        // Show a more user-friendly message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Some data may be unavailable - app will work in offline mode',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Refresh callback for the RefreshIndicator
  Future<void> _handleRefresh() async {
    try {
      await _loadTransactionData();
    } catch (e) {
      _logger.severe('Error during refresh', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Refresh failed - some data may be unavailable'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      // Don't rethrow - let the refresh complete
    }
  }

  Future<void> _loadSelectedAccountPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_kSelectedAccountPrefKey);
      if (!mounted) return;
      if (saved != null && saved.isNotEmpty) {
        setState(() {
          _selectedAccountId = saved;
        });
      }
    } catch (_) {
      // ignore preference errors
    }
  }

  Future<void> _persistSelectedAccountPreference(String? accountId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (accountId == null || accountId.isEmpty) {
        await prefs.remove(_kSelectedAccountPrefKey);
      } else {
        await prefs.setString(_kSelectedAccountPrefKey, accountId);
      }
    } catch (_) {
      // ignore preference errors
    }
  }

  Widget _buildSummaryItem(
    String label,
    String amount,
    Color color,
    IconData icon,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(
              amount,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showTransactionDetails(
    BuildContext context,
    TransactionModel transaction,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: transaction.color.withAlpha((255 * 0.2).toInt()),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    transaction.icon,
                    color: transaction.color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      transaction.formattedDate,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  transaction.formattedAmount,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: transaction.amount < 0 ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
            if (transaction.description.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Description',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Text(transaction.description),
            ],
            if (transaction.recipient != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Recipient',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Text(transaction.recipient!),
            ],
            if (transaction.reference != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Reference',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Text(transaction.reference!),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Show delete confirmation dialog
  Future<void> _showDeleteConfirmation(
    BuildContext context,
    BankAccount account,
    BankAccountService bankAccountService,
  ) async {
    if (!mounted || _authToken == null) return;

    // Get local reference to ScaffoldMessenger before any async operations
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: Text(
          'Are you sure you want to delete the account ending in ${account.accountNumber.length > 4 ? account.accountNumber.substring(account.accountNumber.length - 4) : account.accountNumber}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      final success = await bankAccountService.deleteAccount(account.id);

      if (!mounted) return;

      if (success) {
        // Force a refresh of the accounts list
        await bankAccountService.initialize();

        if (!mounted) return;
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Account deleted successfully')),
        );
      } else if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              'Failed to delete account: ${bankAccountService.error ?? 'Unknown error'}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e, stackTrace) {
      _logger.severe('Error deleting account', e, stackTrace);
      if (!mounted) return;

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error deleting account: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildTransactionItem(TransactionModel transaction) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: transaction.color.withAlpha((255 * 0.2).round()),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(transaction.icon, color: transaction.color, size: 20),
      ),
      title: Text(
        transaction.title,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        transaction.formattedDate,
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),
      trailing: Text(
        transaction.formattedAmount,
        style: TextStyle(
          color: transaction.amount < 0 ? Colors.red : Colors.green,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      onTap: () {
        _showTransactionDetails(context, transaction);
      },
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(icon, color: AppTheme.secondaryColor, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transactionService = Provider.of<TransactionService>(context);
    final bankAccountService = Provider.of<BankAccountService>(context);
    final authService = Provider.of<AuthService>(context);
    final keystrokeService = Provider.of<KeystrokeService>(context);

    // Get user's first name or default to 'User'
    final userName = authService.currentUser?.name.split(' ').first ?? 'User';
    final accounts = bankAccountService.accounts;
    // Ensure selected account still exists; otherwise reset to All Accounts
    if (_selectedAccountId != null &&
        !accounts.any((a) => a.id == _selectedAccountId)) {
      _selectedAccountId = null;
    }

    // Balance: use authoritative balances from BankAccount(s)
    double totalBalance;
    if (_selectedAccountId == null || _selectedAccountId!.isEmpty) {
      totalBalance = accounts.fold(0.0, (sum, a) => sum + (a.balance));
    } else {
      final sel = bankAccountService.getAccountById(_selectedAccountId!);
      totalBalance = sel?.balance ?? 0.0;
    }
    final totalIncome = transactionService.getIncomeForAccount(
      _selectedAccountId,
    );
    final totalExpenses = transactionService.getExpensesForAccount(
      _selectedAccountId,
    );
    final recentTransactions = transactionService.recentTransactions;

    if (transactionService.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Keystroke ML status
    final stats = keystrokeService.getBehavioralStats();
    final bool isSecure = stats['hasProfile'] == true;
    final int confidence = (stats['confidenceScore'] as double?)?.toInt() ?? 0;

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(
          0.0,
        ), // Zero padding for edge-to-edge header
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FAADU PREMIUM HEADER (AXIS GLOW STYLE)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(
                top: 60,
                left: 24,
                right: 24,
                bottom: 35,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF8B0015), // Deep Mahogany
                    Color(0xFFD60029), // Crimson Red
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B0015).withValues(alpha: 0.5),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Welcome back,',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            userName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      // Animated Behavioral Lock Shield
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSecure
                              ? Colors.greenAccent.withValues(alpha: 0.15)
                              : Colors.orangeAccent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSecure
                                ? Colors.greenAccent
                                : Colors.orangeAccent,
                            width: 2,
                          ),
                          boxShadow: [
                            if (isSecure)
                              BoxShadow(
                                color: Colors.greenAccent.withValues(
                                  alpha: 0.6,
                                ),
                                blurRadius: 20,
                                spreadRadius: 3,
                              )
                            else
                              BoxShadow(
                                color: Colors.orangeAccent.withValues(
                                  alpha: 0.5,
                                ),
                                blurRadius: 20,
                                spreadRadius: 3,
                              ),
                          ],
                        ),
                        child: Icon(
                          isSecure
                              ? Icons.fingerprint
                              : Icons.warning_amber_rounded,
                          color: isSecure
                              ? Colors.greenAccent
                              : Colors.orangeAccent,
                          size: 36,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 35),
                  const Text(
                    'Total Balance',
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${totalBalance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.5,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(color: Colors.white24, width: 0.5),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.shield,
                              color: Colors.amberAccent,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isSecure
                                  ? 'Active: $confidence% Match'
                                  : 'Setup Lock!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (accounts.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              value: _selectedAccountId,
                              dropdownColor: const Color(0xFF8B0015),
                              icon: const Icon(
                                Icons.keyboard_arrow_down,
                                color: Colors.white70,
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('All Accounts'),
                                ),
                                ...accounts.map((a) {
                                  final last4 = a.accountNumber.length >= 4
                                      ? a.accountNumber.substring(
                                          a.accountNumber.length - 4,
                                        )
                                      : a.accountNumber;
                                  return DropdownMenuItem<String?>(
                                    value: a.id,
                                    child: Text('${a.bankName} •••• $last4'),
                                  );
                                }),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedAccountId = value;
                                });
                                _persistSelectedAccountPreference(value);
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),

            // Body Content Padding
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sleek White Glassmorphic-style Income/Expenses Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSummaryItem(
                          'Income',
                          '₹${totalIncome.toStringAsFixed(2)}',
                          Colors.green,
                          Icons.arrow_upward,
                        ),
                        Container(
                          height: 45,
                          width: 1.5,
                          color: Colors.grey.shade100,
                        ),
                        _buildSummaryItem(
                          'Expenses',
                          '₹${totalExpenses.abs().toStringAsFixed(2)}',
                          Colors.red,
                          Icons.arrow_downward,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // Bank Accounts Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'My Accounts',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () async {
                        // Navigate to ManageAccountsScreen
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ManageAccountsScreen(),
                          ),
                        );

                        // Refresh accounts when returning from ManageAccountsScreen
                        if (!mounted) return;
                        await bankAccountService.initialize();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                      ),
                      child: const Text('Manage'),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AddAccountScreen(),
                          ),
                        ).then((_) async {
                          // Refresh accounts when returning from AddAccountScreen
                          try {
                            await bankAccountService.initialize();
                          } catch (e) {
                            _logger.warning('Error refreshing accounts', e);
                          }
                        });
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Account'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (accounts.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'No bank accounts added yet. Tap "Add Account" to get started.',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              Container(
                height: 140, // Increased height to accommodate delete button
                margin: const EdgeInsets.only(bottom: 16),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: accounts.length,
                  itemBuilder: (context, index) {
                    final account = accounts[index];
                    return GestureDetector(
                      onLongPress: () => _showDeleteConfirmation(
                        context,
                        account,
                        bankAccountService,
                      ),
                      child: Container(
                        width: 200,
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(
                            alpha: 13,
                          ), // ~0.05 opacity
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.primaryColor.withValues(
                              alpha: 26,
                            ), // ~0.1 opacity
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0x0D000000,
                              ), // black with 0.05 opacity
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            // Main content
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Bank name and primary badge
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        account.bankName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (account.isPrimary)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor
                                              .withValues(
                                                alpha: 26,
                                              ), // ~0.1 opacity
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Text(
                                          'Primary',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: AppTheme.primaryColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),

                                const Spacer(),

                                // Account number
                                Text(
                                  '•••• ${account.accountNumber.substring(account.accountNumber.length - 4)}',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),

                                // Account type and IFSC
                                Text(
                                  '${account.accountType.toString().split('.').last} • ${account.ifscCode}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),

                                // Account holder name
                                Text(
                                  account.accountHolderName,
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),

                            // Delete button (appears on tap and hold)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 2,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 14,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 24),
            // Quick Actions
            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withAlpha(25), // ~10% opacity
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildActionButton('Send', Icons.arrow_upward, () {
                        // Navigate to transfer money screen with withdrawal type pre-selected
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddTransactionScreen(
                              // Pre-select withdrawal transaction type
                              initialTransactionType:
                                  TransactionType.withdrawal,
                            ),
                          ),
                        );
                      }),
                      _buildActionButton('Request', Icons.arrow_downward, () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const QRGenerationScreen(),
                          ),
                        );
                      }),
                      _buildActionButton('Transfer', Icons.swap_horiz, () {
                        // Store context in a local variable to use after async gap
                        final currentContext = context;

                        Navigator.push(
                          currentContext,
                          MaterialPageRoute(
                            builder: (context) => AddTransactionScreen(
                              // Pre-select transfer transaction type
                              initialTransactionType: TransactionType.transfer,
                            ),
                          ),
                        ).then((_) {
                          // Refresh the dashboard when returning from transfer screen
                          if (!currentContext.mounted) return;

                          final transactionService =
                              Provider.of<TransactionService>(
                                currentContext,
                                listen: false,
                              );
                          transactionService.initialize();
                        });
                      }),
                      _buildActionButton('QR Scan', Icons.qr_code_scanner, () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const QRScannerScreen(),
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildActionButton('Pay by Card', Icons.payment, () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PayByCardScreen(),
                          ),
                        );
                      }),
                      const SizedBox(width: 80), // Spacer for centering
                      const SizedBox(width: 80), // Spacer for centering
                      const SizedBox(width: 80), // Spacer for centering
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Recent Transactions Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Transactions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    final dashboardState = context
                        .findAncestorStateOfType<_DashboardScreenState>();
                    if (dashboardState != null && dashboardState.mounted) {
                      dashboardState.setState(() {
                        dashboardState._selectedIndex = 1; // Transactions tab
                      });
                    }
                  },
                  child: const Text('See All'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Recent Transactions List
            if (recentTransactions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32.0),
                child: Center(
                  child: Text(
                    'No transactions yet',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentTransactions.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final transaction = recentTransactions[index];
                  return _buildTransactionItem(transaction);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _TransactionsTab extends StatelessWidget {
  const _TransactionsTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionService>(
      builder: (context, txService, _) {
        if (txService.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        final transactions = txService.transactions;
        if (transactions.isEmpty) {
          return const Center(
            child: Text(
              'No transactions yet',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }
        final sorted = List<TransactionModel>.from(transactions)
          ..sort((a, b) => b.date.compareTo(a.date));
        return RefreshIndicator(
          onRefresh: () async {
            try {
              await txService.initialize();
            } catch (_) {}
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: sorted.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final t = sorted[index];
              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: t.color.withAlpha((255 * 0.2).round()),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(t.icon, color: t.color, size: 20),
                ),
                title: Text(
                  t.title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  t.formattedDate,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                trailing: Text(
                  t.formattedAmount,
                  style: TextStyle(
                    color: t.amount < 0 ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _CardsTab extends StatelessWidget {
  const _CardsTab();

  @override
  Widget build(BuildContext context) {
    return const MyCardsScreen();
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Profile Picture
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[200],
              border: Border.all(color: AppTheme.primaryColor, width: 2),
            ),
            child: const Icon(Icons.person, size: 50, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          // User Name
          Text(
            user?.name ?? 'User',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          // User Email
          Text(
            user?.email ?? 'user@example.com',
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 32),
          // Menu Items
          _buildMenuItem(
            icon: Icons.person_outline,
            title: 'Personal Information',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PersonalInformationScreen(),
                ),
              );
            },
          ),
          _buildMenuItem(
            icon: Icons.credit_card_outlined,
            title: 'My Cards',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyCardsScreen()),
              );
            },
          ),
          _buildMenuItem(
            icon: Icons.history,
            title: 'Transaction History',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TransactionHistoryScreen(),
                ),
              );
            },
          ),
          _buildMenuItem(
            icon: Icons.settings_outlined,
            title: 'Settings',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          _buildMenuItem(
            icon: Icons.help_outline,
            title: 'Help & Support',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
              );
            },
          ),
          const SizedBox(height: 24),
          // Logout Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                await authService.signOut();
                // Navigation is handled by AuthWrapper
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[50],
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Logout'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppTheme.primaryColor),
      ),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}
