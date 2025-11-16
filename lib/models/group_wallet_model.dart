import 'package:cloud_firestore/cloud_firestore.dart';

/// Group Wallet Model
/// Represents a multi-signature wallet shared among multiple users
class GroupWalletModel {
  final String id;
  final String name;
  final String description;
  final String publicKey;
  final List<GroupWalletMember> members;
  final GroupWalletSettings settings;
  final double targetAmount;
  final double currentBalance;

  // Calculated properties
  double get currentAmount {
    return transactions
        .where((t) => t.type == GroupTransactionType.contribution && 
                      t.status == GroupTransactionStatus.completed)
        .fold(0.0, (sum, t) => sum + t.amount);
  }
  
  // Aliases for compatibility
  int get requiredSignatures => settings.requiredSignatures;
  String get stellarAccountId => publicKey;
  final DateTime createdAt;
  final DateTime? targetDate;
  final GroupWalletStatus status;
  final List<GroupWalletTransaction> transactions;
  final Map<String, dynamic> metadata;

  GroupWalletModel({
    required this.id,
    required this.name,
    required this.description,
    required this.publicKey,
    required this.members,
    required this.settings,
    required this.targetAmount,
    required this.currentBalance,
    required this.createdAt,
    this.targetDate,
    required this.status,
    required this.transactions,
    this.metadata = const {},
  });

  /// Progress towards target amount (0.0 to 1.0)
  double get progress => targetAmount > 0 ? (currentBalance / targetAmount).clamp(0.0, 1.0) : 0.0;

  /// Amount remaining to reach target
  double get remainingAmount => (targetAmount - currentBalance).clamp(0.0, double.infinity);

  /// Check if target is reached
  bool get isTargetReached => currentBalance >= targetAmount;

  /// Get member by wallet name
  GroupWalletMember? getMember(String walletName) {
    return members.where((m) => m.walletName == walletName).firstOrNull;
  }

  /// Check if user is admin
  bool isAdmin(String walletName) {
    final member = getMember(walletName);
    return member?.role == GroupWalletRole.admin;
  }

  /// Check if user can spend
  bool canSpend(String walletName) {
    final member = getMember(walletName);
    return member?.role == GroupWalletRole.admin || member?.role == GroupWalletRole.spender;
  }

  /// Get total contributions by member
  double getTotalContributions(String walletName) {
    return transactions
        .where((t) => t.type == GroupTransactionType.contribution && t.fromWalletName == walletName)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  /// Get total spending
  double get totalSpent {
    return transactions
        .where((t) => t.type == GroupTransactionType.spending)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  /// Create from Firestore document
  factory GroupWalletModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return GroupWalletModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      publicKey: data['publicKey'] ?? '',
      members: (data['members'] as List<dynamic>? ?? [])
          .map((m) => GroupWalletMember.fromMap(m as Map<String, dynamic>))
          .toList(),
      settings: GroupWalletSettings.fromMap(data['settings'] ?? {}),
      targetAmount: (data['targetAmount'] ?? 0.0).toDouble(),
      currentBalance: (data['currentBalance'] ?? 0.0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      targetDate: data['targetDate'] != null ? (data['targetDate'] as Timestamp).toDate() : null,
      status: GroupWalletStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => GroupWalletStatus.active,
      ),
      transactions: (data['transactions'] as List<dynamic>? ?? [])
          .map((t) => GroupWalletTransaction.fromMap(t as Map<String, dynamic>))
          .toList(),
      metadata: data['metadata'] ?? {},
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'publicKey': publicKey,
      'members': members.map((m) => m.toMap()).toList(),
      'settings': settings.toMap(),
      'targetAmount': targetAmount,
      'currentBalance': currentBalance,
      'createdAt': Timestamp.fromDate(createdAt),
      'targetDate': targetDate != null ? Timestamp.fromDate(targetDate!) : null,
      'status': status.name,
      'transactions': transactions.map((t) => t.toMap()).toList(),
      'metadata': metadata,
    };
  }

