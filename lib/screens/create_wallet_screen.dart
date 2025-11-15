import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../app/theme/colors.dart';
import '../app/routes.dart';
import '../providers/wallet_provider.dart';
import '../widgets/custom_button.dart';
import '../widgets/wallet_card.dart';
import '../services/storage_service.dart';
import '../services/wallet_registry_service.dart';
import 'backup_secret_key_screen.dart';

/// Create Wallet Screen
/// Premium wallet creation interface with gradient background
class CreateWalletScreen extends StatefulWidget {
  const CreateWalletScreen({super.key});

  @override
  State<CreateWalletScreen> createState() => _CreateWalletScreenState();
}

class _CreateWalletScreenState extends State<CreateWalletScreen> {
  final TextEditingController _secretKeyController = TextEditingController();
  final TextEditingController _walletNameController = TextEditingController(text: 'My Wallet');
  final TextEditingController _importNameController = TextEditingController(text: 'Imported Wallet');
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
    final walletName = _walletNameController.text.trim();
    if (walletName.isEmpty) {
      _showSnackBar('Please enter a wallet name', Colors.red);
      return;
    }

    // Validate wallet name format
    final validation = WalletRegistryService.validateWalletName(walletName);
    if (!validation.isValid) {
      _showSnackBar(validation.error ?? 'Invalid wallet name', Colors.red);
      return;
    }

    setState(() => _isCreatingWallet = true);
    
