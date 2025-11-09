import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../app/theme/colors.dart';
import '../app/routes.dart';

class ReceiveOptionsModal extends StatelessWidget {
  const ReceiveOptionsModal({super.key});

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
              'Receive XLM',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ).animate(delay: 100.ms)
                .slideY(begin: 0.3, duration: 400.ms)
                .fadeIn(duration: 400.ms),
            
            const SizedBox(height: 8),
            
            Text(
              'Choose how you want to receive XLM',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ).animate(delay: 200.ms)
                .slideY(begin: 0.3, duration: 400.ms)
                .fadeIn(duration: 400.ms),
            
            const SizedBox(height: 32),
            
            // Receive Options
            ReceiveOptionCard(
              icon: Icons.qr_code_scanner,
              title: 'Receive with QR Code',
              subtitle: 'Show your QR code to sender',
              onTap: () {
                Navigator.pop(context);
                AppRoutes.push(context, AppRoutes.qrReceive);
              },
              gradient: AppColors.accentGradient,
            ).animate(delay: 300.ms)
                .slideX(begin: -0.3, duration: 500.ms)
                .fadeIn(duration: 500.ms),
            
            const SizedBox(height: 16),
            
            ReceiveOptionCard(
              icon: Icons.pin,
              title: 'Receive with PIN Code',
              subtitle: 'Generate a 6-digit PIN for payment',
              onTap: () {
                Navigator.pop(context);
                AppRoutes.push(context, AppRoutes.pinReceive);
              },
              gradient: AppColors.primaryGradient,
            ).animate(delay: 400.ms)
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
            ).animate(delay: 500.ms)
                .slideY(begin: 0.3, duration: 400.ms)
                .fadeIn(duration: 400.ms),
          ],
        ),
      ),
    );
  }


}

class ReceiveOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final LinearGradient gradient;

  const ReceiveOptionCard({
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