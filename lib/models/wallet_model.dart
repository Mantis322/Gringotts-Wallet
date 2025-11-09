/// Wallet Model
/// Represents a Stellar wallet with all necessary information
class WalletModel {
  final String id; // Unique identifier for multi-wallet support
  final String name; // User-friendly name for the wallet
  final String publicKey;
  final String? secretKey;
  final String? mnemonic;
  final double balance;
  final bool isTestnet;
  final DateTime createdAt;
  final DateTime lastUpdated;
  final bool isActive; // Whether this wallet is currently selected
  
  const WalletModel({
    required this.id,
    required this.name,
    required this.publicKey,
    this.secretKey,
    this.mnemonic,
    required this.balance,
    required this.isTestnet,
    required this.createdAt,
    required this.lastUpdated,
    this.isActive = false,
  });
  
  // Factory constructor for creating empty wallet
  factory WalletModel.empty() {
    return WalletModel(
      id: '',
      name: '',
      publicKey: '',
      secretKey: null,
      mnemonic: null,
      balance: 0.0,
      isTestnet: true,
      createdAt: DateTime.now(),
      lastUpdated: DateTime.now(),
      isActive: false,
    );
  }
  
  // Factory constructor for creating new wallet with generated ID
  factory WalletModel.create({
    required String name,
    required String publicKey,
    String? secretKey,
    String? mnemonic,
    required bool isTestnet,
    bool isActive = false,
  }) {
    final now = DateTime.now();
    return WalletModel(
      id: _generateWalletId(),
      name: name,
      publicKey: publicKey,
      secretKey: secretKey,
      mnemonic: mnemonic,
      balance: 0.0,
      isTestnet: isTestnet,
      createdAt: now,
      lastUpdated: now,
      isActive: isActive,
    );
  }
  
  // Generate unique wallet ID
  static String _generateWalletId() {
    return 'wallet_${DateTime.now().millisecondsSinceEpoch}_${(1000 + (9999 - 1000) * (DateTime.now().microsecond / 1000000)).toInt()}';
  }
  
  // Factory constructor from JSON
  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      id: json['id'] as String? ?? _generateWalletId(),
      name: json['name'] as String? ?? 'Wallet',
      publicKey: json['publicKey'] as String,
      secretKey: json['secretKey'] as String?,
      mnemonic: json['mnemonic'] as String?,
      balance: (json['balance'] as num).toDouble(),
      isTestnet: json['isTestnet'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
      isActive: json['isActive'] as bool? ?? false,
    );
  }
  
  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'publicKey': publicKey,
      'secretKey': secretKey,
      'mnemonic': mnemonic,
      'balance': balance,
      'isTestnet': isTestnet,
      'createdAt': createdAt.toIso8601String(),
      'lastUpdated': lastUpdated.toIso8601String(),
      'isActive': isActive,
    };
  }
  
  // CopyWith method for immutable updates
  WalletModel copyWith({
    String? id,
    String? name,
    String? publicKey,
    String? secretKey,
    String? mnemonic,
    double? balance,
    bool? isTestnet,
    DateTime? createdAt,
    DateTime? lastUpdated,
    bool? isActive,
  }) {
    return WalletModel(
      id: id ?? this.id,
      name: name ?? this.name,
      publicKey: publicKey ?? this.publicKey,
      secretKey: secretKey ?? this.secretKey,
      mnemonic: mnemonic ?? this.mnemonic,
      balance: balance ?? this.balance,
      isTestnet: isTestnet ?? this.isTestnet,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isActive: isActive ?? this.isActive,
    );
  }
  
  // Getters
  bool get hasWallet => publicKey.isNotEmpty;
  bool get hasSecretKey => secretKey != null && secretKey!.isNotEmpty;
  String get displayBalance => balance.toStringAsFixed(7);
  String get shortPublicKey => hasWallet ? '${publicKey.substring(0, 6)}...${publicKey.substring(publicKey.length - 6)}' : '';
  String get displayName => name.isNotEmpty ? name : 'Wallet $shortPublicKey';
  String get networkType => isTestnet ? 'Testnet' : 'Mainnet';
  
  @override
  String toString() {
    return 'WalletModel(id: $id, name: $name, publicKey: $shortPublicKey, balance: $displayBalance, isTestnet: $isTestnet, isActive: $isActive)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WalletModel && other.id == id;
  }
  
  @override
  int get hashCode => id.hashCode;
}