    try {
      // Check if wallet name is available
      final isAvailable = await WalletRegistryService.isWalletNameAvailable(walletName);
      if (!isAvailable) {
        setState(() => _isCreatingWallet = false);
        _showSnackBar('Wallet name "$walletName" is already taken', Colors.red);
        return;
      }

      // Show loading feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              Text('Creating your wallet...'),
            ],
          ),
          backgroundColor: AppColors.primaryPurple,
          duration: Duration(seconds: 5),
        ),
      );
      
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      final success = await walletProvider.createWallet(name: walletName);
      
      if (success && mounted) {
        // Close loading dialog
        Navigator.pop(context);
        
        final wallet = walletProvider.wallet;
        if (wallet != null) {
          try {
            // Register wallet name in Firebase
            await WalletRegistryService.registerWalletName(
              walletName: walletName,
              publicKey: wallet.publicKey,
              displayName: walletName,
            );
            
            _showSnackBar('Wallet created and registered successfully!', AppColors.primaryPurple);
          } catch (e) {
            // Wallet created but registration failed - still show backup
            _showSnackBar('Wallet created but name registration failed: $e', Colors.orange);
          }
          
          // Secret key'i al ve backup ekranını göster
          final secretKey = wallet.secretKey ?? '';
          if (secretKey.isNotEmpty) {
            _showBackupSecretKeyScreen(secretKey);
          } else {
            _navigateToHome();
          }
        } else {
          _navigateToHome();
        }
      } else if (mounted) {
        _showSnackBar('Failed to create wallet: ${walletProvider.error ?? 'Unknown error'}', Colors.red);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error creating wallet: $e', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() => _isCreatingWallet = false);
      }
    }
  }

  void _showBackupSecretKeyScreen(String secretKey) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BackupSecretKeyScreen(
          secretKey: secretKey,
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

    final walletName = _importNameController.text.trim();
    if (walletName.isEmpty) {
      _showSnackBar('Please enter a wallet name', Colors.red);
      return;
    }

    // Validate wallet name format
    final validation = WalletRegistryService.validateWalletName(walletName);
    if (!validation.isValid) {
      _showSnackBar(validation.error ?? 'Invalid wallet name', Colors.red);
      return;
    }

    setState(() => _isImportingWallet = true);
    
    try {
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      
      // Check if this secret key is already imported
      final secretKey = _secretKeyController.text.trim();
      final existingWallet = walletProvider.wallets.where(
        (wallet) => wallet.secretKey == secretKey
      ).firstOrNull;
      
      if (existingWallet != null) {
        setState(() => _isImportingWallet = false);
        _showDuplicateWalletWarning(existingWallet.name);
        return;
      }
      
      // Check if wallet name is available
      final isAvailable = await WalletRegistryService.isWalletNameAvailable(walletName);
      if (!isAvailable) {
        _showSnackBar('Wallet name "$walletName" is already taken', Colors.red);
        return;
      }

      // Show loading feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              Text('Importing your wallet...'),
            ],
          ),
          backgroundColor: AppColors.primaryPurple,
          duration: Duration(seconds: 5),
        ),
      );
      
      final success = await walletProvider.importWalletFromSecretKey(
        secretKey: _secretKeyController.text.trim(),
        name: walletName,
        setAsActive: true,
      );
      
      if (success && mounted) {
        final wallet = walletProvider.wallet;
        if (wallet != null) {
          try {
            // Register wallet name in Firebase
            await WalletRegistryService.registerWalletName(
              walletName: walletName,
              publicKey: wallet.publicKey,
              displayName: walletName,
            );
            
            _showSnackBar('Wallet imported and registered successfully!', AppColors.primaryPurple);
          } catch (e) {
            // Wallet imported but registration failed
            _showSnackBar('Wallet imported but name registration failed: $e', Colors.orange);
          }
        }
        
        _navigateToHome();
      } else if (mounted) {
        _showSnackBar('Failed to import wallet. Please check your secret key.', Colors.red);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error importing wallet: $e', Colors.red);
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

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _secretKeyController.dispose();
    _walletNameController.dispose();
    _importNameController.dispose();
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
          'Welcome to Gringotts',
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
          'Choose how you\'d like to get started with your magical vault',
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
        // Wallet Name Input
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Wallet Name',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _walletNameController,
                decoration: InputDecoration(
                  hintText: 'Enter wallet name (3-20 chars, letters, numbers, _)',
                  hintStyle: TextStyle(color: AppColors.textSecondary),
                  helperText: 'This name will be registered globally as @${_walletNameController.text.isEmpty ? 'walletname' : _walletNameController.text}',
                  helperStyle: TextStyle(color: AppColors.textTertiary, fontSize: 11),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.borderLight),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primaryPurple),
                  ),
                  filled: true,
                  fillColor: AppColors.backgroundDark,
                ),
                style: TextStyle(color: AppColors.textPrimary),
                onChanged: (value) => setState(() {}), // Update helper text
              ),
            ],
          ),
        ).animate(delay: 600.ms),

        const SizedBox(height: 20),

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
            controller: _importNameController,
            decoration: InputDecoration(
              labelText: 'Wallet Name',
              hintText: 'Enter a name for this wallet (3-20 chars)',
              helperText: 'This name will be registered globally as @${_importNameController.text.isEmpty ? 'walletname' : _importNameController.text}',
              helperStyle: TextStyle(color: AppColors.textTertiary, fontSize: 11),
              labelStyle: TextStyle(color: AppColors.textSecondary),
              hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.7)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.borderLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primaryPurple),
              ),
              prefixIcon: Icon(Icons.label_outline, color: AppColors.primaryPurple),
            ),
            style: TextStyle(color: AppColors.textPrimary),
            onChanged: (value) => setState(() {}), // Update helper text
          ),

          const SizedBox(height: 16),

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

  void _showDuplicateWalletWarning(String existingWalletName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Wallet Already Exists',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This wallet is already imported in your active wallets.',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primaryPurple.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.account_balance_wallet, 
                       color: AppColors.primaryPurple, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Existing Wallet: $existingWalletName',
                      style: TextStyle(
                        color: AppColors.textPrimary, 
                        fontWeight: FontWeight.w600
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You can switch to this wallet from the home screen wallet selector.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(color: AppColors.primaryPurple),
            ),
          ),
        ],
      ),
    );
  }
}