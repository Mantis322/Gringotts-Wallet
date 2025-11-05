import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../app/theme/colors.dart';
import '../widgets/custom_button.dart';

class BackupSecretKeyScreen extends StatefulWidget {
  final String secretKey;
  final VoidCallback onContinue;

  const BackupSecretKeyScreen({
    super.key,
    required this.secretKey,
    required this.onContinue,
  });

  @override
  State<BackupSecretKeyScreen> createState() => _BackupSecretKeyScreenState();
}

class _BackupSecretKeyScreenState extends State<BackupSecretKeyScreen> {
  bool _isHidden = true;
  bool _isAgreed = false;

  void _copySecretKey() {
    Clipboard.setData(ClipboardData(text: widget.secretKey));
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Secret key copied to clipboard'),
        backgroundColor: AppColors.primaryPurple,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Backup Secret Key',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  'Save Your Secret Key',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ).animate(delay: 200.ms)
                    .slideX(begin: 0.3, duration: 600.ms)
                    .fadeIn(duration: 600.ms),

                const SizedBox(height: 16),

                Text(
                  'This is your wallet\'s secret key. Keep it safe and private.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ).animate(delay: 400.ms)
                    .slideX(begin: 0.3, duration: 600.ms)
                    .fadeIn(duration: 600.ms),

                const SizedBox(height: 32),

                // Secret Key Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderLight),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Secret Key',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _isHidden = !_isHidden;
                                  });
                                },
                                icon: Icon(
                                  _isHidden ? Icons.visibility : Icons.visibility_off,
                                  color: AppColors.primaryPurple,
                                ),
                              ),
                              IconButton(
                                onPressed: _copySecretKey,
                                icon: Icon(
                                  Icons.copy,
                                  color: AppColors.primaryPurple,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundDark.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderLight.withOpacity(0.3)),
                        ),
                        child: Text(
                          _isHidden 
                              ? '•' * widget.secretKey.length
                              : widget.secretKey,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textPrimary,
                            fontFamily: 'monospace',
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate(delay: 600.ms)
                    .slideY(begin: 0.3, duration: 600.ms)
                    .fadeIn(duration: 600.ms),

                const SizedBox(height: 32),

                // Warning Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.orange,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Important Warning',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '• Never share your secret key with anyone\n'
                        '• Store it securely offline\n'
                        '• Anyone with this key can access your wallet\n'
                        '• We cannot recover your secret key if lost',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ).animate(delay: 800.ms)
                    .slideY(begin: 0.3, duration: 600.ms)
                    .fadeIn(duration: 600.ms),

                const SizedBox(height: 24),

                // Confirmation Checkbox
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Row(
                    children: [
                      Transform.scale(
                        scale: 1.2,
                        child: Checkbox(
                          value: _isAgreed,
                          onChanged: (value) {
                            setState(() {
                              _isAgreed = value ?? false;
                            });
                          },
                          activeColor: AppColors.primaryPurple,
                          checkColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'I have saved my secret key securely',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate(delay: 1000.ms)
                    .slideY(begin: 0.3, duration: 600.ms)
                    .fadeIn(duration: 600.ms),

                const SizedBox(height: 24),

                // Continue Button
                CustomButton(
                  text: 'Continue to Wallet',
                  onPressed: _isAgreed ? widget.onContinue : null,
                  isLoading: false,
                  icon: const Icon(Icons.arrow_forward),
                ).animate(delay: 1200.ms)
                    .slideY(begin: 0.3, duration: 600.ms)
                    .fadeIn(duration: 600.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}