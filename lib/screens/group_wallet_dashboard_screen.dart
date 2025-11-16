import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../app/theme/colors.dart';
import '../providers/wallet_provider.dart';
import '../services/group_wallet_service.dart' hide SpendingRequest;
import '../services/wallet_registry_service.dart';
import '../services/spending_request_service.dart';
import '../services/stellar_service.dart';
import '../models/group_wallet_model.dart';
import '../models/spending_request_model.dart';

class GroupWalletDashboardScreen extends StatefulWidget {
  final String groupWalletId;
  
  const GroupWalletDashboardScreen({
    super.key,
    required this.groupWalletId,
  });

  @override
  State<GroupWalletDashboardScreen> createState() => _GroupWalletDashboardScreenState();
}

class _GroupWalletDashboardScreenState extends State<GroupWalletDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  GroupWalletModel? _groupWallet;
  bool _isLoading = true;
  String? _error;

  // Helper method to get the adjusted current amount (excluding initial activation amount)
  double get _adjustedCurrentAmount {
    if (_groupWallet == null) return 0.0;
    // Use total contributions from transactions instead of subtracting activation amount
    // This includes the initial 1 XLM activation as a contribution
    return _groupWallet!.transactions
        .where((t) => t.type == GroupTransactionType.contribution && t.status == GroupTransactionStatus.completed)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadGroupWallet();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadGroupWallet() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final groupWallet = await GroupWalletService.getGroupWallet(widget.groupWalletId);
      
      if (mounted) {
        setState(() {
          _groupWallet = groupWallet;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<double> _getGroupWalletBalance() async {
    try {
      final accountInfo = await StellarService.getAccountInfo(_groupWallet!.publicKey);
      
      // Get XLM balance from account balances
      for (var balance in accountInfo.balances) {
        if (balance.assetType == 'native') {
          return double.parse(balance.balance);
        }
      }
      return 0.0;
    } catch (e) {
      print('Error getting group wallet balance: $e');
      return 0.0;
    }
  }

  Future<void> _contribute() async {
    if (_groupWallet == null) return;

    final amountController = TextEditingController();
    
    final amount = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: Text(
          'Contribute to ${_groupWallet!.name}',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Current: ${_adjustedCurrentAmount.toStringAsFixed(2)} XLM',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            Text(
              'Target: ${_groupWallet!.targetAmount.toStringAsFixed(2)} XLM',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: amountController,
              style: TextStyle(color: AppColors.textPrimary),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Amount (XLM)',
                hintText: '0.0',
                hintStyle: TextStyle(color: AppColors.textTertiary),
                labelStyle: TextStyle(color: AppColors.textSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.surfaceElevated),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primaryPurple, width: 2),
                ),
                filled: true,
                fillColor: AppColors.surfaceDark,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text.trim());
              if (amount != null && amount > 0) {
                Navigator.pop(context, amount);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
            ),
            child: const Text('Contribute', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (amount != null) {
      await _processContribution(amount);
    }
  }

  Future<void> _processContribution(double amount) async {
    try {
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      final activeWallet = walletProvider.activeWallet;
      
      if (activeWallet == null) {
        throw Exception('No active wallet found');
      }

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Processing contribution...',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
      );

      await GroupWalletService.contributeToGroupWallet(
        groupWalletId: widget.groupWalletId,
        contributorWalletName: activeWallet.name,
        amount: amount,
        contributorSecretKey: activeWallet.secretKey ?? '',
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        
        // Show success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Contribution of $amount XLM successful!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Reload data
        _loadGroupWallet();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _requestSpending() async {
    if (_groupWallet == null) return;

    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final activeWallet = walletProvider.activeWallet;
    
    if (activeWallet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active wallet found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if user can spend
    if (!_groupWallet!.canSpend(activeWallet.name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have spending permissions'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final addressController = TextEditingController();
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: Text(
          'Request Spending from ${_groupWallet!.name}',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Balance: ${_adjustedCurrentAmount.toStringAsFixed(2)} XLM',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              Text(
                'Required Signatures: ${_groupWallet!.settings.requiredSignatures}/${_groupWallet!.settings.totalSigners}',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: addressController,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Destination',
                  hintText: '@username or GABC123...',
                  hintStyle: TextStyle(color: AppColors.textTertiary),
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.surfaceElevated),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primaryPurple, width: 2),
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceDark,
                  helperText: 'Enter @walletname or Stellar address',
                  helperStyle: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                  prefixIcon: Icon(
                    addressController.text.startsWith('@') ? Icons.person : Icons.account_balance,
                    color: AppColors.primaryPurple,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: amountController,
                style: TextStyle(color: AppColors.textPrimary),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount (XLM)',
                  hintText: '0.0',
                  hintStyle: TextStyle(color: AppColors.textTertiary),
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.surfaceElevated),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primaryPurple, width: 2),
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceDark,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: descriptionController,
                style: TextStyle(color: AppColors.textPrimary),
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'What is this payment for?',
                  hintStyle: TextStyle(color: AppColors.textTertiary),
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.surfaceElevated),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primaryPurple, width: 2),
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceDark,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final address = addressController.text.trim();
              final amountText = amountController.text.trim();
              final description = descriptionController.text.trim();
              
              if (address.isEmpty || amountText.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter destination and amount'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              final amount = double.tryParse(amountText);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid amount'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              // Basic validation for @walletname or Stellar address
              if (address.startsWith('@')) {
                if (address.length < 2) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Wallet name cannot be empty'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
              } else {
                // Basic Stellar address validation (should start with G and be ~56 chars)
                if (!address.startsWith('G') || address.length < 50) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid Stellar address or @walletname'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
              }
              
              Navigator.pop(context, {
                'address': address,
                'amount': amount,
                'description': description,
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Request Spending', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != null) {
      await _processSpendingRequest(
        result['address'],
        result['amount'],
        result['description'],
      );
    }
  }

  Future<void> _processSpendingRequest(String originalAddress, double amount, String description) async {
    try {
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      final activeWallet = walletProvider.activeWallet;
      
      if (activeWallet == null) return;

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Resolving destination...',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
      );

      // Resolve @walletname to Stellar address if needed
      String resolvedAddress = originalAddress;
      String displayDestination = originalAddress;
      if (originalAddress.startsWith('@')) {
        final walletName = originalAddress.substring(1); // Remove @ prefix
        final walletInfo = await WalletRegistryService.getWalletInfo(walletName);
        final publicKey = walletInfo?.publicKey;
        
        if (publicKey == null) {
          if (mounted) {
            Navigator.pop(context); // Close loading dialog
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Wallet name "@$walletName" not found'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
        
        resolvedAddress = publicKey;
        
        // Update loading dialog
        if (mounted) {
          Navigator.pop(context); // Close current dialog
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              backgroundColor: AppColors.surfaceCard,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Creating spending request...',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'To: @$walletName',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }
      } else {
        // Update loading dialog for direct address
        if (mounted) {
          Navigator.pop(context); // Close current dialog
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              backgroundColor: AppColors.surfaceCard,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Creating spending request...',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          );
        }
      }

      await GroupWalletService.requestSpending(
        groupWalletId: widget.groupWalletId,
        requesterWalletName: activeWallet.name,
        recipientAddress: resolvedAddress,
        amount: amount,
        description: description,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        
        // Show success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Spending request created to $displayDestination! Needs ${_groupWallet!.settings.requiredSignatures} approvals.'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Reload data
        _loadGroupWallet();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Loading group wallet...',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundDark,
        appBar: AppBar(
          backgroundColor: AppColors.backgroundDark,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Group Wallet',
            style: TextStyle(color: AppColors.textPrimary),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text(
                'Error loading group wallet',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadGroupWallet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                ),
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    if (_groupWallet == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: Center(
          child: Text(
            'Group wallet not found',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                expandedHeight: 280,
                pinned: true,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    icon: Icon(Icons.refresh, color: AppColors.textPrimary),
                    onPressed: _loadGroupWallet,
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: _buildHeader(),
                ),
                bottom: TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primaryPurple,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primaryPurple,
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Members'),
                    Tab(text: 'Transactions'),
                    Tab(text: 'Pending'),
                    Tab(text: 'Completed'),
                    Tab(text: 'Settings'),
                  ],
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(),
              _buildMembersTab(),
              _buildTransactionsTab(),
              _buildPendingRequestsTab(),
              _buildCompletedRequestsTab(),
              _buildSettingsTab(),
            ],
          ),
        ),
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            onPressed: _requestSpending,
            backgroundColor: Colors.orange,
            heroTag: "spend",
            icon: const Icon(Icons.send, color: Colors.white),
            label: const Text('Spend', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 16),
          FloatingActionButton.extended(
            onPressed: _contribute,
            backgroundColor: AppColors.primaryPurple,
            heroTag: "contribute",
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Contribute', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final progress = _groupWallet!.targetAmount > 0 
        ? (_adjustedCurrentAmount / _groupWallet!.targetAmount).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _groupWallet!.name,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ).animate().slideX(duration: 600.ms).fadeIn(),
          
          const SizedBox(height: 8),
          
          Text(
            _groupWallet!.description,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.8),
            ),
          ).animate(delay: 200.ms).slideX(duration: 600.ms).fadeIn(),
          
          const SizedBox(height: 24),
          
          // Progress Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_adjustedCurrentAmount.toStringAsFixed(2)} XLM',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Target: ${_groupWallet!.targetAmount.toStringAsFixed(2)} XLM',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 8),
              
              Text(
                '${(progress * 100).toStringAsFixed(1)}% Complete',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ],
          ).animate(delay: 400.ms).slideY(begin: 0.3, duration: 600.ms).fadeIn(),
        ],
      ),
    );
  }

  Widget _buildCurrentBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryPurple, AppColors.primaryPurple.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FutureBuilder<double>(
        future: _getGroupWalletBalance(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.account_balance_wallet, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'Current Balance',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2,
                ),
              ],
            );
          }

          final balance = snapshot.data ?? 0.0;
          final hasError = snapshot.hasError;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    hasError ? Icons.error_outline : Icons.account_balance_wallet, 
                    color: Colors.white, 
                    size: 24
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Current Balance',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => setState(() {}), // Refresh balance
                    icon: Icon(Icons.refresh, color: Colors.white.withOpacity(0.8)),
                    tooltip: 'Refresh Balance',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                hasError ? 'Error loading balance' : '${balance.toStringAsFixed(7)} XLM',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!hasError) ...[
                const SizedBox(height: 4),
                Text(
                  'Live from Stellar Network',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Balance Card - Full Width
          _buildCurrentBalanceCard(),
          
          const SizedBox(height: 16),
          
          // Stats Cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Members',
                  '${_groupWallet!.members.length}',
                  Icons.group,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Contributions',
                  '${_groupWallet!.transactions.where((t) => t.type == GroupTransactionType.contribution).length}',
                  Icons.trending_up,
                  Colors.green,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Avg Contribution',
                  _groupWallet!.members.isNotEmpty 
                      ? '${(_adjustedCurrentAmount / _groupWallet!.members.length).toStringAsFixed(2)} XLM'
                      : '0 XLM',
                  Icons.analytics,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Days Left',
                  _groupWallet!.targetDate != null
                      ? '${_groupWallet!.targetDate!.difference(DateTime.now()).inDays}'
                      : 'No Limit',
                  Icons.timer,
                  Colors.purple,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Recent Activity
          Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          
          const SizedBox(height: 16),
          
          ..._groupWallet!.transactions
              .take(5)
              .map((transaction) => _buildTransactionItem(transaction)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceElevated),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    ).animate()
        .slideY(begin: 0.3, duration: 500.ms)
        .fadeIn(duration: 500.ms);
  }

  Widget _buildMembersTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Group Members (${_groupWallet!.members.length})',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          
          const SizedBox(height: 16),
          
          ...List.generate(_groupWallet!.members.length, (index) {
            final member = _groupWallet!.members[index];
            return _buildMemberItem(member, index);
          }),
        ],
      ),
    );
  }

  Widget _buildMemberItem(GroupWalletMember member, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceElevated),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primaryPurple.withOpacity(0.2),
            child: Text(
              member.walletName.substring(0, 1).toUpperCase(),
              style: TextStyle(
                color: AppColors.primaryPurple,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '@${member.walletName}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (member.role == GroupWalletRole.admin) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'ADMIN',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  'Contributed: ${member.totalContributions.toStringAsFixed(2)} XLM',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate(delay: (index * 100).ms)
        .slideX(begin: 0.3, duration: 500.ms)
        .fadeIn(duration: 500.ms);
  }

  Widget _buildTransactionsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transaction History',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          
          const SizedBox(height: 16),
          
          if (_groupWallet!.transactions.isEmpty)
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Icon(
                    Icons.receipt_long,
                    size: 64,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No transactions yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else
            ...List.generate(_groupWallet!.transactions.length, (index) {
              final transaction = _groupWallet!.transactions[index];
              return _buildTransactionItem(transaction);
            }),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(GroupWalletTransaction transaction) {
    final isContribution = transaction.type == GroupTransactionType.contribution;
    final isSpending = transaction.type == GroupTransactionType.spending;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceElevated),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isContribution ? Colors.green : isSpending ? Colors.red : Colors.blue)
                  .withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isContribution ? Icons.add : isSpending ? Icons.remove : Icons.pending,
              color: isContribution ? Colors.green : isSpending ? Colors.red : Colors.blue,
              size: 20,
            ),
          ),
          
          const SizedBox(width: 16),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isContribution 
                      ? 'Contribution by @${transaction.initiatorWalletName}'
                      : isSpending 
                          ? 'Spending: ${transaction.description}'
                          : 'Unknown transaction',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${transaction.timestamp.day}/${transaction.timestamp.month}/${transaction.timestamp.year}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (transaction.status == GroupTransactionStatus.pending)
                  Text(
                    'Pending approval',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          
          Text(
            '${isContribution ? '+' : '-'}${transaction.amount.toStringAsFixed(2)} XLM',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isContribution ? Colors.green : isSpending ? Colors.red : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Group Wallet Settings',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          
          const SizedBox(height: 24),
          
          _buildSettingItem(
            'Multi-Signature Rules',
            'Spending requires ${_groupWallet!.requiredSignatures}/${_groupWallet!.members.length} approvals',
            Icons.security,
            () {
              // TODO: Implement signature rules editing
            },
          ),
          
          _buildSettingItem(
            'Target Amount',
            '${_groupWallet!.targetAmount.toStringAsFixed(2)} XLM',
            Icons.savings,
            () {
              // TODO: Implement target amount editing
            },
          ),
          
          if (_groupWallet!.targetDate != null)
            _buildSettingItem(
              'Target Date',
              '${_groupWallet!.targetDate!.day}/${_groupWallet!.targetDate!.month}/${_groupWallet!.targetDate!.year}',
              Icons.calendar_today,
              () {
                // TODO: Implement target date editing
              },
            ),
          
          _buildSettingItem(
            'Stellar Account',
            _groupWallet!.stellarAccountId,
            Icons.account_balance_wallet,
            () {
              // TODO: Show account details
            },
          ),
          
          const SizedBox(height: 32),
          
          // Danger Zone
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Danger Zone',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'These actions cannot be undone.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      // TODO: Implement leave group wallet
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: const Text(
                      'Leave Group Wallet',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primaryPurple),
        title: Text(
          title,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        trailing: Icon(Icons.chevron_right, color: AppColors.textSecondary),
        onTap: onTap,
        tileColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildPendingRequestsTab() {
    return Container(
      color: AppColors.backgroundDark,
      child: FutureBuilder<List<SpendingRequest>>(
        key: ValueKey(DateTime.now().millisecondsSinceEpoch), // Force rebuild on state changes
        future: SpendingRequestService.getPendingSpendingRequests(widget.groupWalletId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryPurple,
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading pending requests',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final pendingRequests = snapshot.data ?? [];

          if (pendingRequests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: AppColors.success,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Pending Requests',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'All spending requests have been processed',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pendingRequests.length,
            itemBuilder: (context, index) {
              final request = pendingRequests[index];
              return _buildPendingRequestCard(request);
            },
          );
        },
      ),
    );
  }

  Widget _buildPendingRequestCard(SpendingRequest request) {
    final currentUserWalletName = Provider.of<WalletProvider>(context).activeWallet?.name;
    final canVote = currentUserWalletName != null && 
                   request.canUserVote(currentUserWalletName) &&
                   currentUserWalletName != request.requesterWalletName;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: request.isPending ? AppColors.warning : AppColors.surfaceCard,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.pending_actions,
                  color: AppColors.warning,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Spending Request',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'PENDING',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Request Details
            _buildRequestDetail('From', request.requesterWalletName, Icons.person),
            _buildRequestDetail('To', request.recipientAddress, Icons.account_balance_wallet),
            _buildRequestDetail('Amount', '${request.amount.toStringAsFixed(2)} XLM', Icons.monetization_on),
            if (request.description.isNotEmpty)
              _buildRequestDetail('Description', request.description, Icons.description),
            
            const SizedBox(height: 16),

            // Approval Status
            Row(
              children: [
                Icon(
                  Icons.how_to_vote,
                  color: AppColors.primaryPurple,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Approvals: ${_getEffectiveApprovalCount(request)}/${request.requiredSignatures}',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            
            if (request.approvedBy.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: request.approvedBy.map((approver) => 
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      approver,
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ).toList(),
              ),
            ],

            // Action Buttons
            if (canVote) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approveSpendingRequest(request.id, true),
                      icon: const Icon(Icons.check, color: Colors.white),
                      label: const Text('Approve', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approveSpendingRequest(request.id, false),
                      icon: const Icon(Icons.close, color: Colors.white),
                      label: const Text('Reject', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (currentUserWalletName == request.requesterWalletName) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'You created this request',
                  style: TextStyle(
                    color: AppColors.primaryPurple,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ] else if (!canVote && request.hasUserApproved(currentUserWalletName ?? '')) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: AppColors.success, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'You approved this request',
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (!canVote && request.hasUserRejected(currentUserWalletName ?? '')) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cancel, color: AppColors.error, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'You rejected this request',
                      style: TextStyle(
                        color: AppColors.error,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            Text(
              'Created: ${_formatDate(request.createdAt)}',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildRequestDetail(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryPurple, size: 18),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approveSpendingRequest(String requestId, bool approve) async {
    final currentUserWalletName = Provider.of<WalletProvider>(context, listen: false).activeWallet?.name;
    
    if (currentUserWalletName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No wallet selected'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primaryPurple),
              const SizedBox(height: 16),
              Text(
                approve ? 'Approving request...' : 'Rejecting request...',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
      );

      final success = await SpendingRequestService.approveSpendingRequest(
        requestId,
        currentUserWalletName,
        approve,
      );

      Navigator.of(context).pop(); // Close loading dialog

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve ? 'Request approved successfully' : 'Request rejected successfully'),
            backgroundColor: approve ? AppColors.success : AppColors.warning,
          ),
        );
        // Reload data to reflect status changes
        await _loadGroupWallet();
        setState(() {
          // Force rebuild of the pending requests tab
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${approve ? 'approve' : 'reject'} request'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _buildCompletedRequestsTab() {
    return Container(
      color: AppColors.backgroundDark,
      child: FutureBuilder<List<SpendingRequest>>(
        key: ValueKey(DateTime.now().millisecondsSinceEpoch), // Force rebuild on state changes
        future: SpendingRequestService.getCompletedSpendingRequests(widget.groupWalletId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryPurple,
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading completed requests',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }

          final completedRequests = snapshot.data ?? [];

          if (completedRequests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Completed Transfers',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Completed transfers will appear here',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: completedRequests.length,
            itemBuilder: (context, index) {
              final request = completedRequests[index];
              return _buildCompletedRequestCard(request);
            },
          );
        },
      ),
    );
  }

  Widget _buildCompletedRequestCard(SpendingRequest request) {
    final bool isSuccess = request.isCompleted;
    final Color statusColor = isSuccess ? AppColors.success : AppColors.error;
    final IconData statusIcon = isSuccess ? Icons.check_circle : Icons.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  statusIcon,
                  color: statusColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isSuccess ? 'Transfer Completed' : 'Transfer Failed',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isSuccess ? 'COMPLETED' : 'FAILED',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Transfer Details
            _buildRequestDetail('From', request.requesterWalletName, Icons.person),
            _buildRequestDetail('To', request.recipientAddress, Icons.account_balance_wallet),
            _buildRequestDetail('Amount', '${request.amount.toStringAsFixed(2)} XLM', Icons.monetization_on),
            if (request.description.isNotEmpty)
              _buildRequestDetail('Description', request.description, Icons.description),
            
            const SizedBox(height: 16),

            // Approval Summary
            Row(
              children: [
                Icon(
                  Icons.how_to_vote,
                  color: AppColors.primaryPurple,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Final Approvals: ${request.approvedBy.length}/${request.requiredSignatures}',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            if (request.approvedBy.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: request.approvedBy.map((approver) => 
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      approver,
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ).toList(),
              ),
            ],

            const SizedBox(height: 16),

            // Transaction Info
            if (isSuccess && request.transactionHash != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.success.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.link, color: AppColors.success, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Transaction Hash',
                          style: TextStyle(
                            color: AppColors.success,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      request.transactionHash!,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (!isSuccess && request.errorMessage != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.error.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.error_outline, color: AppColors.error, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Error Message',
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      request.errorMessage!,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Timestamps
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Created: ${_formatDate(request.createdAt)}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                if (request.completedAt != null)
                  Text(
                    'Completed: ${_formatDate(request.completedAt!)}',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// Calculate effective approval count including request creator
  int _getEffectiveApprovalCount(SpendingRequest request) {
    Set<String> effectiveApprovals = Set.from(request.approvedBy);
    // Request creator automatically approves their own request
    if (request.requesterWalletName.isNotEmpty) {
      effectiveApprovals.add(request.requesterWalletName);
    }
    return effectiveApprovals.length;
  }
}