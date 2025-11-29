import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app/theme/colors.dart';
import '../providers/wallet_provider.dart';
import '../services/split_bill_service.dart';

import '../services/stellar_service.dart';
import '../services/wallet_registry_service.dart';
import '../models/split_bill_model.dart';

class SplitBillManagementScreen extends StatefulWidget {
  const SplitBillManagementScreen({super.key});

  @override
  State<SplitBillManagementScreen> createState() => _SplitBillManagementScreenState();
}

class _SplitBillManagementScreenState extends State<SplitBillManagementScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final walletProvider = Provider.of<WalletProvider>(context);
    final activeWalletName = walletProvider.activeWallet?.name;

    if (activeWalletName == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundDark,
        appBar: AppBar(
          backgroundColor: AppColors.backgroundDark,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Split Bills',
            style: TextStyle(color: AppColors.textPrimary),
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.backgroundGradient,
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  size: 64,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No Active Wallet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please create or select a wallet first',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Split Bills',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryPurple,
          labelColor: AppColors.primaryPurple,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: 'Created by Me'),
            Tab(text: 'Invited to'),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildCreatedBillsTab(activeWalletName),
            _buildInvitedBillsTab(activeWalletName),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatedBillsTab(String activeWalletName) {
    return StreamBuilder<QuerySnapshot>(
      stream: SplitBillService.getCreatedSplitBills(activeWalletName),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading split bills',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final splitBills = snapshot.data?.docs ?? [];

        if (splitBills.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.receipt_long,
                  size: 64,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No Split Bills Created',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create your first split bill to get started',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: splitBills.length,
          itemBuilder: (context, index) {
            final doc = splitBills[index];
            final splitBill = SplitBillModel.fromFirestore(doc);
            return _buildSplitBillCard(splitBill, activeWalletName, isCreator: true);
          },
        );
      },
    );
  }

  Widget _buildInvitedBillsTab(String activeWalletName) {
    return StreamBuilder<QuerySnapshot>(
      stream: SplitBillService.getInvitedSplitBills(activeWalletName),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading invitations',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          );
        }

        final splitBills = snapshot.data?.docs ?? [];

        if (splitBills.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.groups,
                  size: 64,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No Invitations',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You haven\'t been invited to any split bills yet',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        // Split bills are already filtered by participantWalletNames query
        // But we need to exclude bills where user is the creator
        final invitedSplitBills = splitBills.where((doc) {
          final splitBill = SplitBillModel.fromFirestore(doc);
          final isCreator = splitBill.creatorWalletName == activeWalletName;
          // Use participantWalletNames array instead of participants list for consistency
          final isParticipant = splitBill.participantWalletNames?.contains(activeWalletName) ?? false;
          
          // User should be a participant but not the creator
          return !isCreator && isParticipant;
        }).toList();

        if (invitedSplitBills.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.groups,
                  size: 64,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No Invitations',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You haven\'t been invited to any split bills yet',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: invitedSplitBills.length,
          itemBuilder: (context, index) {
            final doc = invitedSplitBills[index];
            final splitBill = SplitBillModel.fromFirestore(doc);
            return _buildSplitBillCard(splitBill, activeWalletName, isCreator: false);
          },
        );
      },
    );
  }

  Widget _buildSplitBillCard(
    SplitBillModel splitBill,
    String activeWalletName, {
    required bool isCreator,
  }) {
    final isCompleted = splitBill.isCompleted;
    final perPersonShare = _calculateShare(splitBill);
    final participantsAmountsDebug = splitBill.participants
        .map((p) => '${p.walletName}:${p.amount.toStringAsFixed(7)}')
        .join(', ');

    debugPrint(
      '[SplitBill] id:${splitBill.id} desc:${splitBill.description} total:${splitBill.totalAmount} '
      'invited:${splitBill.participants.length} totalPeople:${_getTotalParticipantCount(splitBill)} '
      'perShare:${perPersonShare.toStringAsFixed(7)} paid:${_getPaidCount(splitBill)} '
      'participantAmounts:${participantsAmountsDebug}',
    );

    // Find my participant record (will be null if I'm the creator)
    final myParticipant = splitBill.participants.where(
      (p) => p.walletName == activeWalletName,
    ).firstOrNull;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: isCompleted ? AppColors.accentGradient : AppColors.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted ? Colors.green.withOpacity(0.3) : AppColors.borderLight,
          width: isCompleted ? 2 : 1,
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCompleted 
                        ? Colors.green.withOpacity(0.2)
                        : AppColors.primaryPurple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isCompleted ? Icons.check_circle : Icons.receipt_long,
                    color: isCompleted ? Colors.green : AppColors.primaryPurple,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        splitBill.description,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isCompleted ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isCreator ? 'Created by you' : 'Created by @${splitBill.creatorWalletName}',
                        style: TextStyle(
                          fontSize: 14,
                          color: isCompleted 
                              ? Colors.white.withOpacity(0.8)
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCompleted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'COMPLETED',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 20),

            // Amount Info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Amount',
                      style: TextStyle(
                        fontSize: 14,
                        color: isCompleted 
                            ? Colors.white.withOpacity(0.8)
                            : AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '${splitBill.totalAmount.toStringAsFixed(7)} XLM',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isCompleted ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                if (!isCreator && myParticipant != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Your Share',
                        style: TextStyle(
                          fontSize: 14,
                          color: isCompleted 
                              ? Colors.white.withOpacity(0.8)
                              : AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '${perPersonShare.toStringAsFixed(7)} XLM',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isCompleted ? Colors.white : AppColors.primaryPurple,
                        ),
                      ),
                    ],
                  ),
                if (isCreator)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'You Created This',
                        style: TextStyle(
                          fontSize: 14,
                          color: isCompleted 
                              ? Colors.white.withOpacity(0.8)
                              : AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        'Collecting Payments',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isCompleted ? Colors.white : AppColors.primaryPurple,
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Participants Progress
            Row(
              children: [
                Icon(
                  Icons.groups,
                  size: 20,
                  color: isCompleted 
                      ? Colors.white.withOpacity(0.8)
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Participants: ${_getPaidCount(splitBill)}/${_getTotalParticipantCount(splitBill)} paid',
                  style: TextStyle(
                    fontSize: 14,
                    color: isCompleted 
                        ? Colors.white.withOpacity(0.8)
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Payment Status (only show if user is a participant)
            if (!isCreator && myParticipant != null && !myParticipant.isPaid)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.payment,
                      color: Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Payment pending - ${perPersonShare.toStringAsFixed(7)} XLM',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: ElevatedButton(
                        onPressed: () => _payShare(splitBill, myParticipant),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Pay Now',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            if (!isCreator && myParticipant != null && myParticipant.isPaid)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'You have paid ${perPersonShare.toStringAsFixed(7)} XLM',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),

            // Created date
            const SizedBox(height: 12),
            Text(
              'Created ${_formatDate(splitBill.createdAt)}',
              style: TextStyle(
                fontSize: 12,
                color: isCompleted 
                    ? Colors.white.withOpacity(0.6)
                    : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  void _payShare(SplitBillModel splitBill, SplitParticipant participant) {
    final perPersonShare = _calculateShare(splitBill);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: Text(
          'Confirm Payment',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to pay your share?',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primaryPurple.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Description: ${splitBill.description}',
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Amount: ${perPersonShare.toStringAsFixed(7)} XLM',
                    style: TextStyle(color: AppColors.primaryPurple, fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Recipient: ${splitBill.creatorWalletName}',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Payment will be sent directly to the split bill creator.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => _processSplitPayment(splitBill, participant),
            child: Text(
              'Confirm Payment',
              style: TextStyle(color: AppColors.primaryPurple, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processSplitPayment(SplitBillModel splitBill, SplitParticipant participant) async {
    Navigator.pop(context); // Close dialog
    
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Processing payment...',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
      );

      // Get current wallet for payment
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      final currentWallet = walletProvider.activeWallet;
      
      if (currentWallet == null) {
        throw Exception('No wallet selected');
      }

      // Get creator's public key from wallet registry
      final creatorPublicKey = await WalletRegistryService.resolveWalletName(splitBill.creatorWalletName);
      if (creatorPublicKey == null) {
        throw Exception('Creator wallet not found in registry');
      }

      // Send actual Stellar payment
      final secretKey = currentWallet.secretKey;
      if (secretKey == null) {
        throw Exception('Wallet secret key not available');
      }
      
      final paymentAmount = splitBill.amountPerParticipant;
      
      final transaction = await StellarService.sendPayment(
        secretKey: secretKey,
        destinationAddress: creatorPublicKey,
        amount: paymentAmount,
        memo: 'Split Bill: ${splitBill.description}',
      );
      
      final transactionHash = transaction.hash;
      
      // Update split bill with payment
      await SplitBillService.processPayment(
        splitBillId: splitBill.id,
        participantWalletName: participant.walletName,
        transactionHash: transactionHash,
      );

      Navigator.pop(context); // Close loading dialog
      
      // Refresh wallet balance after successful payment
      await walletProvider.refreshBalance();

      // Show success
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Payment Successful',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          content: Text(
            'Your payment of ${paymentAmount.toStringAsFixed(7)} XLM has been processed successfully!',
            style: TextStyle(color: AppColors.textPrimary),
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

    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      
      // Show error
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          title: Row(
            children: [
              Icon(Icons.error, color: Colors.red, size: 28),
              const SizedBox(width: 12),
              Text(
                'Payment Failed',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ],
          ),
          content: Text(
            'Failed to process payment: $e',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'OK',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      );
    }
  }

  double _calculateShare(SplitBillModel splitBill) {
    return splitBill.amountPerParticipant;
  }

  int _getPaidCount(SplitBillModel splitBill) {
    final invitedCount = splitBill.participantWalletNames?.length ?? splitBill.participants.length;
    final paidParticipants = splitBill.participants.where((p) => p.isPaid).length;
    final totalPeople = splitBill.totalPeople;

    // Creator is assumed paid on creation, so start from 1
    final paidWithCreator = paidParticipants + 1;
    return paidWithCreator > totalPeople ? totalPeople : paidWithCreator;
  }

  int _getTotalParticipantCount(SplitBillModel splitBill) {
    return splitBill.totalPeople;
  }
}
