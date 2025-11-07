import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../app/theme/colors.dart';
import '../providers/wallet_provider.dart';
import '../widgets/custom_button.dart';

/// QR Scanner Screen for Payment
/// Allows users to scan QR codes to make payments
class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && !_isProcessing) {
      final String? code = barcodes.first.rawValue;
      _processQRCode(code);
    }
  }

  void _processQRCode(String? code) {
    if (code == null || _isProcessing) return;
    
    setState(() {
      _isProcessing = true;
    });
    
    // Stop camera while processing
    cameraController.stop();
    
    try {
      final paymentData = _parseQRCode(code);
      if (paymentData != null) {
        _showPaymentConfirmation(paymentData);
      } else {
        _showInvalidQRError();
      }
    } catch (e) {
      _showInvalidQRError();
    }
  }

  Map<String, String>? _parseQRCode(String qrData) {
    try {
      // Expected format: web+stellar:pay?destination=ADDRESS&amount=AMOUNT&asset_code=XLM
      if (!qrData.startsWith('web+stellar:pay?')) {
        return null;
      }
      
      final uri = Uri.parse(qrData);
      final destination = uri.queryParameters['destination'];
      final amount = uri.queryParameters['amount'];
      final assetCode = uri.queryParameters['asset_code'];
      
      if (destination == null || amount == null || assetCode != 'XLM') {
        return null;
      }
      
      // Validate amount
      final parsedAmount = double.tryParse(amount);
      if (parsedAmount == null || parsedAmount <= 0) {
        return null;
      }
      
      return {
        'destination': destination,
        'amount': amount,
        'asset_code': assetCode ?? 'XLM',
      };
    } catch (e) {
      return null;
    }
  }

  void _showPaymentConfirmation(Map<String, String> paymentData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PaymentConfirmationDialog(
        destination: paymentData['destination']!,
        amount: paymentData['amount']!,
        onConfirm: () => _executePayment(paymentData),
        onReject: _resumeScanning,
      ),
    );
  }

  void _showInvalidQRError() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: AppColors.errorRed,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'Invalid QR Code',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Text(
          'This QR Code is not compatible with Gringotts Wallet.\n\nPlease scan a valid Stellar payment QR code.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resumeScanning();
            },
            child: Text(
              'Try Again',
              style: TextStyle(
                color: AppColors.primaryPurple,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ).animate()
          .scale(duration: 300.ms, curve: Curves.elasticOut)
          .fadeIn(duration: 300.ms),
    );
  }

  Future<void> _executePayment(Map<String, String> paymentData) async {
    try {
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      
      if (!walletProvider.hasActiveWallet) {
        throw Exception('No active wallet found');
      }
      
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      final success = await walletProvider.sendTransaction(
        destinationAddress: paymentData['destination']!,
        amount: double.parse(paymentData['amount']!),
        memo: '',
      );

  // Close loading dialog
  if (mounted) Navigator.pop(context);

  if (!mounted) return;

  if (success) {
        // Show success and navigate back
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Payment sent successfully!'),
            backgroundColor: AppColors.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        Navigator.pop(context); // Close scanner
      } else {
        // Show error from provider and resume scanning
        final errorMsg = walletProvider.error ?? 'Payment failed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: $errorMsg'),
            backgroundColor: AppColors.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        _resumeScanning();
      }
      
    } catch (e) {
      // Close loading dialog if open
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: ${e.toString()}'),
          backgroundColor: AppColors.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      
      _resumeScanning();
    }
  }

  void _resumeScanning() {
    setState(() {
      _isProcessing = false;
    });
    cameraController.start();
  }

  void _toggleFlash() {
    cameraController.toggleTorch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          // QR Scanner View
          MobileScanner(
            controller: cameraController,
            onDetect: _onDetect,
          ),
          
          // Custom Overlay
          _buildScannerOverlay(),
          
          // Top App Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundDark.withOpacity(0.8),
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
                      'Scan QR Code to Pay',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _toggleFlash,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundDark.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Icon(
                        Icons.flash_on,
                        color: AppColors.textPrimary,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ).animate()
              .slideY(begin: -0.3, duration: 400.ms)
              .fadeIn(duration: 400.ms),
          
          // Bottom Instructions
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.backgroundDark.withOpacity(0.9),
                    AppColors.backgroundDark,
                  ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.qr_code_scanner,
                      color: AppColors.primaryPurple,
                      size: 32,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Position the QR code within the frame',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The camera will automatically scan and process the payment details',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ).animate()
              .slideY(begin: 0.3, duration: 400.ms)
              .fadeIn(duration: 400.ms),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return Container(
      decoration: ShapeDecoration(
        shape: QrScannerOverlayShape(
          borderColor: AppColors.primaryPurple,
          borderRadius: 20,
          borderLength: 30,
          borderWidth: 4,
          cutOutSize: 280,
        ),
      ),
    );
  }
}

