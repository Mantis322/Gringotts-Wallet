import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../app/theme/colors.dart';
import '../app/routes.dart';
import '../app/constants.dart';
import '../providers/wallet_provider.dart';
import '../services/storage_service.dart';

/// Settings Screen
/// Wallet configuration and management interface
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDarkMode = true;
  bool _isBiometricEnabled = false;
  String _selectedNetwork = AppConstants.networkTestnet;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final themeMode = await StorageService.getThemeMode();
    final biometricEnabled = await StorageService.isBiometricEnabled();
    final selectedNetwork = await StorageService.getSelectedNetwork();

    setState(() {
      _isDarkMode = themeMode == 'dark';
      _isBiometricEnabled = biometricEnabled;
      _selectedNetwork = selectedNetwork;
    });
  }

  Future<void> _toggleTheme(bool value) async {
    setState(() => _isDarkMode = value);
    await StorageService.saveThemeMode(value ? 'dark' : 'light');
    
    // Show snackbar for theme change (implementation would restart app)
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Theme updated (restart app to apply)'),
          backgroundColor: AppColors.successGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    setState(() => _isBiometricEnabled = value);
    await StorageService.saveBiometricEnabled(value);
    
    if (mounted) {
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
    await walletProvider.clearWallet();

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
              'Clear Wallet',
              'Remove wallet from this device',
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
    return _buildSection(
      title: 'Preferences',
      icon: Icons.tune,
      children: [
        _buildSwitchTile(
          'Dark Mode',
          'Use dark theme across the app',
          Icons.dark_mode,
          _isDarkMode,
          _toggleTheme,
        ),
      ],
    ).animate(delay: 400.ms)
        .slideY(begin: 0.3, duration: 600.ms)
        .fadeIn(duration: 600.ms);
  }

  Widget _buildSecuritySection() {
    return _buildSection(
      title: 'Security',
      icon: Icons.security,
      children: [
        _buildSwitchTile(
          'Biometric Authentication',
          'Use fingerprint or face ID',
          Icons.fingerprint,
          _isBiometricEnabled,
          _toggleBiometric,
        ),
        _buildListTile(
          'Export Secret Key',
          'View your wallet secret key',
          Icons.vpn_key,
          onTap: () => _showExportDialog(),
        ),
      ],
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
}