import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app/colors.dart';
import '../models/wallet_model.dart';
import '../providers/wallet_provider.dart';
import '../services/whisper_pay_service.dart';
import '../widgets/custom_button.dart';

class WhisperPayReceiveScreen extends StatefulWidget {
  const WhisperPayReceiveScreen({super.key});

  @override
  State<WhisperPayReceiveScreen> createState() => _WhisperPayReceiveScreenState();
}

class _WhisperPayReceiveScreenState extends State<WhisperPayReceiveScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _progressController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _progressAnimation;
  
  final WhisperPayService _whisperPayService = WhisperPayService();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();
  
  Timer? _countdownTimer;
  Duration _remainingTime = const Duration(minutes: 2);
  bool _isActive = false;
  WalletModel? _selectedWallet;
  
  // Balance monitoring for incoming transfers
  double? _initialBalance;
  Timer? _balanceMonitor;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _progressController = AnimationController(
      duration: const Duration(minutes: 2),
      vsync: this,
    );
    
    // Initialize selected wallet
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeSelectedWallet();
    });
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _progressAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(_progressController);
    
    _initializeWhisperPay();
  }

  Future<void> _initializeWhisperPay() async {
    final success = await _whisperPayService.initialize();
    if (!success) {
      _showError('WhisperPay initialization failed. Please check permissions.');
    }
  }

  void _initializeSelectedWallet() {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    
    if (walletProvider.walletCount == 1) {
      // Single wallet: auto-select
      setState(() {
        _selectedWallet = walletProvider.activeWallet;
      });
    } else if (walletProvider.walletCount > 1) {
      // Multiple wallets: use active wallet as default
      setState(() {
        _selectedWallet = walletProvider.activeWallet;
      });
    }
  }

  void _showWalletSelection() async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    
    if (walletProvider.walletCount <= 1) {
      _showError('No wallets available');
      return;
    }
    
    final selectedWallet = await showDialog<WalletModel>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text(
          'Select Wallet for WhisperPay',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Container(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: walletProvider.walletCount,
            itemBuilder: (context, index) {
              final wallet = walletProvider.wallets[index];
              final isSelected = _selectedWallet?.publicKey == wallet.publicKey;
              
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isSelected ? AppColors.primary : Colors.grey,
                  child: Icon(
                    isSelected ? Icons.check : Icons.account_balance_wallet,
                    color: Colors.white,
                  ),
                ),
                title: Text(
                  wallet.name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${wallet.displayBalance} XLM',
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                ),
                onTap: () => Navigator.of(context).pop(wallet),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    
    if (selectedWallet != null) {
      setState(() {
        _selectedWallet = selectedWallet;
      });
    }
  }

  void _startBalanceMonitoring() {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    _initialBalance = walletProvider.balance;
    
    print('💰 WhisperPay: Starting balance monitoring, initial balance: $_initialBalance XLM');
    
    // Check balance every 2 seconds for incoming transfers
    _balanceMonitor = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        await walletProvider.refreshBalance();
        final currentBalance = walletProvider.balance;
        
        if (_initialBalance != null && currentBalance > _initialBalance!) {
          final receivedAmount = currentBalance - _initialBalance!;
          print('💰 WhisperPay: Balance increased! Received $receivedAmount XLM');
          
          // Stop monitoring and show success
          _balanceMonitor?.cancel();
          _showTransferSuccess(receivedAmount);
        }
      } catch (e) {
        print('❌ WhisperPay: Balance monitoring error: $e');
      }
    });
  }
  
  void _showTransferSuccess(double receivedAmount) async {
    // Stop receive mode
    await _whisperPayService.stopReceiveMode();
    _countdownTimer?.cancel();
    
    setState(() {
      _isActive = false;
    });
    
    _pulseController.stop();
    _progressController.reset();
    
    if (!mounted) return;
    
    // Show success dialog
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Payment Received!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '+${receivedAmount.toStringAsFixed(7)} XLM',
              style: const TextStyle(
                color: Colors.green,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'via WhisperPay',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop(); // Go back to previous screen
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    _amountController.dispose();
    _memoController.dispose();
    _countdownTimer?.cancel();
    _stopReceiveMode();
    super.dispose();
  }

  void _startReceiving() async {
    if (_selectedWallet == null) {
      _showError('No wallet selected');
      return;
    }

    final amount = _amountController.text.isNotEmpty 
        ? double.tryParse(_amountController.text) 
        : null;
    
    final success = await _whisperPayService.startReceiveMode(
      walletAddress: _selectedWallet!.publicKey,
      walletName: _selectedWallet!.name,
      amount: amount,
      memo: _memoController.text.isNotEmpty ? _memoController.text : null,
      timeout: const Duration(minutes: 2),
    );

    if (success) {
      setState(() {
        _isActive = true;
        _remainingTime = const Duration(minutes: 2);
      });
      
      _pulseController.repeat(reverse: true);
      _progressController.forward();
      _startCountdown();
      _startBalanceMonitoring();
      
      _showSnackBar('WhisperPay active! Bring devices close together.', Colors.green);
    } else {
      _showError('Failed to start WhisperPay');
    }
  }

  Future<void> _stopReceiveMode() async {
    await _whisperPayService.stopReceiveMode();
    _countdownTimer?.cancel();
    _balanceMonitor?.cancel();
    
    setState(() {
      _isActive = false;
      _remainingTime = const Duration(minutes: 2);
    });
    
    _pulseController.stop();
    _progressController.reset();
    
    _showSnackBar('WhisperPay deactivated', Colors.orange);
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime.inSeconds <= 0) {
        timer.cancel();
        _stopReceiveMode();
        _showSnackBar('WhisperPay session expired', Colors.orange);
        return;
      }
      
      setState(() {
        _remainingTime = Duration(seconds: _remainingTime.inSeconds - 1);
      });
    });
  }

  void _showError(String message) {
    _showSnackBar(message, Colors.red);
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'WhisperPay Receive',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withOpacity(0.1),
                    AppColors.secondary.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.bluetooth,
                    size: 48,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'WhisperPay Receive',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Activate receive mode and bring devices close together',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Wallet Selection
            Consumer<WalletProvider>(
              builder: (context, walletProvider, child) {
                if (walletProvider.walletCount <= 1) {
                  return const SizedBox.shrink();
                }
                
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.account_balance_wallet,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Receiving Wallet',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _showWalletSelection,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: AppColors.primary,
                                radius: 16,
                                child: const Icon(
                                  Icons.account_balance_wallet,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedWallet?.name ?? 'Select Wallet',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (_selectedWallet != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        '${_selectedWallet!.displayBalance} XLM',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_drop_down,
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            
            const SizedBox(height: 24),
            
            // Amount Input (Optional)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Amount (Optional)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Enter amount in XLM',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                      filled: true,
                      fillColor: AppColors.background.withOpacity(0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.currency_exchange, color: AppColors.accent),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Memo Input (Optional)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Memo (Optional)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _memoController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Enter payment description',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                      filled: true,
                      fillColor: AppColors.background.withOpacity(0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.note, color: AppColors.accent),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Status Indicator
            if (_isActive) ...[
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.secondary,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.bluetooth_searching,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 24),
              
              const Text(
                'WhisperPay Active',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 8),
              
              Text(
                'Waiting for nearby device...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Countdown Timer
              AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, child) {
                  return Column(
                    children: [
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: CircularProgressIndicator(
                          value: _progressAnimation.value,
                          strokeWidth: 6,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _formatDuration(_remainingTime),
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  );
                },
              ),
              
              const SizedBox(height: 32),
              
              CustomButton(
                text: 'Stop WhisperPay',
                onPressed: _stopReceiveMode,
                icon: const Icon(Icons.stop, color: Colors.white),
              ),
            ] else ...[
              // Start Button
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.2),
                      AppColors.secondary.withOpacity(0.2),
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.bluetooth,
                  size: 80,
                  color: AppColors.primary,
                ),
              ),
              
              const SizedBox(height: 32),
              
              CustomButton(
                text: 'Start WhisperPay',
                onPressed: _startReceiving,
                icon: const Icon(Icons.play_arrow, color: Colors.white),
              ),
              
              const SizedBox(height: 16),
              
              Text(
                'Tap to activate receive mode for 2 minutes',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
            ],
            
            const SizedBox(height: 32),
            
            // Info Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.accent.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.accent, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'How WhisperPay Works',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '• Activate receive mode on this device\n'
                    '• Sender opens WhisperPay scan on their device\n'
                    '• Bring devices within 20-50cm of each other\n'
                    '• Payment popup will appear automatically\n'
                    '• Sender confirms amount and completes payment',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}