  GroupWalletModel copyWith({
    String? id,
    String? name,
    String? description,
    String? publicKey,
    List<GroupWalletMember>? members,
    GroupWalletSettings? settings,
    double? targetAmount,
    double? currentBalance,
    DateTime? createdAt,
    DateTime? targetDate,
    GroupWalletStatus? status,
    List<GroupWalletTransaction>? transactions,
    Map<String, dynamic>? metadata,
  }) {
    return GroupWalletModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      publicKey: publicKey ?? this.publicKey,
      members: members ?? this.members,
      settings: settings ?? this.settings,
      targetAmount: targetAmount ?? this.targetAmount,
      currentBalance: currentBalance ?? this.currentBalance,
      createdAt: createdAt ?? this.createdAt,
      targetDate: targetDate ?? this.targetDate,
      status: status ?? this.status,
      transactions: transactions ?? this.transactions,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Group Wallet Member
class GroupWalletMember {
  final String walletName;
  final String displayName;
  final GroupWalletRole role;
  final DateTime joinedAt;
  final bool isActive;
  final double totalContributions;
  final Map<String, dynamic> metadata;

  GroupWalletMember({
    required this.walletName,
    required this.displayName,
    required this.role,
    required this.joinedAt,
    this.isActive = true,
    this.totalContributions = 0.0,
    this.metadata = const {},
  });

  factory GroupWalletMember.fromMap(Map<String, dynamic> map) {
    return GroupWalletMember(
      walletName: map['walletName'] ?? '',
      displayName: map['displayName'] ?? '',
      role: GroupWalletRole.values.firstWhere(
        (r) => r.name == map['role'],
        orElse: () => GroupWalletRole.contributor,
      ),
      joinedAt: (map['joinedAt'] as Timestamp).toDate(),
      isActive: map['isActive'] ?? true,
      totalContributions: (map['totalContributions'] ?? 0.0).toDouble(),
      metadata: map['metadata'] ?? {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'walletName': walletName,
      'displayName': displayName,
      'role': role.name,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'isActive': isActive,
      'totalContributions': totalContributions,
      'metadata': metadata,
    };
  }

  GroupWalletMember copyWith({
    String? walletName,
    String? displayName,
    GroupWalletRole? role,
    DateTime? joinedAt,
    bool? isActive,
    double? totalContributions,
    Map<String, dynamic>? metadata,
  }) {
    return GroupWalletMember(
      walletName: walletName ?? this.walletName,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      isActive: isActive ?? this.isActive,
      totalContributions: totalContributions ?? this.totalContributions,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Group Wallet Settings
class GroupWalletSettings {
  final int requiredSignatures;
  final int totalSigners;
  final bool allowContributions;
  final bool allowSpending;
  final double maxSpendingAmount;
  final bool requireApprovalForSpending;
  final List<String> adminWalletNames;

  GroupWalletSettings({
    required this.requiredSignatures,
    required this.totalSigners,
    this.allowContributions = true,
    this.allowSpending = true,
    this.maxSpendingAmount = double.infinity,
    this.requireApprovalForSpending = true,
    this.adminWalletNames = const [],
  });

  factory GroupWalletSettings.fromMap(Map<String, dynamic> map) {
    return GroupWalletSettings(
      requiredSignatures: map['requiredSignatures'] ?? 2,
      totalSigners: map['totalSigners'] ?? 3,
      allowContributions: map['allowContributions'] ?? true,
      allowSpending: map['allowSpending'] ?? true,
      maxSpendingAmount: (map['maxSpendingAmount'] ?? double.infinity).toDouble(),
      requireApprovalForSpending: map['requireApprovalForSpending'] ?? true,
      adminWalletNames: List<String>.from(map['adminWalletNames'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'requiredSignatures': requiredSignatures,
      'totalSigners': totalSigners,
      'allowContributions': allowContributions,
      'allowSpending': allowSpending,
      'maxSpendingAmount': maxSpendingAmount,
      'requireApprovalForSpending': requireApprovalForSpending,
      'adminWalletNames': adminWalletNames,
    };
  }
}

/// Group Wallet Transaction
class GroupWalletTransaction {
  final String id;
  final GroupTransactionType type;
  final String? fromWalletName;
  final String? toWalletName;
  final double amount;
  final String description;
  final DateTime createdAt;
  final String transactionHash;
  final GroupTransactionStatus status;
  final List<String> approvedBy;
  final List<String> rejectedBy;
  final Map<String, dynamic> metadata;

  // Aliases for compatibility
  String? get initiatorWalletName => fromWalletName;
  DateTime get timestamp => createdAt;

  GroupWalletTransaction({
    required this.id,
    required this.type,
    this.fromWalletName,
    this.toWalletName,
    required this.amount,
    required this.description,
    required this.createdAt,
    required this.transactionHash,
    required this.status,
    this.approvedBy = const [],
    this.rejectedBy = const [],
    this.metadata = const {},
  });

  factory GroupWalletTransaction.fromMap(Map<String, dynamic> map) {
    return GroupWalletTransaction(
      id: map['id'] ?? '',
      type: GroupTransactionType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => GroupTransactionType.contribution,
      ),
      fromWalletName: map['fromWalletName'],
      toWalletName: map['toWalletName'],
      amount: (map['amount'] ?? 0.0).toDouble(),
      description: map['description'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      transactionHash: map['transactionHash'] ?? '',
      status: GroupTransactionStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => GroupTransactionStatus.pending,
      ),
      approvedBy: List<String>.from(map['approvedBy'] ?? []),
      rejectedBy: List<String>.from(map['rejectedBy'] ?? []),
      metadata: map['metadata'] ?? {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'fromWalletName': fromWalletName,
      'toWalletName': toWalletName,
      'amount': amount,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'transactionHash': transactionHash,
      'status': status.name,
      'approvedBy': approvedBy,
      'rejectedBy': rejectedBy,
      'metadata': metadata,
    };
  }
}

/// Group Wallet Status
enum GroupWalletStatus {
  active,
  paused,
  completed,
  cancelled,
}

/// Group Wallet Member Role
enum GroupWalletRole {
  admin,        // Can spend, approve, manage members
  spender,      // Can spend (with approval)
  contributor,  // Can only contribute
}

/// Group Transaction Type
enum GroupTransactionType {
  contribution, // Member contributing to group wallet
  spending,     // Spending from group wallet
  withdrawal,   // Withdrawal from group wallet
}

/// Group Transaction Status
enum GroupTransactionStatus {
  pending,
  approved,
  rejected,
  completed,
  failed,
}