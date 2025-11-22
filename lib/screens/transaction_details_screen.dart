import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/wallet_model.dart';
import '../app/theme/colors.dart';
import '../app/constants.dart';
import '../services/stellar_service.dart';

/// Transaction Details Screen
/// Shows comprehensive transaction information
class TransactionDetailsScreen extends StatefulWidget {
  final TransactionModel transaction;

  const TransactionDetailsScreen({
    super.key,
    required this.transaction,
  });

  @override
  State<TransactionDetailsScreen> createState() => _TransactionDetailsScreenState();
}

class _TransactionDetailsScreenState extends State<TransactionDetailsScreen> {
  bool _isLoadingExplorer = false;

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTransactionHeader(),
                      const SizedBox(height: 24),
                      _buildTransactionDetails(),
                      const SizedBox(height: 24),
                      _buildActionButtons(),
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
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Text(
            'Transaction Details',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ).animate(delay: 100.ms)
        .slideX(begin: -0.3, duration: 500.ms)
        .fadeIn(duration: 500.ms);
  }

  Widget _buildTransactionHeader() {
    final isIncoming = widget.transaction.type == TransactionType.received;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            (isIncoming ? AppColors.successGreen : AppColors.secondaryBlue).withOpacity(0.1),
            (isIncoming ? AppColors.successGreen : AppColors.secondaryBlue).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isIncoming ? AppColors.successGreen : AppColors.secondaryBlue).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isIncoming
                  ? [AppColors.successGreen, AppColors.successGreen.withOpacity(0.7)]
                  : [AppColors.secondaryBlue, AppColors.secondaryBlue.withOpacity(0.7)],
              ),
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: (isIncoming ? AppColors.successGreen : AppColors.secondaryBlue).withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              isIncoming ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isIncoming ? 'Received' : 'Sent',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${isIncoming ? '+' : '-'}${widget.transaction.amount.toStringAsFixed(7)} ${widget.transaction.assetCode}',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: isIncoming ? AppColors.successGreen : AppColors.secondaryBlue,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatDate(widget.transaction.createdAt),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    ).animate(delay: 200.ms)
        .slideY(begin: 0.3, duration: 600.ms)
        .fadeIn(duration: 600.ms);
  }

  Widget _buildTransactionDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transaction Information',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        _buildDetailCard(),
      ],
    ).animate(delay: 400.ms)
        .slideY(begin: 0.3, duration: 600.ms)
        .fadeIn(duration: 600.ms);
  }

  Widget _buildDetailCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildDetailRow(
            'Transaction Hash',
            widget.transaction.hash,
            isHashValue: true,
          ),
          _buildDivider(),
          _buildDetailRow(
            'From',
            widget.transaction.sourceAccount,
            isAddress: true,
          ),
          _buildDivider(),
          _buildDetailRow(
            'To',
            widget.transaction.destinationAccount,
            isAddress: true,
          ),
          _buildDivider(),
          _buildDetailRow(
            'Amount',
            '${widget.transaction.amount.toStringAsFixed(7)} ${widget.transaction.assetCode}',
          ),
          _buildDivider(),
          _buildDetailRow(
            'Network Fee',
            '${widget.transaction.fee.toStringAsFixed(7)} XLM',
          ),
          _buildDivider(),
          _buildDetailRow(
            'Status',
            widget.transaction.status.name.toUpperCase(),
            isStatus: true,
          ),
          if (widget.transaction.memo.isNotEmpty) ...[
            _buildDivider(),
            _buildDetailRow(
              'Memo',
              widget.transaction.memo,
              isMemo: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isHashValue = false,
    bool isAddress = false,
    bool isStatus = false,
    bool isMemo = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _copyToClipboard(value, label),
                  child: Text(
                    isHashValue || isAddress
                      ? '${value.substring(0, 6)}...${value.substring(value.length - 6)}'
                      : value,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: isStatus
                        ? (widget.transaction.status == TransactionStatus.success
                            ? AppColors.successGreen
                            : AppColors.errorRed)
                        : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontFamily: isHashValue || isAddress ? 'monospace' : null,
                    ),
                  ),
                ),
              ),
              if (isHashValue || isAddress || isMemo)
                IconButton(
                  icon: Icon(
                    Icons.copy,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                  onPressed: () => _copyToClipboard(value, label),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      color: AppColors.borderLight.withOpacity(0.5),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: _openInExplorer,
          icon: _isLoadingExplorer
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.open_in_new, color: Colors.white),
          label: Text(
            'Copy Explorer URL',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryPurple,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
        ).animate(delay: 600.ms)
            .slideY(begin: 0.3, duration: 500.ms)
            .fadeIn(duration: 500.ms),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _shareTransaction(),
          icon: const Icon(Icons.share, color: AppColors.primaryPurple),
          label: const Text(
            'Share Transaction',
            style: TextStyle(
              color: AppColors.primaryPurple,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            side: const BorderSide(color: AppColors.primaryPurple),
          ),
        ).animate(delay: 700.ms)
            .slideY(begin: 0.3, duration: 500.ms)
            .fadeIn(duration: 500.ms),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    
    return '$day $month $year at $hour:$minute';
  }

  void _copyToClipboard(String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        backgroundColor: AppColors.successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Future<void> _openInExplorer() async {
    setState(() {
      _isLoadingExplorer = true;
    });

    try {
      final network = StellarService.currentNetwork;
      final explorerUrl = network.isTestnet
        ? '${AppConstants.stellarExplorerTestnet}/tx/${widget.transaction.hash}'
        : '${AppConstants.stellarExplorerMainnet}/tx/${widget.transaction.hash}';
      
      // Copy explorer URL to clipboard
      await Clipboard.setData(ClipboardData(text: explorerUrl));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Explorer URL copied to clipboard!'),
            backgroundColor: AppColors.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not copy explorer URL'),
            backgroundColor: AppColors.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingExplorer = false;
        });
      }
    }
  }

  void _shareTransaction() {
    final network = StellarService.currentNetwork;
    final explorerUrl = network.isTestnet
      ? '${AppConstants.stellarExplorerTestnet}/tx/${widget.transaction.hash}'
      : '${AppConstants.stellarExplorerMainnet}/tx/${widget.transaction.hash}';
    
    final shareText = '''
🏦 Stellar Transaction Details

💰 Amount: ${widget.transaction.amount.toStringAsFixed(7)} ${widget.transaction.assetCode}
📅 Date: ${_formatDate(widget.transaction.createdAt)}
🔗 Hash: ${widget.transaction.hash}
${widget.transaction.memo.isNotEmpty ? '📝 Memo: ${widget.transaction.memo}' : ''}

View in Explorer: $explorerUrl
    '''.trim();

    // Using platform share functionality would require platform channels
    // For now, copy to clipboard
    _copyToClipboard(shareText, 'Transaction details');
  }
}