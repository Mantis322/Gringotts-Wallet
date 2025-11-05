import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../app/theme/colors.dart';

/// Premium Wallet Card Component
/// Glass morphism card for wallet creation and import options
class WalletCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;
  final bool isRecommended;
  final LinearGradient? gradient;

  const WalletCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
    this.isRecommended = false,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: gradient ?? AppColors.cardGradient,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isRecommended 
                ? AppColors.primaryPurple 
                : AppColors.borderLight,
            width: isRecommended ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isRecommended 
                  ? AppColors.primaryPurple.withOpacity(0.2)
                  : AppColors.shadowMedium,
              blurRadius: isRecommended ? 20 : 10,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon container
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: isRecommended 
                    ? AppColors.primaryGradient 
                    : AppColors.accentGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: (isRecommended 
                        ? AppColors.primaryPurple 
                        : AppColors.secondaryBlue).withOpacity(0.3),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: AppColors.textPrimary,
                size: 28,
              ),
            ).animate(delay: 200.ms)
                .scale(duration: 600.ms, curve: Curves.elasticOut)
                .then()
                .shimmer(duration: 2000.ms, color: AppColors.accentGold.withOpacity(0.2)),

            const SizedBox(width: 16),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isRecommended) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            gradient: AppColors.goldGradient,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accentGold.withOpacity(0.3),
                                blurRadius: 4,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: Text(
                            'REC',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.textDark,
                              fontWeight: FontWeight.w700,
                              fontSize: 8,
                            ),
                          ),
                        ).animate(delay: 400.ms)
                            .scale(duration: 400.ms)
                            .then()
                            .shimmer(duration: 1500.ms, color: Colors.white.withOpacity(0.5)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            // Arrow icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.glassLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Icon(
                Icons.arrow_forward_ios,
                color: AppColors.textTertiary,
                size: 16,
              ),
            ),
          ],
        ),
      ).animate(delay: 300.ms)
          .slideX(begin: 0.3, duration: 600.ms)
          .fadeIn(duration: 600.ms),
    );
  }
}

/// Transaction Card Component
/// Displays transaction history items
class TransactionCard extends StatelessWidget {
  final String hash;
  final String type;
  final String amount;
  final String date;
  final bool isIncoming;
  final VoidCallback? onTap;

  const TransactionCard({
    super.key,
    required this.hash,
    required this.type,
    required this.amount,
    required this.date,
    required this.isIncoming,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Transaction type icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isIncoming 
                    ? AppColors.successGreen.withOpacity(0.2)
                    : AppColors.secondaryBlue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isIncoming 
                      ? AppColors.successGreen
                      : AppColors.secondaryBlue,
                ),
              ),
              child: Icon(
                isIncoming ? Icons.arrow_downward : Icons.arrow_upward,
                color: isIncoming 
                    ? AppColors.successGreen
                    : AppColors.secondaryBlue,
                size: 20,
              ),
            ),

            const SizedBox(width: 12),

            // Transaction details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isIncoming ? 'Received' : 'Sent',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hash,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    date,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),

            // Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isIncoming ? '+' : '-'}$amount XLM',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: isIncoming 
                        ? AppColors.successGreen
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Icon(
                  Icons.arrow_forward_ios,
                  color: AppColors.textTertiary,
                  size: 12,
                ),
              ],
            ),
          ],
        ),
      ).animate(delay: 100.ms)
          .slideX(begin: 0.2, duration: 400.ms)
          .fadeIn(duration: 400.ms),
    );
  }
}

/// Quick Action Card Component
/// Action buttons for home screen
class QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final LinearGradient? gradient;

  const QuickActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: gradient ?? AppColors.cardGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowMedium,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
                icon,
                color: AppColors.textPrimary,
                size: 24,
              ),
            ).animate(delay: 200.ms)
                .scale(duration: 400.ms, curve: Curves.elasticOut),

            const SizedBox(height: 12),

            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 4),

            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ).animate(delay: 300.ms)
          .slideY(begin: 0.3, duration: 500.ms)
          .fadeIn(duration: 500.ms),
    );
  }
}