/// Multi-Wallet Manager Model
/// Manages multiple wallets and their states
class MultiWalletModel {
  final List<WalletModel> wallets;
  final String? activeWalletId;
  
  const MultiWalletModel({
    required this.wallets,
    this.activeWalletId,
  });
  
  // Factory constructor for empty wallet list
  factory MultiWalletModel.empty() {
    return const MultiWalletModel(
      wallets: [],
      activeWalletId: null,
    );
  }
  
  // Factory constructor from JSON
  factory MultiWalletModel.fromJson(Map<String, dynamic> json) {
    final walletList = (json['wallets'] as List<dynamic>?)
        ?.map((w) => WalletModel.fromJson(w as Map<String, dynamic>))
        .toList() ?? [];
    
    return MultiWalletModel(
      wallets: walletList,
      activeWalletId: json['activeWalletId'] as String?,
    );
  }
  
  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'wallets': wallets.map((w) => w.toJson()).toList(),
      'activeWalletId': activeWalletId,
    };
  }
  
  // Getters
  bool get hasWallets => wallets.isNotEmpty;
  bool get hasActiveWallet => activeWalletId != null && activeWallet != null;
  int get walletCount => wallets.length;
  
  WalletModel? get activeWallet {
    if (activeWalletId == null) return null;
    try {
      return wallets.firstWhere((w) => w.id == activeWalletId);
    } catch (e) {
      return null;
    }
  }
  
  List<WalletModel> get testnetWallets => wallets.where((w) => w.isTestnet).toList();
  List<WalletModel> get mainnetWallets => wallets.where((w) => !w.isTestnet).toList();
  
  // Helper methods
  bool containsWallet(String walletId) {
    return wallets.any((w) => w.id == walletId);
  }
  
  bool containsPublicKey(String publicKey) {
    return wallets.any((w) => w.publicKey == publicKey);
  }
  
  WalletModel? getWalletById(String walletId) {
    try {
      return wallets.firstWhere((w) => w.id == walletId);
    } catch (e) {
      return null;
    }
  }
  
  WalletModel? getWalletByPublicKey(String publicKey) {
    try {
      return wallets.firstWhere((w) => w.publicKey == publicKey);
    } catch (e) {
      return null;
    }
  }
  
  // Operations
  MultiWalletModel addWallet(WalletModel wallet) {
    final updatedWallets = List<WalletModel>.from(wallets);
    updatedWallets.add(wallet);
    
    return MultiWalletModel(
      wallets: updatedWallets,
      activeWalletId: activeWalletId ?? wallet.id, // Set as active if first wallet
    );
  }
  
  MultiWalletModel removeWallet(String walletId) {
    final updatedWallets = wallets.where((w) => w.id != walletId).toList();
    String? newActiveWalletId = activeWalletId;
    
    // If removing active wallet, switch to first available wallet
    if (activeWalletId == walletId) {
      newActiveWalletId = updatedWallets.isNotEmpty ? updatedWallets.first.id : null;
    }
    
    return MultiWalletModel(
      wallets: updatedWallets,
      activeWalletId: newActiveWalletId,
    );
  }
  
  MultiWalletModel updateWallet(WalletModel updatedWallet) {
    final updatedWallets = wallets.map((w) {
      return w.id == updatedWallet.id ? updatedWallet : w;
    }).toList();
    
    return MultiWalletModel(
      wallets: updatedWallets,
      activeWalletId: activeWalletId,
    );
  }
  
  MultiWalletModel setActiveWallet(String walletId) {
    return MultiWalletModel(
      wallets: wallets,
      activeWalletId: walletId,
    );
  }
  
  MultiWalletModel updateWalletBalance(String walletId, double newBalance) {
    final updatedWallets = wallets.map((w) {
      if (w.id == walletId) {
        return w.copyWith(
          balance: newBalance,
          lastUpdated: DateTime.now(),
        );
      }
      return w;
    }).toList();
    
    return MultiWalletModel(
      wallets: updatedWallets,
      activeWalletId: activeWalletId,
    );
  }
  
  @override
  String toString() {
    return 'MultiWalletModel(walletCount: $walletCount, activeWalletId: $activeWalletId)';
  }
}