/// Custom QR Scanner Overlay Shape
class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final double borderLength;
  final double borderRadius;
  final double cutOutSize;

  const QrScannerOverlayShape({
    this.borderColor = Colors.white,
    this.borderWidth = 3.0,
    this.borderLength = 40.0,
    this.borderRadius = 10.0,
    this.cutOutSize = 250.0,
  });

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path outerPath = Path()..addRect(rect);
    Path cutOutPath = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: rect.center,
          width: cutOutSize,
          height: cutOutSize,
        ),
        Radius.circular(borderRadius),
      ));
    return Path.combine(PathOperation.difference, outerPath, cutOutPath);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final center = rect.center;
    final cutOutRect = Rect.fromCenter(
      center: center,
      width: cutOutSize,
      height: cutOutSize,
    );

    canvas.save();
    canvas.clipPath(getOuterPath(rect));
    canvas.drawColor(Colors.black.withOpacity(0.5), BlendMode.srcOut);
    canvas.restore();

    final paint = Paint()
      ..color = borderColor
      ..strokeWidth = borderWidth
      ..style = PaintingStyle.stroke;

    // Draw corners
    final left = cutOutRect.left;
    final top = cutOutRect.top;
    final right = cutOutRect.right;
    final bottom = cutOutRect.bottom;

    // Top left corner
    canvas.drawPath(
      Path()
        ..moveTo(left, top + borderLength)
        ..lineTo(left, top + borderRadius)
        ..arcToPoint(Offset(left + borderRadius, top), radius: Radius.circular(borderRadius))
        ..lineTo(left + borderLength, top),
      paint,
    );

    // Top right corner
    canvas.drawPath(
      Path()
        ..moveTo(right - borderLength, top)
        ..lineTo(right - borderRadius, top)
        ..arcToPoint(Offset(right, top + borderRadius), radius: Radius.circular(borderRadius))
        ..lineTo(right, top + borderLength),
      paint,
    );

    // Bottom left corner
    canvas.drawPath(
      Path()
        ..moveTo(left, bottom - borderLength)
        ..lineTo(left, bottom - borderRadius)
        ..arcToPoint(Offset(left + borderRadius, bottom), radius: Radius.circular(borderRadius))
        ..lineTo(left + borderLength, bottom),
      paint,
    );

    // Bottom right corner
    canvas.drawPath(
      Path()
        ..moveTo(right - borderLength, bottom)
        ..lineTo(right - borderRadius, bottom)
        ..arcToPoint(Offset(right, bottom - borderRadius), radius: Radius.circular(borderRadius))
        ..lineTo(right, bottom - borderLength),
      paint,
    );
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth,
      borderLength: borderLength,
      borderRadius: borderRadius,
      cutOutSize: cutOutSize,
    );
  }
}

/// Payment Confirmation Dialog
class PaymentConfirmationDialog extends StatelessWidget {
  final String destination;
  final String amount;
  final VoidCallback onConfirm;
  final VoidCallback onReject;

  const PaymentConfirmationDialog({
    super.key,
    required this.destination,
    required this.amount,
    required this.onConfirm,
    required this.onReject,
  });

  String get _shortAddress {
    if (destination.length <= 12) return destination;
    return '${destination.substring(0, 6)}...${destination.substring(destination.length - 6)}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: AppColors.cardGradient,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryPurple.withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: 0,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.payment,
                    color: AppColors.textPrimary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Confirm Payment',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Payment Details
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment Details',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Amount
                  Row(
                    children: [
                      Icon(
                        Icons.attach_money,
                        color: AppColors.primaryPurple,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Amount:',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$amount XLM',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Destination
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet,
                        color: AppColors.primaryPurple,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'To:',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _shortAddress,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Warning
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningYellow.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warningYellow.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber,
                    color: AppColors.warningYellow,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This transaction cannot be reversed',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.warningYellow,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'Reject',
                    onPressed: () {
                      Navigator.pop(context);
                      onReject();
                    },
                    type: CustomButtonType.outlined,
                    size: CustomButtonSize.medium,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomButton(
                    text: 'Confirm',
                    onPressed: () {
                      Navigator.pop(context);
                      onConfirm();
                    },
                    size: CustomButtonSize.medium,
                    gradientColors: AppColors.primaryGradient.colors,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate()
        .scale(duration: 400.ms, curve: Curves.elasticOut)
        .fadeIn(duration: 400.ms);
  }
}