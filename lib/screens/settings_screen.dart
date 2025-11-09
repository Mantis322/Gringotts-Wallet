import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../app/theme/colors.dart';
import '../app/routes.dart';
import '../app/constants.dart';
import '../models/wallet_model.dart';
import '../providers/wallet_provider.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import '../services/wallet_registry_service.dart';
import 'pin_setup_screen.dart';
import 'pin_unlock_screen.dart';
import 'debug_auth_screen.dart';

/// Settings Screen
/// Wallet configuration and management interface
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedNetwork = AppConstants.networkTestnet;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final selectedNetwork = await StorageService.getSelectedNetwork();

    setState(() {
      _selectedNetwork = selectedNetwork;
    });
  }

  Future<void> _toggleBiometric(bool value) async {
    try {
      if (value) {
        // Check if biometric is available
        final isAvailable = await AuthService.isBiometricAvailable();
        if (!isAvailable) {
          _showErrorSnackbar('Biometric authentication is not available on this device');
          return;
        }
        
        // Test biometric authentication before enabling
        final success = await AuthService.authenticateWithBiometric(
          localizedReason: 'Enable biometric authentication for Gringotts Wallet',
        );
        
        if (!success) {
          _showErrorSnackbar('Biometric authentication failed');
          return;
        }
      }
      
      await AuthService.setBiometricEnabled(value);
      
      debugPrint('Settings: Biometric enabled set to $value');
      
      if (mounted) {
        setState(() {}); // Trigger rebuild
        debugPrint('Settings: setState called after setBiometricEnabled');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value 
                  ? 'Biometric authentication enabled' 
                  : 'Biometric authentication disabled',
            ),
            backgroundColor: AppColors.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      _showErrorSnackbar('Failed to update biometric settings');
    }
  }

  Future<void> _toggleAuthRequired(bool value) async {
    try {
      if (value) {
        // Ensure at least one authentication method is available
        final authMethods = await AuthService.getAuthenticationMethods();
        if (!authMethods.hasAnyMethod) {
          _showErrorSnackbar('Please setup PIN or biometric authentication first');
          return;
        }
      }
      
      await AuthService.setAuthRequired(value);
      
      if (mounted) {
        setState(() {}); // Trigger rebuild
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value 
                  ? 'Authentication required enabled' 
                  : 'Authentication required disabled',
            ),
            backgroundColor: AppColors.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      _showErrorSnackbar('Failed to update authentication settings');
    }
  }

  Future<void> _handlePinSetup(bool isChanging) async {
    if (isChanging) {
      // Show PIN unlock first, then setup
      final unlockResult = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => PinUnlockScreen(
            title: 'Verify Current PIN',
            subtitle: 'Enter your current PIN to change it',
            canUseBiometric: false,
          ),
        ),
      );
      
      if (unlockResult != true) return;
    }
    
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => PinSetupScreen(
          isChangingPin: isChanging,
          onSuccess: () {
            if (mounted) {
              setState(() {}); // Trigger rebuild
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isChanging ? 'PIN changed successfully' : 'PIN setup completed',
                  ),
                  backgroundColor: AppColors.successGreen,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
    
    if (result == true && mounted) {
      setState(() {}); // Trigger rebuild to update UI
    }
  }

  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _switchNetwork(String network) async {
    if (network == _selectedNetwork) return;

    final confirmed = await _showNetworkSwitchDialog(network);
    if (!confirmed) return;

    setState(() => _selectedNetwork = network);
    
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    await walletProvider.switchNetwork(network);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Switched to ${network.toUpperCase()}'),
          backgroundColor: AppColors.successGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<bool> _showNetworkSwitchDialog(String network) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Switch Network',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to switch to ${network.toUpperCase()}? This will reload your wallet data.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Switch'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _clearWallet() async {
    final confirmed = await _showClearWalletDialog();
    if (!confirmed) return;

    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    await walletProvider.clearAllWallets();

    if (mounted) {
      AppRoutes.pushAndClearStack(context, AppRoutes.onboarding);
    }
  }

  Future<bool> _showClearWalletDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Clear Wallet',
          style: TextStyle(color: AppColors.errorRed),
        ),
        content: Text(
          'This will permanently remove your wallet from this device. Make sure you have backed up your secret key before proceeding.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Clear Wallet'),
          ),
        ],
      ),
    ) ?? false;
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
              _buildAppBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildWalletSection(),
                      const SizedBox(height: 24),
                      _buildPreferencesSection(),
                      const SizedBox(height: 24),
                      _buildSecuritySection(),
                      const SizedBox(height: 24),
                      _buildAboutSection(),
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

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => AppRoutes.pop(context),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.glassLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Icon(
                Icons.arrow_back_ios,
                color: AppColors.textPrimary,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Settings',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletSection() {
    return Consumer<WalletProvider>(
      builder: (context, walletProvider, child) {
        return _buildSection(
          title: 'Wallet',
          icon: Icons.account_balance_wallet,
          children: [
            if (walletProvider.hasActiveWallet) ...[
              _buildInfoTile(
                'Active Wallet',
                _getWalletDisplayName(walletProvider, walletProvider.activeWallet!),
                subtitle: '${walletProvider.activeWallet?.publicKey.substring(0, 8)}...${walletProvider.activeWallet?.publicKey.substring(walletProvider.activeWallet!.publicKey.length - 8)}',
                iconData: Icons.account_balance_wallet,
              ),
              _buildListTile(
                'Manage Wallets',
                'Rename, delete, or export wallets',
                Icons.manage_accounts,
                onTap: () => _showWalletManagement(),
              ),
            ],
            _buildInfoTile(
              'Network',
              walletProvider.selectedNetwork.toUpperCase(),
              subtitle: walletProvider.isTestnet 
                  ? 'Test network for development'
                  : 'Live Stellar network',
              iconData: Icons.public,
            ),
            _buildListTile(
              'Switch Network',
              'Change between testnet and mainnet',
              Icons.swap_horiz,
              onTap: () => _showNetworkSelector(),
            ),
            _buildListTile(
              'Clear All Wallets',
              'Remove all wallets from this device',
              Icons.delete_outline,
              onTap: _clearWallet,
              isDestructive: true,
            ),
          ],
        );
      },
    ).animate(delay: 200.ms)
        .slideY(begin: 0.3, duration: 600.ms)
        .fadeIn(duration: 600.ms);
  }

  Widget _buildPreferencesSection() {
    // Theme section removed - app uses single dark theme
    return const SizedBox.shrink();
  }

  Widget _buildSecuritySection() {
    return FutureBuilder<AuthenticationMethods>(
      future: AuthService.getAuthenticationMethods(),
      builder: (context, snapshot) {
        final authMethods = snapshot.data;
        
        return _buildSection(
          title: 'Security',
          icon: Icons.security,
          children: [
            // Always show biometric option for testing
            _buildSwitchTile(
              'Biometric Authentication',
              authMethods?.biometricAvailable == true 
                ? 'Use fingerprint or face ID'
                : 'Biometric not available on this device',
              Icons.fingerprint,
              authMethods?.biometricEnabled ?? false,
              (value) {
                if (authMethods?.biometricAvailable == true) {
                  _toggleBiometric(value);
                } else {
                  _showErrorSnackbar('Biometric authentication is not available on this device');
                }
              },
            ),
            _buildListTile(
              'PIN Code',
              authMethods?.pinSetup == true ? 'Change PIN' : 'Setup PIN',
              Icons.pin,
              onTap: () => _handlePinSetup(authMethods?.pinSetup == true),
            ),
            _buildSwitchTile(
              'Require Authentication',
              'Require PIN or biometric to open app',
              Icons.lock,
              authMethods?.authRequired ?? false,
              _toggleAuthRequired,
            ),
            _buildListTile(
              'Export Secret Key',
              'View your wallet secret key',
              Icons.vpn_key,
              onTap: () => _showExportDialog(),
            ),
          ],
        );
      },
    ).animate(delay: 600.ms)
        .slideY(begin: 0.3, duration: 600.ms)
        .fadeIn(duration: 600.ms);
  }

  Widget _buildAboutSection() {
    return _buildSection(
      title: 'About',
      icon: Icons.info_outline,
      children: [
        _buildInfoTile(
          'Version',
          AppConstants.appVersion,
          iconData: Icons.verified,
        ),
        _buildListTile(
          'Terms of Service',
          'Read our terms and conditions',
          Icons.description,
          onTap: () => _showComingSoonSnackbar(),
        ),
        _buildListTile(
          'Privacy Policy',
          'Learn about data protection',
          Icons.privacy_tip,
          onTap: () => _showComingSoonSnackbar(),
        ),
        _buildListTile(
          'Support',
          'Get help and contact us',
          Icons.help_outline,
          onTap: () => _showComingSoonSnackbar(),
        ),
        _buildListTile(
          'Debug Auth',
          'Check authentication status (Debug)',
          Icons.bug_report,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const DebugAuthScreen()),
          ),
        ),
      ],
    ).animate(delay: 800.ms)
        .slideY(begin: 0.3, duration: 600.ms)
        .fadeIn(duration: 600.ms);
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
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
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryPurple.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.textPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(
            color: AppColors.borderLight,
            height: 1,
            indent: 20,
            endIndent: 20,
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildListTile(
    String title,
    String subtitle,
    IconData iconData, {
    VoidCallback? onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        iconData,
        color: isDestructive ? AppColors.errorRed : AppColors.textSecondary,
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: isDestructive ? AppColors.errorRed : AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.textTertiary,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        color: AppColors.textTertiary,
        size: 16,
      ),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    IconData iconData,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return ListTile(
      leading: Icon(
        iconData,
        color: AppColors.textSecondary,
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.textTertiary,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildInfoTile(
    String title,
    String value, {
    String? subtitle,
    required IconData iconData,
  }) {
    return ListTile(
      leading: Icon(
        iconData,
        color: AppColors.textSecondary,
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textTertiary,
              ),
            )
          : null,
      trailing: Text(
        value,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: AppColors.primaryPurple,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showNetworkSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Network',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: Icon(
                Icons.bug_report,
                color: AppColors.warningOrange,
              ),
              title: Text(
                'Testnet',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              subtitle: Text(
                'Test network for development',
                style: TextStyle(color: AppColors.textTertiary),
              ),
              trailing: _selectedNetwork == AppConstants.networkTestnet
                  ? Icon(Icons.check, color: AppColors.primaryPurple)
                  : null,
              onTap: () {
                Navigator.pop(context);
                _switchNetwork(AppConstants.networkTestnet);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.public,
                color: AppColors.successGreen,
              ),
              title: Text(
                'Mainnet',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              subtitle: Text(
                'Live Stellar network',
                style: TextStyle(color: AppColors.textTertiary),
              ),
              trailing: _selectedNetwork == AppConstants.networkMainnet
                  ? Icon(Icons.check, color: AppColors.primaryPurple)
                  : null,
              onTap: () {
                Navigator.pop(context);
                _switchNetwork(AppConstants.networkMainnet);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showExportDialog() {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final secretKey = walletProvider.wallet?.secretKey;

    if (secretKey == null) {
      _showComingSoonSnackbar();
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.warning, color: AppColors.warningOrange),
            const SizedBox(width: 8),
            Text(
              'Secret Key',
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Keep this secret key safe. Anyone with access to it can control your wallet.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: SelectableText(
                secretKey,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Close',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  void _showComingSoonSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Feature coming soon'),
        backgroundColor: AppColors.secondaryBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  String _getWalletDisplayName(WalletProvider walletProvider, WalletModel wallet) {
    // Use the wallet's actual name instead of generic "Wallet X"
    return wallet.displayName;
  }

  void _showWalletManagement() {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _WalletManagementSheet(walletProvider: walletProvider),
    );
  }
}

/// Wallet Management Bottom Sheet
class _WalletManagementSheet extends StatelessWidget {
  final WalletProvider walletProvider;

  const _WalletManagementSheet({required this.walletProvider});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Manage Wallets',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),

            // Wallet List
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: walletProvider.wallets.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final wallet = walletProvider.wallets[index];
                  final isActive = walletProvider.activeWallet?.id == wallet.id;
                  
                  return Container(
                    decoration: BoxDecoration(
                      color: isActive 
                          ? AppColors.primaryPurple.withOpacity(0.1)
                          : AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isActive 
                            ? AppColors.primaryPurple
                            : AppColors.borderLight,
                        width: isActive ? 2 : 1,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primaryPurple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Icon(
                          Icons.account_balance_wallet,
                          color: AppColors.primaryPurple,
                          size: 24,
                        ),
                      ),
                      title: Text(
                        'Wallet ${index + 1}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            '${wallet.publicKey.substring(0, 8)}...${wallet.publicKey.substring(wallet.publicKey.length - 8)}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${wallet.displayBalance} XLM',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.primaryPurple,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (isActive) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primaryPurple,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'ACTIVE',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: AppColors.textSecondary),
                        color: AppColors.surfaceCard,
                        onSelected: (value) {
                          Navigator.pop(context);
                          switch (value) {
                            case 'rename':
                              _showRenameDialog(context, wallet);
                              break;
                            case 'export':
                              _showExportDialog(context, wallet);
                              break;
                            case 'delete':
                              if (!isActive) _showDeleteDialog(context, wallet);
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'rename',
                            child: Row(
                              children: [
                                Icon(Icons.edit, color: AppColors.textSecondary),
                                const SizedBox(width: 8),
                                Text('Rename', style: TextStyle(color: AppColors.textPrimary)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'export',
                            child: Row(
                              children: [
                                Icon(Icons.download, color: AppColors.textSecondary),
                                const SizedBox(width: 8),
                                Text('Export Secret Key', style: TextStyle(color: AppColors.textPrimary)),
                              ],
                            ),
                          ),
                          if (!isActive)
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, color: Colors.red),
                                  const SizedBox(width: 8),
                                  Text('Delete', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, wallet) {
    final nameController = TextEditingController(text: wallet.name);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: Text('Rename Wallet', style: TextStyle(color: AppColors.textPrimary)),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Wallet Name',
                  hintText: '3-20 chars, letters, numbers, _',
                  helperText: 'This will update your global @${nameController.text.isEmpty ? 'walletname' : nameController.text} registration',
                  helperStyle: TextStyle(color: AppColors.textTertiary, fontSize: 11),
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.borderLight),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primaryPurple),
                  ),
                ),
                style: TextStyle(color: AppColors.textPrimary),
                autofocus: true,
                onChanged: (value) {
                  setDialogState(() {}); // Update helper text
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty && newName != wallet.name) {
                // Validate wallet name format
                final validation = WalletRegistryService.validateWalletName(newName);
                if (!validation.isValid) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(validation.error ?? 'Invalid wallet name'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Show loading
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
                        Text('Updating wallet name...', style: TextStyle(color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                );

                try {
                  // Update in Firebase registry
                  await WalletRegistryService.updateWalletName(
                    oldWalletName: wallet.name,
                    newWalletName: newName,
                    publicKey: wallet.publicKey,
                    displayName: newName,
                  );

                  // Refresh wallet display names to reflect the change
                  final walletProvider = Provider.of<WalletProvider>(context, listen: false);
                  await walletProvider.refreshWalletDisplayNames();
                  
                  if (context.mounted) {
                    Navigator.pop(context); // Close loading dialog
                    Navigator.pop(context); // Close rename dialog
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Wallet renamed successfully!'),
                        backgroundColor: AppColors.primaryPurple,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context); // Close loading dialog
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to rename wallet: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } else {
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showExportDialog(BuildContext context, wallet) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: Text('Export Secret Key', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WARNING: Keep your secret key safe. Anyone with this key can access your wallet.',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: SelectableText(
                wallet.secretKey,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, wallet) {
    final walletDisplayName = wallet.displayName;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: Text('Delete Wallet', style: TextStyle(color: Colors.red)),
        content: Text(
          'Are you sure you want to delete "$walletDisplayName"? This action cannot be undone. Make sure you have backed up your secret key.',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog first
              
              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  backgroundColor: AppColors.surfaceCard,
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Deleting wallet...', style: TextStyle(color: AppColors.textPrimary)),
                    ],
                  ),
                ),
              );

              try {
                // Unregister from Firebase if wallet has a registered name
                if (wallet.name.isNotEmpty) {
                  await WalletRegistryService.unregisterWalletName(
                    walletName: wallet.name,
                    publicKey: wallet.publicKey,
                  );
                }

                // TODO: Delete wallet from local storage via WalletProvider
                // This should be implemented in WalletProvider as deleteWallet method
                
                if (context.mounted) {
                  Navigator.pop(context); // Close loading dialog
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Wallet "$walletDisplayName" deleted successfully!'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context); // Close loading dialog
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete wallet: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}