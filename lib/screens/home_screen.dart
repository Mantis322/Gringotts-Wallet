import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../app/theme/colors.dart';
import '../app/routes.dart';
import '../providers/wallet_provider.dart';
import '../services/wallet_registry_service.dart';
import '../widgets/balance_card.dart';
import '../widgets/wallet_card.dart';
import '../widgets/payment_options_modal.dart';
import '../widgets/receive_options_modal.dart';
import '../widgets/wallet_selector.dart';
import '../widgets/wallet_name_setup_dialog.dart';

/// Home Screen
/// Main wallet dashboard with balance, transactions and quick actions
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _initializeWallet();
  }

  Future<void> _initializeWallet() async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    await walletProvider.initialize();
    
    // If no wallet exists, navigate to create wallet
    if (!walletProvider.hasWallet && mounted) {
      AppRoutes.pushReplacement(context, AppRoutes.createWallet);
      return;
    }
    
    // Check if existing wallet needs Firebase registration
    if (walletProvider.hasWallet && mounted) {
      // First try to load existing display names from Firebase
      await walletProvider.refreshWalletDisplayNames();
      
      // Refresh balance and transactions when home screen loads
      await walletProvider.refreshBalance();
      
      // Then check if any wallet needs registration
      await _checkWalletRegistration(walletProvider);
    }
  }

  Future<void> _checkWalletRegistration(WalletProvider walletProvider) async {
    try {
      final currentWallet = walletProvider.wallet;
      if (currentWallet == null) return;

      final needsRegistration = await WalletRegistryService.doesWalletNeedRegistration(
        currentWallet.publicKey,
      );

      if (needsRegistration && mounted) {
        // Show the setup dialog
        showDialog(
          context: context,
          barrierDismissible: false, // Force user to make a choice
          builder: (context) => WalletNameSetupDialog(
            publicKey: currentWallet.publicKey,
            currentWalletName: currentWallet.name,
            onCompleted: () {
              // Refresh wallet provider to get updated display name
              walletProvider.refreshWalletDisplayNames();
            },
          ),
        );
      }
    } catch (e) {
      // If there's an error, we can silently continue
      // The user can still use the app normally
      debugPrint('Error checking wallet registration: $e');
    }
  }

  Future<void> _refreshWallet() async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    await walletProvider.refreshBalance();
    await walletProvider.loadTransactions();
  }

  void _showPaymentOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PaymentOptionsModal(),
    );
  }

  void _showReceiveOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ReceiveOptionsModal(),
    );
  }

  void _navigateToSettings() {
    AppRoutes.push(context, AppRoutes.settings);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Consumer<WalletProvider>(
            builder: (context, walletProvider, child) {
              if (!walletProvider.isInitialized) {
                return _buildLoadingState();
              }

              if (!walletProvider.hasWallet) {
                return _buildNoWalletState();
              }

              return RefreshIndicator(
                onRefresh: _refreshWallet,
                backgroundColor: AppColors.surfaceCard,
                color: AppColors.primaryPurple,
                child: CustomScrollView(
                  slivers: [
                    _buildAppBar(),
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          _buildWalletSection(walletProvider),
                          const SizedBox(height: 24),
                          _buildQuickActions(),
                          const SizedBox(height: 32),
                          _buildTransactionHistory(walletProvider),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.primaryPurple,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Initializing wallet...',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoWalletState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: WalletSelector(),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 80,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/gringotts_logo.png',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Gringotts Wallet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          onPressed: _navigateToSettings,
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.glassLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Icon(
              Icons.settings,
              color: AppColors.textPrimary,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildWalletSection(WalletProvider walletProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Wallet Selector
          const WalletSelector().animate(delay: 200.ms)
              .slideY(begin: 0.3, duration: 600.ms)
              .fadeIn(duration: 600.ms),
          
          const SizedBox(height: 16),
          
          // Balance Card (existing functionality)
          BalanceCard(
            wallet: walletProvider.wallet,
            isLoading: walletProvider.isLoading,
            onRefresh: _refreshWallet,
            onCopyAddress: () {
              // Handle copy address action
            },
          ).animate(delay: 400.ms)
              .slideY(begin: 0.3, duration: 600.ms)
              .fadeIn(duration: 600.ms),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ).animate(delay: 400.ms)
              .slideX(begin: 0.3, duration: 600.ms)
              .fadeIn(duration: 600.ms),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: QuickActionCard(
                  icon: Icons.payment,
                  title: 'Make a Payment',
                  subtitle: 'Multiple options',
                  onTap: _showPaymentOptions,
                  gradient: AppColors.primaryGradient,
                ).animate(delay: 600.ms)
                    .slideY(begin: 0.3, duration: 500.ms)
                    .fadeIn(duration: 500.ms),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: QuickActionCard(
                  icon: Icons.qr_code_scanner,
                  title: 'Receive',
                  subtitle: 'Multiple options',
                  onTap: _showReceiveOptions,
                  gradient: AppColors.accentGradient,
                ).animate(delay: 800.ms)
                    .slideY(begin: 0.3, duration: 500.ms)
                    .fadeIn(duration: 500.ms),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionHistory(WalletProvider walletProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Transactions',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (walletProvider.isLoadingTransactions)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primaryPurple,
                    ),
                  ),
                ),
            ],
          ),
        ).animate(delay: 1000.ms)
            .slideX(begin: 0.3, duration: 600.ms)
            .fadeIn(duration: 600.ms),

        const SizedBox(height: 16),

        if (walletProvider.transactions.isEmpty && !walletProvider.isLoadingTransactions)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(
                  Icons.history,
                  size: 48,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No transactions yet',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your transaction history will appear here',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textTertiary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ).animate(delay: 1200.ms)
              .slideY(begin: 0.3, duration: 600.ms)
              .fadeIn(duration: 600.ms)
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: walletProvider.transactions.length,
            itemBuilder: (context, index) {
              // Reverse the list so newest transactions appear first
              final reversedIndex = walletProvider.transactions.length - 1 - index;
              final transaction = walletProvider.transactions[reversedIndex];
              return TransactionCard(
                hash: transaction.shortHash,
                type: transaction.type.name,
                amount: transaction.displayAmount,
                date: _formatDate(transaction.createdAt),
                isIncoming: transaction.isIncoming,
                onTap: () {
                  // TODO: Show transaction details
                },
              ).animate(delay: Duration(milliseconds: 1200 + (index * 100)))
                  .slideX(begin: 0.3, duration: 400.ms)
                  .fadeIn(duration: 400.ms);
            },
          ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}