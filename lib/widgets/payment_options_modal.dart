import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../app/theme/colors.dart';
import '../app/routes.dart';

class PaymentOptionsModal extends StatelessWidget {
  const PaymentOptionsModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.backgroundGradient,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ).animate()
                .slideY(begin: -0.3, duration: 300.ms)
                .fadeIn(duration: 300.ms),
            
            const SizedBox(height: 24),
            
            // Title
            Text(
              'Make a Payment',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ).animate(delay: 100.ms)
                .slideY(begin: 0.3, duration: 400.ms)
                .fadeIn(duration: 400.ms),
            
            const SizedBox(height: 8),
            
            Text(
              'Choose your preferred payment method',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ).animate(delay: 200.ms)
                .slideY(begin: 0.3, duration: 400.ms)
                .fadeIn(duration: 400.ms),
            
            const SizedBox(height: 32),
            
            // Payment Options
            PaymentOptionCard(
              icon: Icons.qr_code_scanner,
              title: 'Make a Payment with QR Code',
              subtitle: 'Scan recipient\'s QR code',
              onTap: () => _showComingSoon(context, 'QR Code Payment'),
              gradient: AppColors.accentGradient,
            ).animate(delay: 300.ms)
                .slideX(begin: -0.3, duration: 500.ms)
                .fadeIn(duration: 500.ms),
            
            const SizedBox(height: 16),
            
            PaymentOptionCard(
              icon: Icons.nfc,
              title: 'Make a Payment with NFC',
              subtitle: 'Tap to pay with NFC',
              onTap: () => _showComingSoon(context, 'NFC Payment'),
              gradient: AppColors.goldGradient,
            ).animate(delay: 400.ms)
                .slideX(begin: 0.3, duration: 500.ms)
                .fadeIn(duration: 500.ms),
            
            const SizedBox(height: 16),
            
            PaymentOptionCard(
              icon: Icons.send,
              title: 'Transfer XLM',
              subtitle: 'Traditional wallet transfer',
              onTap: () {
                Navigator.pop(context);
                AppRoutes.push(context, AppRoutes.send);
              },
              gradient: AppColors.primaryGradient,
            ).animate(delay: 500.ms)
                .slideX(begin: -0.3, duration: 500.ms)
                .fadeIn(duration: 500.ms),
            
            const SizedBox(height: 24),
            
            // Close button
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ).animate(delay: 600.ms)
                .slideY(begin: 0.3, duration: 400.ms)
                .fadeIn(duration: 400.ms),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    Navigator.pop(context); // Close the modal first
    
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
              Icons.construction,
              color: AppColors.warningYellow,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'Coming Soon',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Text(
          '$feature is currently under development.\n\nThis feature will be available in a future update with enhanced security and magical user experience.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Got it',
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
}

class PaymentOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final LinearGradient gradient;

  const PaymentOptionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.cardGradient,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.borderLight,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowMedium,
                blurRadius: 10,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: gradient.colors.first.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: AppColors.textPrimary,
                  size: 24,
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Arrow icon
              Icon(
                Icons.arrow_forward_ios,
                color: AppColors.textSecondary,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}