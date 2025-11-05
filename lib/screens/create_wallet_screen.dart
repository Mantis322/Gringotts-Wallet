import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../app/theme/colors.dart';
import '../app/routes.dart';
import '../providers/wallet_provider.dart';
import '../widgets/custom_button.dart';
import '../widgets/wallet_card.dart';
import '../services/storage_service.dart';
import 'backup_mnemonic_screen.dart';

/// Create Wallet Screen
/// Premium wallet creation interface with gradient background
class CreateWalletScreen extends StatefulWidget {
  const CreateWalletScreen({super.key});

  @override
  State<CreateWalletScreen> createState() => _CreateWalletScreenState();
}

class _CreateWalletScreenState extends State<CreateWalletScreen> {
  final TextEditingController _secretKeyController = TextEditingController();
  bool _isCreatingWallet = false;
  bool _isImportingWallet = false;
  bool _showImportSection = false;

  @override
  void initState() {
    super.initState();
    _markFirstLaunchComplete();
  }

  Future<void> _markFirstLaunchComplete() async {
    await StorageService.saveFirstLaunchStatus(false);
  }

  Future<void> _createNewWallet() async {
    setState(() => _isCreatingWallet = true);
    
    try {
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      final success = await walletProvider.createWallet();
      
      if (success && mounted) {
        // Mnemonic'i al ve backup ekranını göster
        final mnemonic = walletProvider.wallet?.mnemonic?.split(' ') ?? [];
        if (mnemonic.isNotEmpty) {
          _showBackupMnemonicScreen(mnemonic);
        } else {
          _navigateToHome();
        }
      } else if (mounted) {
        _showErrorDialog('Failed to create wallet. Please try again.');
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Error creating wallet: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isCreatingWallet = false);
      }
    }
  }

  void _showBackupMnemonicScreen(List<String> mnemonic) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BackupMnemonicScreen(
          mnemonic: mnemonic,
          onContinue: () {
            Navigator.of(context).pop();
            _navigateToHome();
          },
        ),
      ),
    );
  }

  Future<void> _importWallet() async {
    if (_secretKeyController.text.trim().isEmpty) {
      _showErrorDialog('Please enter a secret key');
      return;
    }

    setState(() => _isImportingWallet = true);
    
    try {
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      final success = await walletProvider.importWallet(_secretKeyController.text.trim());
      
      if (success && mounted) {
        _navigateToHome();
      } else if (mounted) {
        _showErrorDialog('Failed to import wallet. Please check your secret key.');
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Error importing wallet: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isImportingWallet = false);
      }
    }
  }

  void _navigateToHome() {
    AppRoutes.pushAndClearStack(context, AppRoutes.home);
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Error',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          message,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: TextStyle(color: AppColors.primaryPurple),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _secretKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      const SizedBox(height: 32),
                      _buildWelcomeSection(),
                      const SizedBox(height: 40),
                      _buildWalletOptions(),
                      if (_showImportSection) ...[
                        const SizedBox(height: 32),
                        _buildImportSection(),
                      ],
                      const SizedBox(height: 32),
                      _buildSecurityNote(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => AppRoutes.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          Text(
            'Stellar Wallet',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48), // Balance the back button
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryPurple.withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.account_balance_wallet,
            color: AppColors.textPrimary,
            size: 40,
          ),
        ).animate(delay: 200.ms)
            .scale(duration: 600.ms, curve: Curves.elasticOut)
            .then()
            .shimmer(duration: 2000.ms, color: AppColors.accentGold.withOpacity(0.3)),

        const SizedBox(height: 24),

        Text(
          'Welcome to Stellar',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ).animate(delay: 400.ms)
            .slideY(begin: 0.3, duration: 600.ms)
            .fadeIn(duration: 600.ms),

        const SizedBox(height: 12),

        Text(
          'Choose how you\'d like to get started with your Stellar wallet',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppColors.textSecondary,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ).animate(delay: 600.ms)
            .slideY(begin: 0.3, duration: 600.ms)
            .fadeIn(duration: 600.ms),
      ],
    );
  }

  Widget _buildWalletOptions() {
    return Column(
      children: [
        WalletCard(
          title: 'Create New Wallet',
          description: 'Generate a new wallet with secure backup phrase',
          icon: Icons.add_circle_outline,
          isRecommended: true,
          onTap: _createNewWallet,
        ).animate(delay: 800.ms),

        const SizedBox(height: 16),

        WalletCard(
          title: 'Import Existing Wallet',
          description: 'Restore your wallet using secret key',
          icon: Icons.file_download_outlined,
          onTap: () {
            setState(() => _showImportSection = !_showImportSection);
          },
        ).animate(delay: 1000.ms),

        if (_isCreatingWallet || _isImportingWallet)
          Container(
            margin: const EdgeInsets.only(top: 24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard.withOpacity(0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              children: [
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
                const SizedBox(width: 12),
                Text(
                  _isCreatingWallet 
                      ? 'Creating your wallet...' 
                      : 'Importing wallet...',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ).animate(delay: 200.ms)
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.2, duration: 400.ms),
      ],
    );
  }

  Widget _buildImportSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowMedium,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Import Wallet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 16),

          Text(
            'Enter your Stellar secret key to restore your wallet',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: 20),

          TextField(
            controller: _secretKeyController,
            decoration: InputDecoration(
              labelText: 'Secret Key',
              hintText: 'S...',
              prefixIcon: Icon(
                Icons.vpn_key,
                color: AppColors.textTertiary,
              ),
            ),
            style: TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'monospace',
            ),
            obscureText: true,
            maxLines: 1,
          ),

          const SizedBox(height: 24),

          CustomButton(
            text: 'Import Wallet',
            onPressed: _importWallet,
            isLoading: _isImportingWallet,
            icon: Icon(Icons.file_download),
          ),
        ],
      ),
    ).animate(delay: 300.ms)
        .slideY(begin: 0.3, duration: 600.ms)
        .fadeIn(duration: 600.ms);
  }

  Widget _buildSecurityNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warningOrange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warningOrange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.security,
            color: AppColors.warningOrange,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your keys are stored securely on your device and never shared with our servers.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    ).animate(delay: 1200.ms)
        .slideY(begin: 0.3, duration: 600.ms)
        .fadeIn(duration: 600.ms);
  }
}