/// Transaction Model
/// Represents a Stellar transaction
class TransactionModel {
  final String id;
  final String hash;
  final String sourceAccount;
  final String destinationAccount;
  final double amount;
  final String assetCode;
  final String memo;
  final DateTime createdAt;
  final TransactionStatus status;
  final TransactionType type;
  final double fee;
  
  const TransactionModel({
    required this.id,
    required this.hash,
    required this.sourceAccount,
    required this.destinationAccount,
    required this.amount,
    required this.assetCode,
    required this.memo,
    required this.createdAt,
    required this.status,
    required this.type,
    required this.fee,
  });
  
  // Factory constructor from JSON
  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as String,
      hash: json['hash'] as String,
      sourceAccount: json['sourceAccount'] as String,
      destinationAccount: json['destinationAccount'] as String,
      amount: (json['amount'] as num).toDouble(),
      assetCode: json['assetCode'] as String,
      memo: json['memo'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      status: TransactionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TransactionStatus.pending,
      ),
      type: TransactionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => TransactionType.payment,
      ),
      fee: (json['fee'] as num).toDouble(),
    );
  }
  
  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hash': hash,
      'sourceAccount': sourceAccount,
      'destinationAccount': destinationAccount,
      'amount': amount,
      'assetCode': assetCode,
      'memo': memo,
      'createdAt': createdAt.toIso8601String(),
      'status': status.name,
      'type': type.name,
      'fee': fee,
    };
  }
  
  // Getters
  String get displayAmount => amount.toStringAsFixed(7);
  String get shortSourceAccount => '${sourceAccount.substring(0, 6)}...${sourceAccount.substring(sourceAccount.length - 6)}';
  String get shortDestinationAccount => '${destinationAccount.substring(0, 6)}...${destinationAccount.substring(destinationAccount.length - 6)}';
  String get shortHash => '${hash.substring(0, 8)}...${hash.substring(hash.length - 8)}';
  
  bool get isIncoming => type == TransactionType.received;
  bool get isOutgoing => type == TransactionType.sent;
  bool get isSuccessful => status == TransactionStatus.success;
  bool get isFailed => status == TransactionStatus.failed;
  bool get isPending => status == TransactionStatus.pending;
}

/// Transaction Status Enum
enum TransactionStatus {
  pending,
  success,
  failed,
}

/// Transaction Type Enum
enum TransactionType {
  payment,
  sent,
  received,
  createAccount,
  manageData,
}

/// Network Model
/// Represents Stellar network configuration
class NetworkModel {
  final String name;
  final String url;
  final String passphrase;
  final bool isTestnet;
  
  const NetworkModel({
    required this.name,
    required this.url,
    required this.passphrase,
    required this.isTestnet,
  });
  
  // Factory constructors for predefined networks
  factory NetworkModel.testnet() {
    return const NetworkModel(
      name: 'Testnet',
      url: 'https://horizon-testnet.stellar.org',
      passphrase: 'Test SDF Network ; September 2015',
      isTestnet: true,
    );
  }
  
  factory NetworkModel.mainnet() {
    return const NetworkModel(
      name: 'Mainnet',
      url: 'https://horizon.stellar.org',
      passphrase: 'Public Global Stellar Network ; September 2015',
      isTestnet: false,
    );
  }
}

/// Balance Model
/// Represents account balance information
class BalanceModel {
  final String assetCode;
  final String assetIssuer;
  final double balance;
  final double? limit;
  final bool isNative;
  
  const BalanceModel({
    required this.assetCode,
    required this.assetIssuer,
    required this.balance,
    this.limit,
    required this.isNative,
  });
  
  // Factory constructor for native XLM
  factory BalanceModel.xlm(double balance) {
    return BalanceModel(
      assetCode: 'XLM',
      assetIssuer: '',
      balance: balance,
      isNative: true,
    );
  }
  
  // Factory constructor from JSON
  factory BalanceModel.fromJson(Map<String, dynamic> json) {
    return BalanceModel(
      assetCode: json['asset_code'] as String? ?? 'XLM',
      assetIssuer: json['asset_issuer'] as String? ?? '',
      balance: double.parse(json['balance'] as String),
      limit: json['limit'] != null ? double.parse(json['limit'] as String) : null,
      isNative: json['asset_type'] == 'native',
    );
  }
  
  // Getters
  String get displayBalance => balance.toStringAsFixed(7);
  String get displayAsset => isNative ? 'XLM' : assetCode;
}