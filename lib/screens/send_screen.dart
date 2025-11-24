import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../app/theme/colors.dart';
import '../app/routes.dart';
import '../providers/wallet_provider.dart';

import '../widgets/custom_button.dart';
import '../services/stellar_service.dart';
import '../services/transaction_service.dart';
import '../services/wallet_registry_service.dart';
import '../services/pin_code_service.dart';
import '../models/pin_code_model.dart';

/// Send Screen
/// Premium transaction sending interface with validation and confirmation
class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();
  final TextEditingController _pinCodeController = TextEditingController();
  final FocusNode _addressFocus = FocusNode();
  final FocusNode _amountFocus = FocusNode();
  final FocusNode _memoFocus = FocusNode();
  final FocusNode _pinCodeFocus = FocusNode();

  bool _isSending = false;
  String? _validationError;
  TransactionValidationResult? _validationResult;
  bool _isResolvingAddress = false;
  String? _resolvedAddress;
  String? _resolvedWalletName;
  PinCodeModel? _usedPinCode;
  bool _usePinCode = false;
  bool _isValidatingPin = false;

  @override
  void initState() {
    super.initState();
    _setupValidation();
  }

  void _setupValidation() {
    _addressController.addListener(() {
      setState(() {}); // Update UI for prefix icon changes
      _validateTransaction();
    });
    _amountController.addListener(_validateTransaction);
    _memoController.addListener(_validateTransaction);
  }

  void _validateTransaction() async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    
    if (_addressController.text.isEmpty || _amountController.text.isEmpty) {
      setState(() {
        _validationError = null;
        _validationResult = null;
        _resolvedAddress = null;
        _resolvedWalletName = null;
      });
      return;
    }

    String destinationAddress = _addressController.text.trim();
    final currentWallet = walletProvider.wallet;
    
    // Check if input is a 6-digit PIN code
    if (RegExp(r'^\d{6}$').hasMatch(destinationAddress.replaceAll(' ', ''))) {
      setState(() => _isResolvingAddress = true);
      
      try {
        final pinCodeModel = await PinCodeService.validatePinCode(destinationAddress);
        
        if (pinCodeModel != null) {
          setState(() {
            _resolvedAddress = pinCodeModel.walletPublicKey;
            _resolvedWalletName = 'PIN: ${pinCodeModel.formattedPinCode}';
            _usedPinCode = pinCodeModel;
            _isResolvingAddress = false;
            _validationError = null;
          });
          
          // Auto-fill amount and memo from PIN code
          _amountController.text = pinCodeModel.amount.toStringAsFixed(7);
          if (pinCodeModel.memo?.isNotEmpty == true) {
            _memoController.text = pinCodeModel.memo!;
          }
          
          destinationAddress = pinCodeModel.walletPublicKey;
        } else {
          setState(() {
            _validationError = 'Invalid or expired PIN code';
            _validationResult = null;
            _resolvedAddress = null;
            _resolvedWalletName = null;
            _isResolvingAddress = false;
          });
          return;
        }
      } catch (e) {
        setState(() {
          _validationError = 'Failed to validate PIN code: $e';
          _validationResult = null;
          _resolvedAddress = null;
          _resolvedWalletName = null;
          _isResolvingAddress = false;
        });
        return;
      }
    }
    // Check if address starts with @ (wallet name)
    else if (destinationAddress.startsWith('@')) {
      setState(() => _isResolvingAddress = true);
      
      try {
        final resolvedPublicKey = await WalletRegistryService.resolveWalletName(destinationAddress);
        
        if (resolvedPublicKey != null) {
          // Check if user is trying to send to the currently active wallet by name
          if (currentWallet != null && resolvedPublicKey == currentWallet.publicKey) {
            setState(() {
              _validationError = 'Cannot send to your currently active wallet ($destinationAddress)';
              _validationResult = null;
              _resolvedAddress = null;
              _resolvedWalletName = null;
              _isResolvingAddress = false;
            });
            return;
          }
          
          setState(() {
            _resolvedAddress = resolvedPublicKey;
            _resolvedWalletName = destinationAddress;
          });
          destinationAddress = resolvedPublicKey;
        } else {
          setState(() {
            _validationError = 'Wallet name "$destinationAddress" not found';
            _validationResult = null;
            _resolvedAddress = null;
            _resolvedWalletName = null;
            _isResolvingAddress = false;
          });
          return;
        }
      } catch (e) {
        setState(() {
          _validationError = 'Failed to resolve wallet name: $e';
          _validationResult = null;
          _resolvedAddress = null;
          _resolvedWalletName = null;
          _isResolvingAddress = false;
        });
        return;
      } finally {
        setState(() => _isResolvingAddress = false);
      }
    } else {
      // Check if user is trying to send to their currently active wallet address directly
      if (currentWallet != null && destinationAddress == currentWallet.publicKey) {
        setState(() {
          _validationError = 'Cannot send to your currently active wallet address';
          _validationResult = null;
          _resolvedAddress = null;
          _resolvedWalletName = null;
        });
        return;
      }
      
      // Reset resolved address if not using wallet name
      setState(() {
        _resolvedAddress = null;
        _resolvedWalletName = null;
      });
    }

    final result = TransactionService.validateTransaction(
      destinationAddress: destinationAddress,
      amount: _amountController.text.trim(),
      currentBalance: walletProvider.balance,
      memo: _memoController.text.trim(),
    );

    setState(() {
      _validationResult = result;
      _validationError = result.isValid ? null : result.error;
    });
  }

  Future<void> _sendTransaction() async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    
    // Get the actual destination address (resolved if wallet name was used)
    String destinationAddress = _resolvedAddress ?? _addressController.text.trim();
    
    // Final security check: prevent self-transfer to currently active wallet only
    final currentWallet = walletProvider.wallet;
    if (currentWallet != null && destinationAddress == currentWallet.publicKey) {
      setState(() => _validationError = 'Cannot send to your currently active wallet');
      return;
    }
    
    // Final validation
    final validation = TransactionService.validateTransaction(
      destinationAddress: destinationAddress,
      amount: _amountController.text.trim(),
      currentBalance: walletProvider.balance,
      memo: _memoController.text.trim(),
    );

    if (!validation.isValid) {
      setState(() => _validationError = validation.error);
      return;
    }

    // Check if destination account exists and ask for confirmation if not
    setState(() => _isSending = true);
    
    bool accountExists = false;
    try {
      accountExists = await StellarService.accountExists(destinationAddress);
    } catch (e) {
      setState(() => _isSending = false);
      _showErrorDialog(
        'Verification Failed',
        'Failed to verify destination account:\n\n$e',
      );
      return;
    }
    
    setState(() => _isSending = false);

    // If account doesn't exist, ask for confirmation
    if (!accountExists) {
      final shouldProceed = await _showInactiveAccountConfirmation();
      if (!shouldProceed) return;
    }

    // Show confirmation dialog
    final confirmed = await _showConfirmationDialog();
    if (!confirmed) return;

    setState(() => _isSending = true);

    try {
      final success = await walletProvider.sendTransaction(
        destinationAddress: destinationAddress,
        amount: double.parse(_amountController.text.trim()),
        memo: _memoController.text.trim(),
      );

      if (success && mounted) {
        // Mark PIN code as used if transfer was made with PIN
        if (_usedPinCode != null) {
          try {
            await PinCodeService.usePinCode(_usedPinCode!.id);
          } catch (e) {
            debugPrint('Failed to mark PIN code as used: $e');
          }
        }
        
        _showSuccessDialog();
      } else if (mounted) {
        _showErrorDialog(
          'Transaction Failed',
          walletProvider.error ?? 'Transaction failed to complete. Please try again.',
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(
          'Transaction Error',
          'Error sending transaction:\n\n$e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<bool> _showConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => _buildConfirmationDialog(),
    ) ?? false;
  }

  Future<bool> _showInactiveAccountConfirmation() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber,
              color: AppColors.warningOrange,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Inactive Account',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are sending to an inactive or non-existent Stellar account.',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.warningOrange.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This transfer will:',
                    style: TextStyle(
                      color: AppColors.warningOrange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Activate the recipient\'s account (requires minimum 1 XLM)\n'
                    '• Allow them to receive future payments\n'
                    '• Cannot be reversed once sent',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Do you want to proceed with this transfer?',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
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
              backgroundColor: AppColors.warningOrange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Proceed',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildSuccessDialog(),
    );
  }

  Widget _buildConfirmationDialog() {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final fee = _validationResult?.estimatedFee ?? 0.0001;
    final total = amount + fee;

    return AlertDialog(
      backgroundColor: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Text(
        'Confirm Transaction',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
        content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_resolvedWalletName != null) ...[
            _buildConfirmationItem('To:', _resolvedWalletName!),
            const SizedBox(height: 8),
            _buildConfirmationItem('Address:', _resolvedAddress!, isSubAddress: true),
          ] else
            _buildConfirmationItem('To:', _addressController.text.trim()),
          const SizedBox(height: 12),
          _buildConfirmationItem('Amount:', '${amount.toStringAsFixed(7)} XLM'),
          const SizedBox(height: 12),
          _buildConfirmationItem('Network Fee:', '${fee.toStringAsFixed(7)} XLM'),
          const SizedBox(height: 12),
          _buildConfirmationItem(
            'Total:', 
            '${total.toStringAsFixed(7)} XLM',
            isTotal: true,
          ),
          if (_memoController.text.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildConfirmationItem('Memo:', _memoController.text.trim()),
          ],
        ],
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
          child: Text('Confirm'),
        ),
      ],
    );
  }

  Widget _buildConfirmationItem(String label, String value, {bool isTotal = false, bool isSubAddress = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              color: isSubAddress ? AppColors.textTertiary.withOpacity(0.7) : AppColors.textTertiary,
              fontSize: isSubAddress ? 12 : 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: isTotal ? AppColors.primaryPurple : (isSubAddress ? AppColors.textSecondary : AppColors.textPrimary),
              fontSize: isSubAddress ? 12 : 14,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.w400,
              fontFamily: (label == 'To:' && !value.startsWith('@')) || label == 'Address:' ? 'monospace' : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessDialog() {
    return AlertDialog(
      backgroundColor: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryPurple.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              Icons.check,
              color: AppColors.textPrimary,
              size: 40,
            ),
          ).animate()
              .scale(duration: 600.ms, curve: Curves.elasticOut)
              .then()
              .shimmer(duration: 1000.ms, color: AppColors.accentGold.withOpacity(0.3)),

          const SizedBox(height: 24),

          Text(
            'Transaction Sent!',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'Your transaction has been successfully sent to the Stellar network.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          CustomButton(
            text: 'Done',
            onPressed: () async {
              Navigator.of(context).pop(); // Close dialog
              
              // Update wallet balance
              final walletProvider = Provider.of<WalletProvider>(context, listen: false);
              await walletProvider.refreshBalance();
              
              // Navigate to home screen (pop all screens until home)
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _addressController.dispose();
    _amountController.dispose();
    _memoController.dispose();
    _pinCodeController.dispose();
    _addressFocus.dispose();
    _amountFocus.dispose();
    _memoFocus.dispose();
    _pinCodeFocus.dispose();
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
              _buildAppBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Consumer<WalletProvider>(
                    builder: (context, walletProvider, child) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildBalanceInfo(walletProvider),
                          const SizedBox(height: 32),
                          _buildTransactionForm(),
                          const SizedBox(height: 24),
                          if (_validationResult != null && _validationResult!.isValid)
                            _buildTransactionSummary(),
                          const SizedBox(height: 32),
                          _buildSendButton(),
                          if (_validationError != null) ...[
                            const SizedBox(height: 16),
                            _buildErrorMessage(),
                          ],
                        ],
                      );
                    },
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
            'Send XLM',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceInfo(WalletProvider walletProvider) {
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
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryPurple.withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Icon(
              Icons.account_balance_wallet,
              color: AppColors.textPrimary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Available Balance',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${walletProvider.displayBalance} XLM',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate(delay: 200.ms)
        .slideY(begin: 0.3, duration: 600.ms)
        .fadeIn(duration: 600.ms);
  }

  Widget _buildTransactionForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transaction Details',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ).animate(delay: 400.ms)
            .slideX(begin: 0.3, duration: 600.ms)
            .fadeIn(duration: 600.ms),

        const SizedBox(height: 20),

        // Send Method Selection
        _buildSendMethodSelection(),
        const SizedBox(height: 20),

        // Input Fields based on send method
        if (_usePinCode) ...[
          _buildPinCodeInput(),
        ] else ...[
          // Destination Address
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _addressController,
                focusNode: _addressFocus,
                decoration: InputDecoration(
                  labelText: 'Destination Address',
                  hintText: 'Address or @walletname',
                  prefixIcon: Icon(
                    _addressController.text.startsWith('@') 
                      ? Icons.account_balance_wallet 
                      : Icons.person,
                    color: _addressController.text.startsWith('@') 
                      ? AppColors.primaryPurple 
                      : AppColors.textTertiary,
                  ),
                  suffixIcon: _isResolvingAddress
                    ? Container(
                        width: 20,
                        height: 20,
                        padding: const EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primaryPurple,
                          ),
                        ),
                      )
                    : IconButton(
                        onPressed: () {
                          // TODO: Implement QR code scanner with self-transfer prevention
                          // When implemented, ensure scanned address is not user's own wallet
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('QR Scanner coming soon'),
                              backgroundColor: AppColors.secondaryBlue,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                        },
                        icon: Icon(
                          Icons.qr_code_scanner,
                          color: AppColors.textTertiary,
                        ),
                      ),
                ),
              style: TextStyle(
                color: AppColors.textPrimary,
                fontFamily: _addressController.text.startsWith('@') ? null : 'monospace',
              ),
              maxLines: 1,
            ),
            if (_resolvedAddress != null && _resolvedWalletName != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.primaryPurple.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: AppColors.primaryPurple,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Resolved to: ${_resolvedAddress!.substring(0, 8)}...${_resolvedAddress!.substring(_resolvedAddress!.length - 8)}',
                        style: TextStyle(
                          color: AppColors.primaryPurple,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              'Enter wallet address or @walletname (cannot send to your own wallets)',
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 12,
              ),
            ),
          ],
        ).animate(delay: 600.ms)
            .slideX(begin: 0.3, duration: 500.ms)
            .fadeIn(duration: 500.ms),

          const SizedBox(height: 20),
          
          // Amount
        TextField(
          controller: _amountController,
          focusNode: _amountFocus,
          decoration: const InputDecoration(
            labelText: 'Amount',
            hintText: '0.0000000',
            suffixText: 'XLM',
          ),
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          maxLines: 1,
        ).animate(delay: 800.ms)
            .slideX(begin: 0.3, duration: 500.ms)
            .fadeIn(duration: 500.ms),

        const SizedBox(height: 20),

        // Memo (Optional)
        TextField(
          controller: _memoController,
          focusNode: _memoFocus,
          decoration: InputDecoration(
            labelText: 'Memo (Optional)',
            hintText: 'Add a note for this transaction',
            prefixIcon: Icon(
              Icons.note,
              color: AppColors.textTertiary,
            ),
          ),
          style: TextStyle(
            color: AppColors.textPrimary,
          ),
          maxLength: 28,
          maxLines: 1,
        ).animate(delay: 1000.ms)
            .slideX(begin: 0.3, duration: 500.ms)
            .fadeIn(duration: 500.ms),
        ], // Close else block
      ],
    );
  }

  Widget _buildTransactionSummary() {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final fee = _validationResult!.estimatedFee!;
    final total = _validationResult!.totalAmount!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transaction Summary',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildSummaryRow('Amount:', '${amount.toStringAsFixed(7)} XLM'),
          _buildSummaryRow('Network Fee:', '${fee.toStringAsFixed(7)} XLM'),
          const Divider(color: AppColors.borderLight),
          _buildSummaryRow(
            'Total:', 
            '${total.toStringAsFixed(7)} XLM',
            isTotal: true,
          ),
        ],
      ),
    ).animate(delay: 300.ms)
        .slideY(begin: 0.3, duration: 500.ms)
        .fadeIn(duration: 500.ms);
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isTotal ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isTotal ? AppColors.primaryPurple : AppColors.textPrimary,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton() {
    final canSend = _validationResult?.isValid == true && !_isSending;

    return CustomButton(
      text: 'Send Transaction',
      onPressed: canSend ? _sendTransaction : null,
      isLoading: _isSending,
      enabled: canSend,
      icon: Icon(Icons.send),
    ).animate(delay: 1200.ms)
        .slideY(begin: 0.3, duration: 600.ms)
        .fadeIn(duration: 600.ms);
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.errorRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.errorRed.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: AppColors.errorRed,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _validationError!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.errorRed,
              ),
            ),
          ),
        ],
      ),
    ).animate()
        .slideY(begin: 0.3, duration: 400.ms)
        .fadeIn(duration: 400.ms);
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.borderLight),
        ),
        title: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: AppColors.errorRed,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryPurple,
            ),
            child: Text(
              'OK',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.primaryPurple,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendMethodSelection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Send Method',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _usePinCode = false;
                    _pinCodeController.clear();
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: !_usePinCode ? AppColors.primaryPurple.withOpacity(0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: !_usePinCode ? AppColors.primaryPurple : AppColors.borderLight,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.account_balance_wallet,
                          color: !_usePinCode ? AppColors.primaryPurple : AppColors.textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Manual',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: !_usePinCode ? AppColors.primaryPurple : AppColors.textSecondary,
                            fontWeight: !_usePinCode ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _usePinCode = true;
                    _addressController.clear();
                    _amountController.clear();
                    _memoController.clear();
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: _usePinCode ? AppColors.primaryPurple.withOpacity(0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _usePinCode ? AppColors.primaryPurple : AppColors.borderLight,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.pin,
                          color: _usePinCode ? AppColors.primaryPurple : AppColors.textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'PIN Code',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _usePinCode ? AppColors.primaryPurple : AppColors.textSecondary,
                            fontWeight: _usePinCode ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate(delay: 200.ms)
        .slideY(begin: 0.3, duration: 600.ms)
        .fadeIn(duration: 600.ms);
  }

  Widget _buildPinCodeInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _pinCodeController,
          focusNode: _pinCodeFocus,
          decoration: InputDecoration(
            labelText: 'PIN Code',
            hintText: 'Enter 6-digit PIN code',
            prefixIcon: Icon(
              Icons.pin,
              color: AppColors.primaryPurple,
            ),
            suffixIcon: _isValidatingPin
              ? Container(
                  width: 20,
                  height: 20,
                  padding: const EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primaryPurple,
                    ),
                  ),
                )
              : null,
          ),
          style: TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'monospace',
            fontSize: 18,
            letterSpacing: 2,
          ),
          keyboardType: TextInputType.number,
          maxLength: 6,
          onChanged: _onPinCodeChanged,
        ),
        const SizedBox(height: 4),
        Text(
          'Enter the 6-digit PIN code received from sender',
          style: TextStyle(
            color: AppColors.textTertiary,
            fontSize: 12,
          ),
        ),
      ],
    ).animate(delay: 600.ms)
        .slideX(begin: 0.3, duration: 500.ms)
        .fadeIn(duration: 600.ms);
  }

  void _onPinCodeChanged(String value) {
    if (value.length == 6) {
      _validatePinCode(value);
    }
  }

  Future<void> _validatePinCode(String pinCode) async {
    setState(() => _isValidatingPin = true);
    
    try {
      final pinData = await PinCodeService.validatePinCode(pinCode);
      
      if (pinData != null) {
        setState(() {
          _amountController.text = pinData.amount.toString();
          _memoController.text = pinData.memo ?? '';
          _usedPinCode = pinData;
          _isValidatingPin = false;
        });
        
        // Show confirmation dialog
        _showPinCodeConfirmationDialog(pinData);
      } else {
        setState(() => _isValidatingPin = false);
        _showErrorDialog('Invalid PIN Code', 'The PIN code you entered is invalid or has expired.');
      }
    } catch (e) {
      setState(() => _isValidatingPin = false);
      _showErrorDialog('Validation Error', 'Failed to validate PIN code: ${e.toString()}');
    }
  }

  void _showPinCodeConfirmationDialog(PinCodeModel pinData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        title: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: AppColors.primaryPurple,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Confirm Transaction',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.3, // Limit height
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(
              'You are about to send:',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primaryPurple.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Amount:',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          '${pinData.amount.toStringAsFixed(7)} XLM',
                          style: TextStyle(
                            color: AppColors.primaryPurple,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'To:',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          pinData.walletName ?? 'Unknown Wallet',
                          style: TextStyle(
                            color: AppColors.primaryPurple,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (pinData.memo != null && pinData.memo!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Memo:',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            pinData.memo!,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.right,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            ],
          ),
        ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _pinCodeController.clear();
                _amountController.clear();
                _memoController.clear();
                _usedPinCode = null;
              });
            },
            child: Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _confirmPinCodeTransaction();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Confirm Send'),
          ),
        ],
      ),
    ),
    );
  }

  Future<void> _confirmPinCodeTransaction() async {
    if (_usedPinCode == null) return;

    setState(() => _isSending = true);

    try {
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);

      final result = await StellarService.sendPayment(
        secretKey: walletProvider.activeWallet!.secretKey!,
        destinationAddress: _usedPinCode!.walletPublicKey,
        amount: _usedPinCode!.amount,
        memo: _usedPinCode!.memo ?? '',
      );

      // Check if transaction was successful (assuming TransactionModel has success field or check hash)
      if (result.hash.isNotEmpty) {
        // Mark PIN as used
        try {
          await PinCodeService.usePinCode(_usedPinCode!.pinCode);
        } catch (e) {
          debugPrint('Warning: Failed to mark PIN as used: $e');
          // Continue anyway since the payment was successful
        }

        setState(() => _isSending = false);
        _showSuccessDialog();

        // Clear form
        _pinCodeController.clear();
        _amountController.clear();
        _memoController.clear();
        _usedPinCode = null;
      } else {
        setState(() => _isSending = false);
        _showErrorDialog('Transaction Failed', 'Failed to send transfer');
      }
    } catch (e) {
      setState(() => _isSending = false);
      _showErrorDialog('Transaction Error', 'Failed to send transfer: ${e.toString()}');
    }
  }
}
