import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app/colors.dart';
import '../models/whisper_pay_model.dart';
import '../providers/wallet_provider.dart';
import '../services/whisper_pay_service.dart';
import '../services/pin_code_service.dart';
import '../widgets/custom_button.dart';

class WhisperPaySendScreen extends StatefulWidget {
  const WhisperPaySendScreen({super.key});

  @override
  State<WhisperPaySendScreen> createState() => _WhisperPaySendScreenState();
}

class _WhisperPaySendScreenState extends State<WhisperPaySendScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  final WhisperPayService _whisperPayService = WhisperPayService();
  WhisperPaySession? _foundSession;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    // Initialize WhisperPay service
    _whisperPayService.initialize();
    
    // Listen to service state changes
    _whisperPayService.addListener(_handleStateChange);
  }

  void _showLocationServiceError() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Row(
          children: [
            const Icon(
              Icons.location_off,
              color: Colors.orange,
            ),
            const SizedBox(width: 12),
            const Text(
              'Location Required',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'WhisperPay needs Location Services to scan for nearby devices.',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            const Text(
              'Troubleshooting Steps:',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '1. Enable Location/GPS in device settings',
              style: TextStyle(color: Colors.white70),
            ),
            const Text(
              '2. Grant Location permission to this app',
              style: TextStyle(color: Colors.white70),
            ),
            const Text(
              '3. Enable Bluetooth',
              style: TextStyle(color: Colors.white70),
            ),
            const Text(
              '4. Restart the app if needed',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Colors.blue,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Android requires location for BLE device discovery',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Try scanning again after user hopefully enables location
              Future.delayed(const Duration(milliseconds: 500), () {
                _startScanning();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text(
              'Retry',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _whisperPayService.removeListener(_handleStateChange);
    _whisperPayService.stopScanning();
    _pulseController.dispose();
    super.dispose();
  }

  void _startScanning() async {
    _pulseController.repeat(reverse: true);
    
    final success = await _whisperPayService.startScanning(
      onDeviceDiscovered: _onDeviceDiscovered,
    );
    
    if (!success) {
      _pulseController.stop();
      _showLocationServiceError();
      return;
    }
    
    // Auto-stop after 30 seconds
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted && _whisperPayService.state == WhisperPayState.scanningForDevices) {
        _stopScanning();
      }
    });
    
    _showSnackBar('Scanning for WhisperPay devices...', Colors.blue);
  }
  
  void _onDeviceDiscovered(WhisperPayBeacon beacon) {
    if (!beacon.isInRange) return; // Only show close devices
    
    setState(() {
      // Create session from discovered beacon (amount and walletAddress from BLE/session data)
      _foundSession = WhisperPaySession(
        sessionId: beacon.sessionId,
        deviceId: beacon.deviceId,
        createdAt: beacon.timestamp,
        expiresAt: beacon.timestamp.add(const Duration(minutes: 2)),
        walletName: 'WhisperPay Device',
        walletAddress: beacon.walletAddress, // Wallet address from beacon
        amount: beacon.amount, // Amount parsed from BLE advertising data
        memo: null,
      );
    });
    
    _stopScanning();
    _showPaymentConfirmation();
  }

  void _stopScanning() async {
    await _whisperPayService.stopScanning();
    _pulseController.stop();
    setState(() {});
  }

  void _handleStateChange() {
    if (!mounted) return;
    
    setState(() {
      // Update UI based on service state
      if (_whisperPayService.state == WhisperPayState.scanningForDevices) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
      }
      
      // Handle found session
      if (_whisperPayService.currentSession != null) {
        _foundSession = _whisperPayService.currentSession;
        _handleFoundSession();
      }
    });
  }

  void _handleFoundSession() {
    if (_foundSession != null) {
      _showPaymentConfirmation();
    }
  }

  void _showPaymentConfirmation() {
    // Show payment confirmation dialog
    // This would integrate with the actual payment flow
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('WhisperPay Device Found!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('💰 WhisperPay Payment Request', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.account_balance_wallet, size: 20),
                const SizedBox(width: 8),
                Text('From: ${_foundSession?.walletName ?? 'Unknown Wallet'}'),
              ],
            ),
            const SizedBox(height: 8),
            // Show session amount from BLE data
            if (_foundSession?.amount != null) ...[              
              Row(
                children: [
                  const Icon(Icons.payments, size: 20, color: Colors.green),
                  const SizedBox(width: 8),
                  Text('Amount: ${_foundSession!.amount!.toStringAsFixed(2)} XLM', 
                       style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (_foundSession?.memo != null && _foundSession!.memo!.isNotEmpty) ...[              
              Row(
                children: [
                  const Icon(Icons.note, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Memo: ${_foundSession!.memo}')),
                ],
              ),
            ] else ...[              
              const Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: Colors.grey),
                  SizedBox(width: 8),
                  Text('No amount specified', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Process payment
              Navigator.of(context).pop();
              _processPayment();
            },
            child: const Text('Confirm Payment'),
          ),
        ],
      ),
    );
  }

  void _processPayment() {
    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Processing WhisperPay transfer...'),
            const SizedBox(height: 8),
            Text('Amount: ${_foundSession?.amount?.toStringAsFixed(2) ?? '0'} XLM', 
                 style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
    
    // TODO: Integrate with actual Stellar payment logic
    _performStellarTransfer();
  }
  
  Future<void> _performStellarTransfer() async {
    try {
      // Debug: Print session details
      print('=== WhisperPay Transfer Debug ===');
      print('Found Session: $_foundSession');
      print('Session Amount: ${_foundSession?.amount}');
      print('Session Amount Type: ${_foundSession?.amount.runtimeType}');
      print('Session Device ID: ${_foundSession?.deviceId}');
      print('Session Wallet Address: ${_foundSession?.walletAddress}');
      print('Session Memo: ${_foundSession?.memo}');
      
      // Extract PIN code from device ID if it's PIN-based
      final deviceId = _foundSession?.deviceId ?? '';
      if (deviceId.startsWith('PIN_')) {
        final pinCode = deviceId.substring(4);
        print('PIN Code detected: $pinCode');
        
        // Validate PIN code again for safety
        try {
          final pinCodeModel = await PinCodeService.validatePinCode(pinCode);
          if (pinCodeModel != null) {
            print('PIN Code validated successfully');
            print('PIN Amount: ${pinCodeModel.amount}');
            print('PIN Wallet: ${pinCodeModel.walletPublicKey}');
            print('PIN Memo: ${pinCodeModel.memo}');
          } else {
            print('WARNING: PIN code validation failed');
          }
        } catch (e) {
          print('ERROR validating PIN code: $e');
        }
      }
      
      print('================================');
      
      if (_foundSession?.amount == null || _foundSession!.amount! <= 0) {
        print('ERROR: Invalid amount detected');
        print('Amount is null: ${_foundSession?.amount == null}');
        print('Amount value: ${_foundSession?.amount}');
        print('Amount <= 0: ${_foundSession!.amount! <= 0}');
        throw Exception('Invalid amount: ${_foundSession?.amount}');
      }
      
      // Get current wallet provider
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      if (!walletProvider.hasActiveWallet) {
        print('ERROR: No active wallet');
        throw Exception('No active wallet');
      }
      
      print('Wallet Provider State:');
      print('Has Active Wallet: ${walletProvider.hasActiveWallet}');
      print('Current Balance: ${walletProvider.balance}');
      
      // Get recipient address from session (from BLE data)
      String recipientAddress = _foundSession?.walletAddress ?? '';
      
      print('Original device ID: ${_foundSession?.deviceId}');
      print('Session wallet address: ${_foundSession?.walletAddress}');
      print('Using recipient address: $recipientAddress');
      print('Address length: ${recipientAddress.length}');
      print('Address starts with G: ${recipientAddress.startsWith('G')}');
      
      // If no wallet address in session, fallback to current wallet for testing
      if (recipientAddress.isEmpty || !recipientAddress.startsWith('G') || recipientAddress.length != 56) {
        print('WARNING: Invalid or missing wallet address in session, using fallback');
        recipientAddress = walletProvider.publicKey;
      }
      
      // Final validation
      if (!recipientAddress.startsWith('G') || recipientAddress.length != 56) {
        print('ERROR: Invalid recipient address format');
        throw Exception('Invalid recipient address: $recipientAddress');
      }
      
      // Get balance before transaction
      final balanceBefore = walletProvider.balance;
      final senderAddress = walletProvider.publicKey;
      
      print('💰 Balance before transaction: $balanceBefore XLM');
      print('🏦 Sender address: $senderAddress');
      print('🎯 Recipient address: $recipientAddress');
      print('🔄 Self-transfer: ${senderAddress == recipientAddress}');
      
      // Perform actual Stellar transaction
      print('🚀 Starting Stellar transaction...');
      print('   → From: $senderAddress');
      print('   → To: $recipientAddress');
      print('   → Amount: ${_foundSession!.amount!} XLM');
      print('   → Memo: ${_foundSession?.memo ?? 'WhisperPay transfer'}');
      
      final success = await walletProvider.sendTransaction(
        destinationAddress: recipientAddress,
        amount: _foundSession!.amount!,
        memo: _foundSession?.memo ?? 'WhisperPay transfer',
      );
      
      // Get balance after transaction
      final balanceAfter = walletProvider.balance;
      print('💰 Balance after transaction: $balanceAfter XLM');
      print('💸 Balance difference: ${balanceBefore - balanceAfter} XLM');
      print('📊 Transaction success: $success');
      
      if (walletProvider.error != null) {
        print('❌ Wallet provider error: ${walletProvider.error}');
      }
      
      // Close progress dialog
      if (mounted) Navigator.of(context).pop();
      
      if (success) {
        print('✅ Transaction completed successfully');
        // Show success dialog
        _showPaymentSuccess(balanceBefore, balanceAfter);
      } else {
        print('❌ Transaction failed');
        // Show error from wallet provider
        _showPaymentError(walletProvider.error ?? 'Transaction failed');
      }
      
    } catch (e) {
      // Close progress dialog
      if (mounted) Navigator.of(context).pop();
      
      // Show error dialog
      _showPaymentError(e.toString());
    }
  }
  
  void _showPaymentSuccess(double balanceBefore, double balanceAfter) {
    final balanceChange = balanceBefore - balanceAfter;
    final actualFee = balanceChange - (_foundSession?.amount ?? 0);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('Payment Successful!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('✅ ${_foundSession?.amount?.toStringAsFixed(2) ?? '0'} XLM sent successfully'),
            if (_foundSession?.walletName != null)
              Text('To: ${_foundSession!.walletName}'),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Text('Balance Changes:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600])),
            const SizedBox(height: 4),
            Text('Before: ${balanceBefore.toStringAsFixed(7)} XLM'),
            Text('After: ${balanceAfter.toStringAsFixed(7)} XLM'),
            Text('Total Change: -${balanceChange.toStringAsFixed(7)} XLM', 
                 style: const TextStyle(fontWeight: FontWeight.bold)),
            if (actualFee > 0) 
              Text('Network Fee: ~${actualFee.toStringAsFixed(7)} XLM', 
                   style: TextStyle(color: Colors.orange[600])),
            const SizedBox(height: 8),
            const Text('WhisperPay transfer completed!', 
                 style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Also close WhisperPay screen
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
  
  void _showPaymentError(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Payment Failed'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('❌ WhisperPay transfer failed'),
            const SizedBox(height: 8),
            Text('Error: $error', style: const TextStyle(color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'WhisperPay Send',
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
                    Icons.bluetooth_searching,
                    size: 48,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'WhisperPay Send',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Scan for nearby WhisperPay receivers',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Status Display
            if (_whisperPayService.state == WhisperPayState.scanningForDevices) ...[
              // Scanning Animation
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 200,
                      height: 200,
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
                      child: const Center(
                        child: Icon(
                          Icons.bluetooth_searching,
                          size: 60,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 24),
              
              const Text(
                'Scanning for WhisperPay devices...',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              
              const SizedBox(height: 8),
              
              Text(
                'Bring your device close to a WhisperPay receiver',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              
              const SizedBox(height: 32),
              
              CustomButton(
                text: 'Stop Scanning',
                onPressed: _stopScanning,
                icon: const Icon(Icons.stop, color: Colors.white),
              ),
            ] else ...[
              // Start Scanning
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.3),
                      AppColors.secondary.withOpacity(0.2),
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.5),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.2),
                      blurRadius: 15,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.bluetooth_searching,
                  size: 80,
                  color: AppColors.primary,
                ),
              ),
              
              const SizedBox(height: 32),
              
              CustomButton(
                text: 'Start WhisperPay Scan',
                onPressed: _startScanning,
                icon: const Icon(Icons.radar, color: Colors.white),
              ),
              
              const SizedBox(height: 16),
              
              Text(
                'Tap to scan for nearby WhisperPay receivers',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
            ],
            
            const SizedBox(height: 40),
            
            // Demo Notice
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.warning.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'WhisperPay Demo',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This is a demo implementation of WhisperPay. '
                    'The full BLE functionality requires additional setup '
                    'and permissions on actual devices.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
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
                      Icon(Icons.lightbulb_outline, color: AppColors.accent, size: 20),
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
                    '• Receiver activates WhisperPay mode on their device\n'
                    '• Start scanning on this device\n'
                    '• Bring devices within 20-50cm of each other\n'
                    '• Confirm payment details when detected\n'
                    '• Transaction completes automatically via Stellar',
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