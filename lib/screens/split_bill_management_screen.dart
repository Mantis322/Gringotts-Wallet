import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app/theme/colors.dart';
import '../providers/wallet_provider.dart';
import '../services/split_bill_service.dart';
import '../services/firebase_cleanup_service.dart';
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
  String? _activeWalletName;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Get active wallet name
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    _activeWalletName = walletProvider.activeWallet?.name;
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
    if (_activeWalletName == null) {
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
        actions: [
          // Debug button - sadece geliştirme için
          if (kDebugMode)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: AppColors.textPrimary),
              onSelected: (value) async {
                if (value == 'cleanup') {
                  await FirebaseCleanupService.listAllSplitBillCollections();
                  await FirebaseCleanupService.addParticipantWalletNamesToExistingDocs();
                } else if (value == 'migrate') {
                  await FirebaseCleanupService.migrateSplitRequestsToSplitBills();
                } else if (value == 'fix_creator') {
                  await FirebaseCleanupService.fixCreatorStatusInExistingBills();
                } else if (value == 'clean_names') {
                  await FirebaseCleanupService.cleanWalletNamesInExistingBills();
                } else if (value == 'remove_creators') {
                  await FirebaseCleanupService.removeCreatorFromParticipants();
                } else if (value == 'full_cleanup') {
                  // Tam temizlik
                  await FirebaseCleanupService.removeCreatorFromParticipants();
                  await FirebaseCleanupService.cleanWalletNamesInExistingBills();
                  await FirebaseCleanupService.fixCreatorStatusInExistingBills();
                  await FirebaseCleanupService.addParticipantWalletNamesToExistingDocs();
                  // split_requests collection'ını temizle
                  await FirebaseCleanupService.cleanupSplitRequestsCollection();
                } else if (value == 'delete_requests') {
                  await FirebaseCleanupService.cleanupSplitRequestsCollection();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'full_cleanup',
                  child: Text('🔧 Full Cleanup'),
                ),
                const PopupMenuItem(
                  value: 'fix_creator',
                  child: Text('Fix Creator Status'),
                ),
                const PopupMenuItem(
                  value: 'clean_names',
                  child: Text('Clean Wallet Names'),
                ),
                const PopupMenuItem(
                  value: 'remove_creators',
                  child: Text('🚫 Remove Creators from Participants'),
                ),
                const PopupMenuItem(
                  value: 'cleanup',
                  child: Text('Fix Existing Docs'),
                ),
                const PopupMenuItem(
                  value: 'migrate',
                  child: Text('Migrate split_requests'),
                ),
                const PopupMenuItem(
                  value: 'delete_requests',
                  child: Text('🗑️ Delete split_requests'),
                ),
              ],
            ),
        ],
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
            KeepAlive(keepAlive: true, child: _buildCreatedBillsTab()),
            KeepAlive(keepAlive: true, child: _buildInvitedBillsTab()),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatedBillsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: SplitBillService.getCreatedSplitBills(_activeWalletName!),
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
            return _buildSplitBillCard(splitBill, isCreator: true);
          },
        );
      },
    );
  }

  Widget _buildInvitedBillsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: SplitBillService.getInvitedSplitBills(_activeWalletName!),
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
        debugPrint('Invited to - Total docs from query: ${splitBills.length}');
        debugPrint('Active wallet name: $_activeWalletName');
        
        final invitedSplitBills = splitBills.where((doc) {
          final splitBill = SplitBillModel.fromFirestore(doc);
          final isCreator = splitBill.creatorWalletName == _activeWalletName;
          // Use participantWalletNames array instead of participants list for consistency
          final isParticipant = splitBill.participantWalletNames?.contains(_activeWalletName) ?? false;
          
          debugPrint('Doc ${doc.id}: creator=${splitBill.creatorWalletName}, isCreator=$isCreator, isParticipant=$isParticipant');
          debugPrint('  participantWalletNames: ${splitBill.participantWalletNames}');
          debugPrint('  participants count: ${splitBill.participants.length}');
          
          // User should be a participant but not the creator
          return !isCreator && isParticipant;
        }).toList();
        
        debugPrint('Filtered invited bills: ${invitedSplitBills.length}');

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
            return _buildSplitBillCard(splitBill, isCreator: false);
          },
        );
      },
    );
  }

  Widget _buildSplitBillCard(SplitBillModel splitBill, {required bool isCreator}) {
    final isCompleted = splitBill.isCompleted;
    
    // Find my participant record (will be null if I'm the creator)
    final myParticipant = splitBill.participants.where(
      (p) => p.walletName == _activeWalletName,
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
                        '${myParticipant.amount.toStringAsFixed(7)} XLM',
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
                  'Participants: ${splitBill.participants.where((p) => p.isPaid).length}/${splitBill.participants.length} paid',
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
                        'Payment pending - ${myParticipant.amount.toStringAsFixed(7)} XLM',
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
                    const Text(
                      'You have paid your share',
                      style: TextStyle(
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
                    'Amount: ${participant.amount.toStringAsFixed(7)} XLM',
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
      
      final transaction = await StellarService.sendPayment(
        secretKey: secretKey,
        destinationAddress: creatorPublicKey,
        amount: participant.amount,
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
            'Your payment of ${participant.amount.toStringAsFixed(7)} XLM has been processed successfully!',
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
}