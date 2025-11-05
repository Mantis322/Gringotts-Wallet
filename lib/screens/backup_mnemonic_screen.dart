import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../app/theme/colors.dart';
import '../widgets/custom_button.dart';

class BackupMnemonicScreen extends StatefulWidget {
  final List<String> mnemonic;
  final VoidCallback onContinue;

  const BackupMnemonicScreen({
    super.key,
    required this.mnemonic,
    required this.onContinue,
  });

  @override
  State<BackupMnemonicScreen> createState() => _BackupMnemonicScreenState();
}

class _BackupMnemonicScreenState extends State<BackupMnemonicScreen> {
  bool _isHidden = true;
  bool _isAgreed = false;

  void _copyMnemonic() {
    final mnemonicText = widget.mnemonic.join(' ');
    Clipboard.setData(ClipboardData(text: mnemonicText));
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Mnemonic phrase copied to clipboard'),
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
          'Backup Wallet',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 32),
                      _buildMnemonicCard(),
                      const SizedBox(height: 24),
                      _buildWarningSection(),
                      const SizedBox(height: 24),
                      _buildAgreementSection(),
                    ],
                  ),
                ),
              ),
              _buildContinueButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryPurple.withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.security,
            color: AppColors.textPrimary,
            size: 40,
          ),
        ).animate(delay: 200.ms)
            .scale(duration: 600.ms, curve: Curves.elasticOut)
            .then()
            .shimmer(duration: 2000.ms, color: AppColors.accentGold.withOpacity(0.3)),

        const SizedBox(height: 24),

        Text(
          'Secret Recovery Phrase',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ).animate(delay: 400.ms)
            .slideY(begin: 0.3, duration: 600.ms)
            .fadeIn(duration: 600.ms),

        const SizedBox(height: 12),

        Text(
          'Write down these 12 words in the exact order shown. Keep them safe and never share them with anyone.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ).animate(delay: 600.ms)
            .slideY(begin: 0.3, duration: 600.ms)
            .fadeIn(duration: 600.ms),
      ],
    );
  }

  Widget _buildMnemonicCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowMedium,
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Secret Phrase',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: _copyMnemonic,
                    icon: const Icon(Icons.copy, color: AppColors.primaryPurple),
                    tooltip: 'Copy to clipboard',
                  ),
                  IconButton(
                    onPressed: () => setState(() => _isHidden = !_isHidden),
                    icon: Icon(
                      _isHidden ? Icons.visibility : Icons.visibility_off,
                      color: AppColors.primaryPurple,
                    ),
                    tooltip: _isHidden ? 'Show phrase' : 'Hide phrase',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isHidden)
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surfaceCard.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.visibility_off,
                    color: AppColors.textSecondary,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the eye icon to reveal your secret phrase',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            _buildMnemonicGrid(),
        ],
      ),
    ).animate(delay: 800.ms)
        .slideY(begin: 0.3, duration: 600.ms)
        .fadeIn(duration: 600.ms);
  }

  Widget _buildMnemonicGrid() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 2.5,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: widget.mnemonic.length,
        itemBuilder: (context, index) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              gradient: AppColors.accentGradient,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              children: [
                Text(
                  '${index + 1}.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    widget.mnemonic[index],
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ).animate(delay: (index * 50).ms)
              .slideX(begin: 0.3, duration: 400.ms)
              .fadeIn(duration: 400.ms);
        },
      ),
    );
  }

  Widget _buildWarningSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warningYellow.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warningYellow.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AppColors.warningYellow,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Important Security Notice',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.warningYellow,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '• Never share your secret phrase with anyone\n'
            '• Store it offline in a secure location\n'
            '• Anyone with access to this phrase can control your wallet\n'
            '• We cannot recover your wallet if you lose this phrase',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    ).animate(delay: 1000.ms)
        .slideY(begin: 0.3, duration: 600.ms)
        .fadeIn(duration: 600.ms);
  }

  Widget _buildAgreementSection() {
    return GestureDetector(
      onTap: () => setState(() => _isAgreed = !_isAgreed),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppColors.cardGradient,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isAgreed ? AppColors.primaryPurple : AppColors.borderLight,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                gradient: _isAgreed ? AppColors.primaryGradient : null,
                color: _isAgreed ? null : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _isAgreed ? AppColors.primaryPurple : AppColors.borderLight,
                ),
              ),
              child: _isAgreed
                  ? const Icon(
                      Icons.check,
                      color: AppColors.textPrimary,
                      size: 16,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'I understand that I am responsible for saving my secret recovery phrase, and that it is the only way to recover my wallet.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate(delay: 1200.ms)
        .slideY(begin: 0.3, duration: 600.ms)
        .fadeIn(duration: 600.ms);
  }

  Widget _buildContinueButton() {
    return CustomButton(
      text: 'I\'ve Saved My Secret Phrase',
      onPressed: _isAgreed ? widget.onContinue : null,
      type: _isAgreed ? CustomButtonType.primary : CustomButtonType.ghost,
      icon: const Icon(Icons.check_circle_outline, color: AppColors.textPrimary),
    ).animate(delay: 1400.ms)
        .slideY(begin: 0.3, duration: 600.ms)
        .fadeIn(duration: 600.ms);
  }
}