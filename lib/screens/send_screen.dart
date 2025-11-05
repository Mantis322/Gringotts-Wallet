import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../app/theme/colors.dart';
import '../app/routes.dart';
import '../providers/wallet_provider.dart';
import '../widgets/custom_button.dart';
import '../services/transaction_service.dart';

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
  final FocusNode _addressFocus = FocusNode();
  final FocusNode _amountFocus = FocusNode();
  final FocusNode _memoFocus = FocusNode();

  bool _isSending = false;
  String? _validationError;
  TransactionValidationResult? _validationResult;

  @override
  void initState() {
    super.initState();
    _setupValidation();
  }

  void _setupValidation() {
    _addressController.addListener(_validateTransaction);
    _amountController.addListener(_validateTransaction);
    _memoController.addListener(_validateTransaction);
  }

  void _validateTransaction() {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    
    if (_addressController.text.isEmpty || _amountController.text.isEmpty) {
      setState(() {
        _validationError = null;
        _validationResult = null;
      });
      return;
    }

    final result = walletProvider.validateTransaction(
      destinationAddress: _addressController.text.trim(),
      amount: _amountController.text.trim(),
      memo: _memoController.text.trim(),
    );

    setState(() {
      _validationResult = result;
      _validationError = result.isValid ? null : result.error;
    });
  }

  Future<void> _sendTransaction() async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    
    // Final validation
    final validation = walletProvider.validateTransaction(
      destinationAddress: _addressController.text.trim(),
      amount: _amountController.text.trim(),
      memo: _memoController.text.trim(),
    );

    if (!validation.isValid) {
      setState(() => _validationError = validation.error);
      return;
    }

    // Show confirmation dialog
    final confirmed = await _showConfirmationDialog();
    if (!confirmed) return;

    setState(() => _isSending = true);

    try {
      final success = await walletProvider.sendTransaction(
        destinationAddress: _addressController.text.trim(),
        amount: double.parse(_amountController.text.trim()),
        memo: _memoController.text.trim(),
      );

      if (success && mounted) {
        _showSuccessDialog();
      } else if (mounted) {
        setState(() => _validationError = walletProvider.error ?? 'Transaction failed');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _validationError = 'Error sending transaction: $e');
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

  Widget _buildConfirmationItem(String label, String value, {bool isTotal = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: isTotal ? AppColors.primaryPurple : AppColors.textPrimary,
              fontSize: 14,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.w400,
              fontFamily: label == 'To:' ? 'monospace' : null,
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
            onPressed: () {
              Navigator.of(context).pop();
              AppRoutes.pop(context);
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
    _addressFocus.dispose();
    _amountFocus.dispose();
    _memoFocus.dispose();
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

        // Destination Address
        TextField(
          controller: _addressController,
          focusNode: _addressFocus,
          decoration: InputDecoration(
            labelText: 'Destination Address',
            hintText: 'G...',
            prefixIcon: Icon(
              Icons.person,
              color: AppColors.textTertiary,
            ),
            suffixIcon: IconButton(
              onPressed: () {
                // TODO: Implement QR code scanner
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
            fontFamily: 'monospace',
          ),
          maxLines: 1,
        ).animate(delay: 600.ms)
            .slideX(begin: 0.3, duration: 500.ms)
            .fadeIn(duration: 500.ms),

        const SizedBox(height: 20),

        // Amount
        TextField(
          controller: _amountController,
          focusNode: _amountFocus,
          decoration: InputDecoration(
            labelText: 'Amount',
            hintText: '0.0000000',
            prefixIcon: Icon(
              Icons.attach_money,
              color: AppColors.textTertiary,
            ),
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
}