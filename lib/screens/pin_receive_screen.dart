import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../app/theme/colors.dart';
import '../providers/wallet_provider.dart';
import '../services/pin_code_service.dart';
import '../models/pin_code_model.dart';


import 'dart:async';

/// PIN Receive Screen
/// Generate PIN codes for receiving payments
class PinReceiveScreen extends StatefulWidget {
  const PinReceiveScreen({super.key});

  @override
  State<PinReceiveScreen> createState() => _PinReceiveScreenState();
}

class _PinReceiveScreenState extends State<PinReceiveScreen> {
  final _amountController = TextEditingController();
  final _memoController = TextEditingController();
  
  bool _isGenerating = false;
  PinCodeModel? _activePinCode;
  Timer? _countdownTimer;
  Timer? _statusCheckTimer;
  bool _showTransferSuccess = false;
  
  @override
  void dispose() {
    _amountController.dispose();
    _memoController.dispose();
    _countdownTimer?.cancel();
    _statusCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _generatePinCode() async {
    if (_amountController.text.trim().isEmpty) {
      _showErrorDialog('Please enter an amount');
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      _showErrorDialog('Please enter a valid amount');
      return;
    }

    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    
    // Handle wallet selection
    if (walletProvider.walletCount > 1) {
      final selectedWallet = await _showWalletSelectionDialog();
      if (selectedWallet == null) return;
      
      // Set selected wallet as active temporarily for this operation
      await walletProvider.setActiveWallet(selectedWallet.id);
    }

    final wallet = walletProvider.wallet;
    if (wallet == null) {
      _showErrorDialog('No wallet available');
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final pinCode = await PinCodeService.createPinCode(
        walletPublicKey: wallet.publicKey,
        amount: amount,
        walletName: wallet.displayName,
        memo: _memoController.text.trim().isEmpty ? null : _memoController.text.trim(),
      );

      setState(() {
        _activePinCode = pinCode;
        _isGenerating = false;
      });

      _startCountdown();
      _startStatusChecker();
      _showSuccessMessage();
    } catch (e) {
      setState(() => _isGenerating = false);
      _showErrorDialog('Failed to generate PIN code: $e');
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted && _activePinCode != null) {
        if (_activePinCode!.isExpired) {
          setState(() {
            _activePinCode = null;
            timer.cancel();
          });
          _statusCheckTimer?.cancel();
        } else {
          setState(() {}); // Trigger rebuild for countdown update
        }
      } else {
        timer.cancel();
      }
    });
  }

  void _startStatusChecker() {
    _statusCheckTimer?.cancel();
    _statusCheckTimer = Timer.periodic(Duration(seconds: 2), (timer) async {
      if (mounted && _activePinCode != null && !_showTransferSuccess) {
        try {
          final updatedPinCode = await PinCodeService.getPinCodeById(_activePinCode!.id);
          if (updatedPinCode != null && updatedPinCode.isUsed) {
            setState(() {
              _showTransferSuccess = true;
            });
            timer.cancel();
            _countdownTimer?.cancel();
            
            // Show success animation
            _showTransferSuccessAnimation();
            
            // Navigate to home after 1 second
            Timer(Duration(seconds: 1), () async {
              if (mounted) {
                // Update wallet balance
                final walletProvider = Provider.of<WalletProvider>(context, listen: false);
                await walletProvider.refreshBalance();
                
                // Navigate to home screen (pop all screens until home)
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            });
          }
        } catch (e) {
          // Ignore errors in status checking
        }
      } else if (_activePinCode == null) {
        timer.cancel();
      }
    });
  }

  Future<dynamic> _showWalletSelectionDialog() async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.borderLight),
        ),
        title: Text(
          'Select Wallet',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: walletProvider.wallets.map((wallet) => ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primaryPurple,
              child: Text(
                wallet.displayName.substring(0, 1).toUpperCase(),
                style: TextStyle(color: Colors.white),
              ),
            ),
            title: Text(
              wallet.displayName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: Text(
              '${wallet.displayBalance} XLM',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            onTap: () => Navigator.pop(context, wallet),
          )).toList(),
        ),
      ),
    );
  }

  void _showSuccessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'PIN code generated successfully! Valid for 5 minutes.',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.successGreen,
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _showTransferSuccessAnimation() {
    // Show success snackbar with bigger design
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle, color: Colors.white, size: 28),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '🎉 Payment Received!',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Redirecting to home screen...',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        backgroundColor: AppColors.successGreen,
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorDialog(String message) {
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
            Icon(Icons.error_outline, color: AppColors.errorRed),
            SizedBox(width: 12),
            Text(
              'Error',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
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
            child: Text(
              'OK',
              style: TextStyle(color: AppColors.primaryPurple),
            ),
          ),
        ],
      ),
    );
  }

  void _copyPinCode() {
    if (_activePinCode != null) {
      Clipboard.setData(ClipboardData(text: _activePinCode!.pinCode));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PIN code copied to clipboard'),
          backgroundColor: AppColors.primaryPurple,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _cancelPinCode() async {
    if (_activePinCode != null) {
      try {
        await PinCodeService.cancelPinCode(_activePinCode!.id);
        setState(() {
          _activePinCode = null;
          _countdownTimer?.cancel();
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PIN code cancelled'),
            backgroundColor: AppColors.warningOrange,
            duration: Duration(seconds: 2),
          ),
        );
      } catch (e) {
        _showErrorDialog('Failed to cancel PIN code: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      SizedBox(height: 32),
                      if (_activePinCode == null) ...[
                        _buildAmountInput(),
                        SizedBox(height: 24),
                        _buildMemoInput(),
                        SizedBox(height: 32),
                        _buildGenerateButton(),
                      ] else ...[
                        _buildPinCodeDisplay(),
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
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Container(
              padding: EdgeInsets.all(8),
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
          SizedBox(width: 16),
          Expanded(
            child: Text(
              'Receive with PIN',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Generate PIN Code',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ).animate()
            .slideY(begin: 0.3, duration: 600.ms)
            .fadeIn(duration: 600.ms),
        
        SizedBox(height: 12),
        
        Text(
          'Create a 6-digit PIN code that others can use to send you XLM. The PIN expires in 5 minutes.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ).animate(delay: 200.ms)
            .slideY(begin: 0.3, duration: 600.ms)
            .fadeIn(duration: 600.ms),
      ],
    );
  }

  Widget _buildAmountInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Amount to Receive',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 12),
        
        TextFormField(
          controller: _amountController,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: '0.0000000',
            suffixText: 'XLM',
            filled: true,
            fillColor: AppColors.surfaceInput,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.borderLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.borderLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.primaryPurple, width: 2),
            ),
          ),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      ],
    ).animate(delay: 400.ms)
        .slideY(begin: 0.3, duration: 600.ms)
        .fadeIn(duration: 600.ms);
  }

  Widget _buildMemoInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Memo (Optional)',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 12),
        
        TextFormField(
          controller: _memoController,
          maxLength: 28,
          decoration: InputDecoration(
            hintText: 'Payment description...',
            filled: true,
            fillColor: AppColors.surfaceInput,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.borderLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.borderLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.primaryPurple, width: 2),
            ),
          ),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      ],
    ).animate(delay: 600.ms)
        .slideY(begin: 0.3, duration: 600.ms)
        .fadeIn(duration: 600.ms);
  }

  Widget _buildGenerateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isGenerating ? null : _generatePinCode,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryPurple,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isGenerating
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Generating...'),
                ],
              )
            : Text(
                'Generate PIN Code',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    ).animate(delay: 800.ms)
        .slideY(begin: 0.3, duration: 600.ms)
        .fadeIn(duration: 600.ms);
  }

  Widget _buildPinCodeDisplay() {
    return Column(
      children: [
        // PIN Code Card
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: _showTransferSuccess 
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.successGreen, Color(0xFF2E7D32)],
                )
              : AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: (_showTransferSuccess ? AppColors.successGreen : AppColors.primaryPurple).withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 2,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(
                _showTransferSuccess ? Icons.check_circle : Icons.pin,
                size: 48,
                color: Colors.white,
              ),
              SizedBox(height: 16),
              
              Text(
                _showTransferSuccess ? 'Payment Received!' : 'Your PIN Code',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              
              SizedBox(height: 24),
              
              // PIN Code Display or Success Message
              Container(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _showTransferSuccess
                  ? Text(
                      '🎉 SUCCESS 🎉',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    )
                  : Text(
                      _activePinCode!.formattedPinCode,
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 8,
                      ),
                    ),
              ),
              
              SizedBox(height: 24),
              
              // Amount and Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Amount',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        Text(
                          _activePinCode!.displayAmount,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _showTransferSuccess ? 'Status' : 'Expires in',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        Text(
                          _showTransferSuccess ? 'Completed ✅' : _activePinCode!.timeRemainingText,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ).animate()
            .scale(duration: 600.ms, curve: Curves.elasticOut)
            .fadeIn(duration: 600.ms)
            .animate(target: _showTransferSuccess ? 1 : 0)
            .shimmer(duration: _showTransferSuccess ? 1000.ms : 0.ms, color: Colors.white.withOpacity(0.5))
            .scale(begin: Offset(1.0, 1.0), end: Offset(1.02, 1.02), duration: 300.ms),
        
        SizedBox(height: 32),
        
        // Action Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _copyPinCode,
                icon: Icon(Icons.copy, size: 18),
                label: Text('Copy PIN'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryPurple,
                  side: BorderSide(color: AppColors.primaryPurple),
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            
            SizedBox(width: 16),
            
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _cancelPinCode,
                icon: Icon(Icons.cancel, size: 18),
                label: Text('Cancel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.errorRed,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ).animate(delay: 200.ms)
            .slideY(begin: 0.3, duration: 600.ms)
            .fadeIn(duration: 600.ms),
        
        SizedBox(height: 24),
        
        // Instructions
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.primaryPurple,
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'How to Use',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 16),
              
              Text(
                '1. Share this PIN code with the sender\n'
                '2. They can use it in the "Send" screen\n'
                '3. PIN expires in 5 minutes\n'
                '4. Can only be used once',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ).animate(delay: 400.ms)
            .slideY(begin: 0.3, duration: 600.ms)
            .fadeIn(duration: 600.ms),
      ],
    );
  }
}