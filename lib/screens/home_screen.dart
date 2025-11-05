import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../app/theme/colors.dart';
import '../app/routes.dart';
import '../providers/wallet_provider.dart';
import '../widgets/balance_card.dart';
import '../widgets/wallet_card.dart';
import '../widgets/custom_button.dart';

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
    }
  }

  Future<void> _refreshWallet() async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    await walletProvider.refreshBalance();
    await walletProvider.loadTransactionHistory();
  }

  void _navigateToSend() {
    AppRoutes.push(context, AppRoutes.send);
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
                          _buildBalanceSection(walletProvider),
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
          Container(
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet,
              size: 80,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 24),
            Text(
              'No Wallet Found',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Create or import a wallet to get started',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            CustomButton(
              text: 'Create Wallet',
              onPressed: () => AppRoutes.push(context, AppRoutes.createWallet),
              icon: Icon(Icons.add),
            ),
          ],
        ),
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
        title: Text(
          'Stellar Wallet',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
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

  Widget _buildBalanceSection(WalletProvider walletProvider) {
    return BalanceCard(
      wallet: walletProvider.wallet,
      isLoading: walletProvider.isLoading,
      onRefresh: _refreshWallet,
      onCopyAddress: () {
        // Handle copy address action
      },
    ).animate(delay: 200.ms)
        .slideY(begin: 0.3, duration: 600.ms)
        .fadeIn(duration: 600.ms);
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
                  icon: Icons.send,
                  title: 'Send',
                  subtitle: 'Transfer XLM',
                  onTap: _navigateToSend,
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
                  subtitle: 'Show QR Code',
                  onTap: () {
                    // TODO: Implement QR code functionality
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('QR Code feature coming soon'),
                        backgroundColor: AppColors.secondaryBlue,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  },
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
              final transaction = walletProvider.transactions[index];
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