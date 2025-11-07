import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../app/theme/colors.dart';
import '../providers/wallet_provider.dart';
import '../models/wallet_model.dart';
import '../widgets/custom_button.dart';

/// QR Code Receive Screen
/// Allows users to generate QR codes for receiving XLM
class QRReceiveScreen extends StatefulWidget {
  const QRReceiveScreen({super.key});

  @override
  State<QRReceiveScreen> createState() => _QRReceiveScreenState();
}

class _QRReceiveScreenState extends State<QRReceiveScreen> {
  final TextEditingController _amountController = TextEditingController();
  WalletModel? _selectedWallet;
  String _qrData = '';
  bool _qrGenerated = false;

  @override
  void initState() {
    super.initState();
    _initializeWallet();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _initializeWallet() {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    
    // If only one wallet exists, auto-select it
    if (walletProvider.walletCount == 1) {
      _selectedWallet = walletProvider.activeWallet;
    } else if (walletProvider.hasActiveWallet) {
      // Default to active wallet if multiple wallets exist
      _selectedWallet = walletProvider.activeWallet;
    }
  }

  void _generateQRCode() {
    if (_selectedWallet == null) {
      _showError('Please select a wallet');
      return;
    }

    final amount = _amountController.text.trim();
    if (amount.isEmpty) {
      _showError('Please enter an amount');
      return;
    }

    final double? parsedAmount = double.tryParse(amount);
    if (parsedAmount == null || parsedAmount <= 0) {
      _showError('Please enter a valid amount');
      return;
    }

    // Create Stellar payment URI
    // Format: web+stellar:pay?destination=WALLET_ADDRESS&amount=AMOUNT&asset_code=XLM
    final qrData = 'web+stellar:pay?destination=${_selectedWallet!.publicKey}&amount=$amount&asset_code=XLM';
    
    setState(() {
      _qrData = qrData;
      _qrGenerated = true;
    });

    // Show success feedback
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('QR Code generated successfully!'),
        backgroundColor: AppColors.successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showError(String message) {
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

  void _resetQRCode() {
    setState(() {
      _qrGenerated = false;
      _qrData = '';
    });
    _amountController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!_qrGenerated) ...[
                        _buildWalletSelection(),
                        const SizedBox(height: 24),
                        _buildAmountInput(),
                        const SizedBox(height: 32),
                        _buildGenerateButton(),
                      ] else ...[
                        _buildQRCodeDisplay(),
                        const SizedBox(height: 24),
                        _buildQRActions(),
                      ],
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
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.glassLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Icon(
                Icons.arrow_back,
                color: AppColors.textPrimary,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Receive with QR Code',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ).animate()
        .slideY(begin: -0.3, duration: 400.ms)
        .fadeIn(duration: 400.ms);
  }

  Widget _buildWalletSelection() {
    return Consumer<WalletProvider>(
      builder: (context, walletProvider, child) {
        if (walletProvider.walletCount <= 1) {
          // Show selected wallet info when only one wallet
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.cardGradient,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet,
                    color: AppColors.textPrimary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selected Wallet',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedWallet?.displayName ?? 'No wallet selected',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedWallet?.shortPublicKey ?? '',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate(delay: 200.ms)
              .slideY(begin: 0.3, duration: 500.ms)
              .fadeIn(duration: 500.ms);
        }

        // Show wallet dropdown when multiple wallets exist
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.cardGradient,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Wallet Address',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              _buildCustomWalletSelector(walletProvider),
            ],
          ),
        ).animate(delay: 200.ms)
            .slideY(begin: 0.3, duration: 500.ms)
            .fadeIn(duration: 500.ms);
      },
    );
  }

  Widget _buildAmountInput() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Amount to Receive',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: '0.0000000',
              hintStyle: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w600,
              ),
              suffixText: 'XLM',
              suffixStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.primaryPurple,
                fontWeight: FontWeight.w600,
              ),
              filled: true,
              fillColor: AppColors.surfaceElevated.withOpacity(0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.borderLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primaryPurple, width: 2),
              ),
            ),
          ),
        ],
      ),
    ).animate(delay: 400.ms)
        .slideY(begin: 0.3, duration: 500.ms)
        .fadeIn(duration: 500.ms);
  }

  Widget _buildGenerateButton() {
    return CustomButton(
      text: 'Create QR Code',
      onPressed: _generateQRCode,
      icon: const Icon(Icons.qr_code),
      gradientColors: AppColors.accentGradient.colors,
    ).animate(delay: 600.ms)
        .slideY(begin: 0.3, duration: 500.ms)
        .fadeIn(duration: 500.ms);
  }

  Widget _buildQRCodeDisplay() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Scan to Send XLM',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'to ${_selectedWallet?.displayName ?? 'Selected Wallet'}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          
          // QR Code
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: QrImageView(
              data: _qrData,
              version: QrVersions.auto,
              size: 250.0,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Amount display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _amountController.text,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'XLM',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.primaryPurple,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate()
        .scale(duration: 600.ms, curve: Curves.elasticOut)
        .fadeIn(duration: 600.ms);
  }

  Widget _buildQRActions() {
    return Column(
      children: [
        CustomButton(
          text: 'Generate New QR',
          onPressed: _resetQRCode,
          icon: const Icon(Icons.refresh),
          gradientColors: AppColors.goldGradient.colors,
        ).animate(delay: 200.ms)
            .slideY(begin: 0.3, duration: 500.ms)
            .fadeIn(duration: 500.ms),
        
        const SizedBox(height: 16),
        
        Text(
          'Share this QR code with the sender to receive XLM',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ).animate(delay: 400.ms)
            .slideY(begin: 0.3, duration: 500.ms)
            .fadeIn(duration: 500.ms),
      ],
    );
  }

  Widget _buildCustomWalletSelector(WalletProvider walletProvider) {
    return GestureDetector(
      onTap: () => _showWalletBottomSheet(walletProvider),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.account_balance_wallet,
                color: AppColors.textPrimary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedWallet?.displayName ?? 'Select Wallet',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _selectedWallet?.shortPublicKey ?? 'Choose a wallet to receive XLM',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontFamily: _selectedWallet != null ? 'monospace' : null,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down,
              color: AppColors.textSecondary,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  void _showWalletBottomSheet(WalletProvider walletProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Title
              Text(
                'Select Wallet',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Wallet list
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: walletProvider.wallets.length,
                  itemBuilder: (context, index) {
                    final wallet = walletProvider.wallets[index];
                    final isSelected = _selectedWallet?.id == wallet.id;
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedWallet = wallet;
                          });
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: isSelected 
                                ? AppColors.primaryGradient 
                                : AppColors.cardGradient,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected 
                                  ? AppColors.primaryPurple 
                                  : AppColors.borderLight,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected ? [
                              BoxShadow(
                                color: AppColors.primaryPurple.withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 0,
                                offset: const Offset(0, 4),
                              ),
                            ] : null,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: isSelected 
                                      ? LinearGradient(
                                          colors: [
                                            Colors.white.withOpacity(0.3),
                                            Colors.white.withOpacity(0.1),
                                          ],
                                        )
                                      : AppColors.accentGradient,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  isSelected ? Icons.check_circle : Icons.account_balance_wallet,
                                  color: AppColors.textPrimary,
                                  size: 24,
                                ),
                              ),
                              
                              const SizedBox(width: 16),
                              
                              Expanded(
                                child: Text(
                                  wallet.shortPublicKey,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              
                              if (isSelected)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Selected',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ).animate(delay: (index * 100).ms)
                          .slideX(begin: 0.3, duration: 400.ms)
                          .fadeIn(duration: 400.ms),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}