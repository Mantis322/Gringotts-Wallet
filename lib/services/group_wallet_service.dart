import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';
import '../models/group_wallet_model.dart';
import '../models/wallet_model.dart';
import '../services/stellar_service.dart';
import '../services/wallet_registry_service.dart';

/// Group Wallet Service
/// Manages multi-signature group wallets with contribution tracking
class GroupWalletService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _groupWalletsCollection = 'group_wallets';
  static const String _groupTransactionsCollection = 'group_transactions';

  /// Create a new group wallet
  static Future<String> createGroupWallet({
    required String name,
    required String description,
    required List<String> memberWalletNames,
    required String creatorWalletName,
    required String creatorSecretKey, // Add creator's secret key for initial funding
    required double targetAmount,
    DateTime? targetDate,
    int requiredSignatures = 2,
  }) async {
    try {
      // Validate member wallet names
      for (final memberName in memberWalletNames) {
        final isAvailable = await WalletRegistryService.isWalletNameAvailable(memberName);
        if (isAvailable) {
          throw Exception('Member wallet name not found: $memberName');
        }
      }

      // Validate creator
      final creatorAvailable = await WalletRegistryService.isWalletNameAvailable(creatorWalletName);
      if (creatorAvailable) {
        throw Exception('Creator wallet name not found');
      }

      // Create multi-signature wallet on Stellar network
      final groupKeyPair = await _createMultiSigWallet(
        memberWalletNames: [...memberWalletNames, creatorWalletName],
        requiredSignatures: requiredSignatures,
        creatorSecretKey: creatorSecretKey, // Pass creator's secret key for initial funding
      );

      final now = DateTime.now();

      // Create members list
      final members = <GroupWalletMember>[
        // Creator as admin
        GroupWalletMember(
          walletName: creatorWalletName,
          displayName: creatorWalletName,
          role: GroupWalletRole.admin,
          joinedAt: now,
        ),
        // Other members as contributors
        ...memberWalletNames.map((name) => GroupWalletMember(
          walletName: name,
          displayName: name,
          role: GroupWalletRole.contributor,
          joinedAt: now,
        )),
      ];

      // Create group wallet
      final groupWallet = GroupWalletModel(
        id: '', // Will be set by Firestore
        name: name,
        description: description,
        publicKey: groupKeyPair.accountId,
        members: members,
        settings: GroupWalletSettings(
          requiredSignatures: requiredSignatures,
          totalSigners: members.length,
          adminWalletNames: [creatorWalletName],
        ),
        targetAmount: targetAmount,
        currentBalance: 0.0,
        createdAt: now,
        targetDate: targetDate,
        status: GroupWalletStatus.active,
        transactions: [],
      );

      // Save to Firebase with secret key
      final groupWalletData = groupWallet.toFirestore();
      groupWalletData['secretKey'] = groupKeyPair.secretSeed; // Add secret key for transfers
      
      final docRef = await _firestore
          .collection(_groupWalletsCollection)
          .add(groupWalletData);

      // Record the initial 1 XLM as a contribution transaction
      debugPrint('GroupWalletService: About to record initial contribution for wallet ${docRef.id}');
      await _recordInitialContribution(
        groupWalletId: docRef.id,
        contributorWalletName: creatorWalletName,
        amount: 1.0,
      );
      debugPrint('GroupWalletService: Initial contribution recorded successfully');

      debugPrint('GroupWalletService: Created group wallet ${docRef.id} with initial contribution');
      return docRef.id;

    } catch (e) {
      debugPrint('Error creating group wallet: $e');
      throw Exception('Failed to create group wallet: $e');
    }
  }

  /// Get group wallets where user is a member
  static Stream<QuerySnapshot> getUserGroupWalletsStream(String walletName) {
    return _firestore
        .collection(_groupWalletsCollection)
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Get group wallets where user is a member (one-time fetch)
  static Future<List<GroupWalletModel>> getUserGroupWallets(String walletName) async {
    try {
      debugPrint('GroupWalletService: Getting group wallets for user: $walletName');
      
      // Get all active group wallets and filter on client side
      // This works around Firestore's limitation with complex arrayContains queries
      final querySnapshot = await _firestore
          .collection(_groupWalletsCollection)
          .where('status', isEqualTo: 'active')
          .orderBy('createdAt', descending: true)
          .get();

      debugPrint('GroupWalletService: Found ${querySnapshot.docs.length} total group wallets');

      // Filter for wallets where user is a member and load transactions
      final groupWallets = <GroupWalletModel>[];
      
      for (final doc in querySnapshot.docs) {
        final wallet = GroupWalletModel.fromFirestore(doc);
        
        // Check if user is a member
        if (wallet.members.any((member) => member.walletName == walletName && member.isActive)) {
          // Load transactions for this wallet
          try {
            final transactionsQuery = await _firestore
                .collection('group_transactions')
                .where('groupWalletId', isEqualTo: doc.id)
                .get();
            
            final transactions = transactionsQuery.docs.map((transDoc) {
              final data = transDoc.data();
              return GroupWalletTransaction.fromMap(data);
            }).toList();
            
            // Add wallet with transactions
            groupWallets.add(wallet.copyWith(transactions: transactions));
          } catch (e) {
            debugPrint('GroupWalletService: Failed to load transactions for ${wallet.name}: $e');
            // Add wallet without transactions
            groupWallets.add(wallet);
          }
        }
      }
      
      debugPrint('GroupWalletService: Filtered to ${groupWallets.length} wallets for user $walletName');
      
      for (final wallet in groupWallets) {
        debugPrint('GroupWalletService: Wallet ${wallet.name} (${wallet.id})');
      }

      return groupWallets;
    } catch (e) {
      debugPrint('Error getting user group wallets: $e');
      return [];
    }
  }

  /// Get group wallet by ID
  static Future<GroupWalletModel?> getGroupWallet(String groupWalletId) async {
    try {
      final doc = await _firestore
          .collection(_groupWalletsCollection)
          .doc(groupWalletId)
          .get();

      if (!doc.exists) return null;
      
      // Load group wallet data
      final groupWallet = GroupWalletModel.fromFirestore(doc);
      
      // Load transactions for this group wallet
      final transactionsQuery = await _firestore
          .collection('group_transactions')
          .where('groupWalletId', isEqualTo: groupWalletId)
          .get();
      
      final transactions = transactionsQuery.docs.map((doc) {
        final data = doc.data();
        return GroupWalletTransaction.fromMap(data);
      }).toList();
      
      debugPrint('GroupWalletService: Loaded ${transactions.length} transactions for wallet $groupWalletId');
      
      // Return group wallet with loaded transactions
      return groupWallet.copyWith(transactions: transactions);
    } catch (e) {
      debugPrint('Error getting group wallet: $e');
      return null;
    }
  }

  /// Contribute to group wallet
  static Future<void> contributeToGroupWallet({
    required String groupWalletId,
    required String contributorWalletName,
    required String contributorSecretKey,
    required double amount,
    String memo = '',
  }) async {
    try {
      // Get group wallet
      final groupWallet = await getGroupWallet(groupWalletId);
      if (groupWallet == null) {
        throw Exception('Group wallet not found');
      }

      // Check if user is a member
      final member = groupWallet.getMember(contributorWalletName);
      if (member == null) {
        throw Exception('You are not a member of this group wallet');
      }

      // Check if group wallet account exists on Stellar network
      bool accountExists = false;
      try {
        await StellarService.getAccountInfo(groupWallet.publicKey);
        accountExists = true;
        debugPrint('GroupWalletService: Group wallet account exists on Stellar network');
      } catch (e) {
        debugPrint('GroupWalletService: Group wallet account does not exist: $e');
      }

      // If account doesn't exist and we're on testnet, try to fund it first
      if (!accountExists && StellarService.currentNetwork.isTestnet) {
        try {
          debugPrint('GroupWalletService: Attempting to fund group wallet account');
          await FriendBot.fundTestAccount(groupWallet.publicKey);
          debugPrint('GroupWalletService: Successfully funded group wallet account');
          accountExists = true;
        } catch (e) {
          debugPrint('GroupWalletService: Failed to fund account, will try create account operation: $e');
        }
      }

      TransactionModel transaction;
      
      if (!accountExists) {
        // Use create account operation for the first contribution
        debugPrint('GroupWalletService: Using create account operation');
        transaction = await StellarService.createAccount(
          sourceSecretKey: contributorSecretKey,
          destinationAddress: groupWallet.publicKey,
          startingBalance: amount,
          memo: memo.isEmpty ? 'Group wallet creation: ${groupWallet.name}' : memo,
        );
      } else {
        // Send regular payment to existing account
        debugPrint('GroupWalletService: Using regular payment operation');
        transaction = await StellarService.sendPayment(
          secretKey: contributorSecretKey,
          destinationAddress: groupWallet.publicKey,
          amount: amount,
          memo: memo.isEmpty ? 'Group contribution: ${groupWallet.name}' : memo,
        );
      }

      // Record transaction
      final groupTransaction = GroupWalletTransaction(
        id: transaction.hash,
        type: GroupTransactionType.contribution,
        fromWalletName: contributorWalletName,
        amount: amount,
        description: memo.isEmpty ? 'Contribution to ${groupWallet.name}' : memo,
        createdAt: DateTime.now(),
        transactionHash: transaction.hash,
        status: GroupTransactionStatus.completed,
      );

      // Update group wallet
      await _firestore.collection(_groupWalletsCollection).doc(groupWalletId).update({
        'currentBalance': FieldValue.increment(amount),
        'currentAmount': FieldValue.increment(amount),
        'transactions': FieldValue.arrayUnion([groupTransaction.toMap()]),
        'members': groupWallet.members.map((m) {
          if (m.walletName == contributorWalletName) {
            return m.copyWith(
              totalContributions: m.totalContributions + amount,
            ).toMap();
          }
          return m.toMap();
        }).toList(),
      });

      // Also add to group_transactions collection for consistency
      await _firestore.collection('group_transactions').add({
        'id': transaction.hash,
        'groupWalletId': groupWalletId,
        'type': 'contribution',
        'fromWalletName': contributorWalletName,
        'toWalletName': '',
        'amount': amount,
        'status': 'completed',
        'description': memo.isEmpty ? 'Contribution to ${groupWallet.name}' : memo,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'completedAt': FieldValue.serverTimestamp(),
        'transactionHash': transaction.hash,
        'metadata': {
          'isManualContribution': true,
        },
      });

      debugPrint('GroupWalletService: Contribution processed for $contributorWalletName');
    } catch (e) {
      debugPrint('Error contributing to group wallet: $e');
      throw Exception('Failed to contribute: $e');
    }
  }

  /// Request spending from group wallet
  static Future<void> requestSpending({
    required String groupWalletId,
    required String requesterWalletName,
    required String recipientAddress,
    required double amount,
    required String description,
  }) async {
    try {
      // Get group wallet
      final groupWallet = await getGroupWallet(groupWalletId);
      if (groupWallet == null) {
        throw Exception('Group wallet not found');
      }

      // Check if user can spend
      if (!groupWallet.canSpend(requesterWalletName)) {
        throw Exception('You do not have spending permissions');
      }

      // Check balance
      if (groupWallet.currentBalance < amount) {
        throw Exception('Insufficient group wallet balance');
      }

      // Create spending request
      final spendingRequest = GroupWalletTransaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: GroupTransactionType.spending,
        fromWalletName: requesterWalletName,
        toWalletName: recipientAddress,
        amount: amount,
        description: description,
        createdAt: DateTime.now(),
        transactionHash: '', // Will be filled when executed
        status: GroupTransactionStatus.pending,
      );

      // Save spending request with required signatures
      await _firestore
          .collection(_groupTransactionsCollection)
          .doc(spendingRequest.id)
          .set({
        ...spendingRequest.toMap(),
        'groupWalletId': groupWalletId,
        'requiredSignatures': groupWallet.settings.requiredSignatures,
        'approvedBy': [],
        'rejectedBy': [],
      });

      debugPrint('GroupWalletService: Spending request created');
    } catch (e) {
      debugPrint('Error requesting spending: $e');
      throw Exception('Failed to request spending: $e');
    }
  }

  /// Approve/reject spending request
  static Future<void> approveSpendingRequest({
    required String requestId,
    required String approverWalletName,
    required bool approve,
  }) async {
    try {
      final docRef = _firestore.collection(_groupTransactionsCollection).doc(requestId);
      final doc = await docRef.get();
      
      if (!doc.exists) {
        throw Exception('Spending request not found');
      }

      final data = doc.data()!;
      final groupWalletId = data['groupWalletId'];
      final groupWallet = await getGroupWallet(groupWalletId);
      
      if (groupWallet == null) {
        throw Exception('Group wallet not found');
      }

      // Check if user can approve
      if (!groupWallet.canSpend(approverWalletName)) {
        throw Exception('You do not have approval permissions');
      }

      List<String> approvedBy = List<String>.from(data['approvedBy'] ?? []);
      List<String> rejectedBy = List<String>.from(data['rejectedBy'] ?? []);

      if (approve) {
        if (!approvedBy.contains(approverWalletName)) {
          approvedBy.add(approverWalletName);
        }
        rejectedBy.remove(approverWalletName);
      } else {
        if (!rejectedBy.contains(approverWalletName)) {
          rejectedBy.add(approverWalletName);
        }
        approvedBy.remove(approverWalletName);
      }

      // Update request
      await docRef.update({
        'approvedBy': approvedBy,
        'rejectedBy': rejectedBy,
        'status': _calculateRequestStatus(approvedBy, rejectedBy, groupWallet.settings).name,
      });

      debugPrint('GroupWalletService: Spending request ${approve ? 'approved' : 'rejected'}');
    } catch (e) {
      debugPrint('Error approving spending request: $e');
      throw Exception('Failed to process approval: $e');
    }
  }

  /// Get group wallet statistics
  static Future<GroupWalletStats> getGroupWalletStats(String groupWalletId) async {
    try {
      final groupWallet = await getGroupWallet(groupWalletId);
      if (groupWallet == null) {
        throw Exception('Group wallet not found');
      }

      // Calculate member contributions
      final memberStats = <String, double>{};
      for (final member in groupWallet.members) {
        memberStats[member.walletName] = groupWallet.getTotalContributions(member.walletName);
      }

      return GroupWalletStats(
        totalContributions: groupWallet.currentBalance + groupWallet.totalSpent,
        totalSpent: groupWallet.totalSpent,
        currentBalance: groupWallet.currentBalance,
        targetAmount: groupWallet.targetAmount,
        progress: groupWallet.progress,
        memberContributions: memberStats,
        transactionCount: groupWallet.transactions.length,
      );
    } catch (e) {
      debugPrint('Error getting group wallet stats: $e');
      throw Exception('Failed to get stats: $e');
    }
  }

  /// Helper: Create multi-signature wallet
  static Future<KeyPair> _createMultiSigWallet({
    required List<String> memberWalletNames,
    required int requiredSignatures,
    required String creatorSecretKey,
  }) async {
    // For now, create a regular wallet
    // TODO: Implement actual multi-signature wallet creation with Stellar SDK
    final keyPair = KeyPair.random();
    
    // Create and fund the account with 1 XLM from creator
    try {
      debugPrint('GroupWalletService: Creating account for group wallet ${keyPair.accountId}');
      
      await StellarService.createAccount(
        sourceSecretKey: creatorSecretKey,
        destinationAddress: keyPair.accountId,
        startingBalance: 1.0, // 1 XLM minimum to activate account
        memo: 'Group Wallet Creation',
      );
      
      debugPrint('GroupWalletService: Successfully created and funded group wallet account');
    } catch (e) {
      debugPrint('GroupWalletService: Failed to create account: $e');
      
      // If on testnet, try FriendBot as fallback
      if (StellarService.currentNetwork.isTestnet) {
        try {
          await FriendBot.fundTestAccount(keyPair.accountId);
          debugPrint('GroupWalletService: Funded testnet group wallet account via FriendBot');
        } catch (friendBotError) {
          debugPrint('GroupWalletService: FriendBot also failed: $friendBotError');
          throw Exception('Failed to create and fund group wallet account: $e');
        }
      } else {
        throw Exception('Failed to create group wallet account: $e');
      }
    }

    return keyPair;
  }

  /// Record initial contribution transaction for group wallet activation
  static Future<void> _recordInitialContribution({
    required String groupWalletId,
    required String contributorWalletName,
    required double amount,
  }) async {
    try {
      debugPrint('GroupWalletService: _recordInitialContribution called with groupWalletId: $groupWalletId, contributor: $contributorWalletName, amount: $amount');
      final now = DateTime.now();
      
      // Create contribution transaction record
      final contributionTransaction = {
        'id': '${now.millisecondsSinceEpoch}',
        'groupWalletId': groupWalletId,
        'type': 'contribution',
        'fromWalletName': contributorWalletName,
        'toWalletName': '', // Group wallet itself
        'amount': amount,
        'status': 'completed',
        'description': 'Initial Group Wallet activation',
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'completedAt': FieldValue.serverTimestamp(),
        'transactionHash': '', // This is account creation, not a regular payment
        'metadata': {
          'isInitialContribution': true,
          'purpose': 'account_activation',
        },
      };

      debugPrint('GroupWalletService: About to save contribution transaction to Firestore: $contributionTransaction');
      
      final docRef = await FirebaseFirestore.instance
          .collection('group_transactions')
          .add(contributionTransaction);
      
      debugPrint('GroupWalletService: Successfully saved contribution with ID: ${docRef.id}');
      
      // Update the group wallet's currentAmount field
      await FirebaseFirestore.instance
          .collection(_groupWalletsCollection)
          .doc(groupWalletId)
          .update({'currentAmount': FieldValue.increment(amount)});
      
      debugPrint('GroupWalletService: Updated currentAmount by $amount XLM');
      debugPrint('GroupWalletService: Recorded initial contribution of $amount XLM');
    } catch (e) {
      debugPrint('GroupWalletService: Failed to record initial contribution: $e');
      // Don't throw error - group wallet creation should still succeed
    }
  }

  /// Helper: Calculate request status based on approvals
  static GroupTransactionStatus _calculateRequestStatus(
    List<String> approvedBy,
    List<String> rejectedBy,
    GroupWalletSettings settings,
  ) {
    if (rejectedBy.isNotEmpty) {
      return GroupTransactionStatus.rejected;
    }
    
    if (approvedBy.length >= settings.requiredSignatures) {
      return GroupTransactionStatus.approved;
    }
    
    return GroupTransactionStatus.pending;
  }

  /// Get pending spending requests for a group wallet
  Future<List<SpendingRequest>> getPendingSpendingRequests(String groupWalletId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('group_transactions')
          .where('groupWalletId', isEqualTo: groupWalletId)
          .where('type', isEqualTo: 'spending_request')
          .where('status', isEqualTo: 'pending')
          .orderBy('timestamp', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return SpendingRequest.fromMap({
          'id': doc.id,
          ...data,
        });
      }).toList();
    } catch (e) {
      print('Error getting pending spending requests: $e');
      return [];
    }
  }

  /// Approve or reject a spending request (instance method)
  Future<bool> approveSpendingRequestNew(
    String requestId, 
    String userWalletName, 
    bool approve
  ) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('group_transactions')
          .doc(requestId)
          .get();
      
      if (!doc.exists) return false;

      final data = doc.data()!;
      List<String> approvedBy = List<String>.from(data['approvedBy'] ?? []);
      List<String> rejectedBy = List<String>.from(data['rejectedBy'] ?? []);
      
      if (approve) {
        if (!approvedBy.contains(userWalletName)) {
          approvedBy.add(userWalletName);
        }
        rejectedBy.remove(userWalletName);
      } else {
        if (!rejectedBy.contains(userWalletName)) {
          rejectedBy.add(userWalletName);
        }
        approvedBy.remove(userWalletName);
      }

      await FirebaseFirestore.instance
          .collection('group_transactions')
          .doc(requestId)
          .update({
        'approvedBy': approvedBy,
        'rejectedBy': rejectedBy,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Check if we have enough approvals to change status
      final groupWalletId = data['groupWalletId'];
      final groupWalletDoc = await FirebaseFirestore.instance
          .collection('group_wallets')
          .doc(groupWalletId)
          .get();
      
      if (groupWalletDoc.exists) {
        final groupWalletData = groupWalletDoc.data()!;
        final settings = GroupWalletSettings.fromMap(groupWalletData['settings']);
        
        String newStatus = 'pending';
        if (rejectedBy.isNotEmpty) {
          newStatus = 'rejected';
        } else if (approvedBy.length >= settings.requiredSignatures) {
          newStatus = 'approved';
        }

        if (newStatus != 'pending') {
          await FirebaseFirestore.instance
              .collection('group_transactions')
              .doc(requestId)
              .update({
            'status': newStatus,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      return true;
    } catch (e) {
      print('Error approving spending request: $e');
      return false;
    }
  }
}

/// Group Wallet Statistics
class GroupWalletStats {
  final double totalContributions;
  final double totalSpent;
  final double currentBalance;
  final double targetAmount;
  final double progress;
  final Map<String, double> memberContributions;
  final int transactionCount;

  GroupWalletStats({
    required this.totalContributions,
    required this.totalSpent,
    required this.currentBalance,
    required this.targetAmount,
    required this.progress,
    required this.memberContributions,
    required this.transactionCount,
  });
}

/// Spending Request Model for UI
class SpendingRequest {
  final String id;
  final String groupWalletId;
  final String requesterWalletName;
  final String recipientAddress;
  final double amount;
  final String description;
  final DateTime createdAt;
  final List<String> approvedBy;
  final List<String> rejectedBy;
  final GroupTransactionStatus status;
  final int requiredSignatures;

  SpendingRequest({
    required this.id,
    required this.groupWalletId,
    required this.requesterWalletName,
    required this.recipientAddress,
    required this.amount,
    required this.description,
    required this.createdAt,
    required this.approvedBy,
    required this.rejectedBy,
    required this.status,
    required this.requiredSignatures,
  });

  factory SpendingRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SpendingRequest(
      id: doc.id,
      groupWalletId: data['groupWalletId'] ?? '',
      requesterWalletName: data['fromWalletName'] ?? '',
      recipientAddress: data['toWalletName'] ?? '',
      amount: (data['amount'] ?? 0.0).toDouble(),
      description: data['description'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      approvedBy: List<String>.from(data['approvedBy'] ?? []),
      rejectedBy: List<String>.from(data['rejectedBy'] ?? []),
      status: GroupTransactionStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => GroupTransactionStatus.pending,
      ),
      requiredSignatures: data['requiredSignatures'] ?? 1,
    );
  }

  bool get isPending => status == GroupTransactionStatus.pending;
  bool get needsMoreApprovals => approvedBy.length < requiredSignatures;
  
  bool hasUserApproved(String walletName) => approvedBy.contains(walletName);
  bool hasUserRejected(String walletName) => rejectedBy.contains(walletName);
  bool canUserVote(String walletName) => !hasUserApproved(walletName) && !hasUserRejected(walletName);

  static SpendingRequest fromMap(Map<String, dynamic> map) {
    return SpendingRequest(
      id: map['id'] ?? '',
      groupWalletId: map['groupWalletId'] ?? '',
      requesterWalletName: map['fromWalletName'] ?? '',
      recipientAddress: map['toWalletName'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      description: map['description'] ?? '',
      createdAt: map['createdAt'] is Timestamp 
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      approvedBy: List<String>.from(map['approvedBy'] ?? []),
      rejectedBy: List<String>.from(map['rejectedBy'] ?? []),
      status: GroupTransactionStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => GroupTransactionStatus.pending,
      ),
      requiredSignatures: map['requiredSignatures'] ?? 1,
    );
  }
}