/// Wallet Model
/// Represents a Stellar wallet with all necessary information
class WalletModel {
  final String publicKey;
  final String? secretKey;
  final String? mnemonic;
  final double balance;
  final bool isTestnet;
  final DateTime createdAt;
  final DateTime lastUpdated;
  
  const WalletModel({
    required this.publicKey,
    this.secretKey,
    this.mnemonic,
    required this.balance,
    required this.isTestnet,
    required this.createdAt,
    required this.lastUpdated,
  });
  
  // Factory constructor for creating empty wallet
  factory WalletModel.empty() {
    return WalletModel(
      publicKey: '',
      secretKey: null,
      mnemonic: null,
      balance: 0.0,
      isTestnet: true,
      createdAt: DateTime.now(),
      lastUpdated: DateTime.now(),
    );
  }
  
  // Factory constructor from JSON
  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      publicKey: json['publicKey'] as String,
      secretKey: json['secretKey'] as String?,
      mnemonic: json['mnemonic'] as String?,
      balance: (json['balance'] as num).toDouble(),
      isTestnet: json['isTestnet'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
    );
  }
  
  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'publicKey': publicKey,
      'secretKey': secretKey,
      'mnemonic': mnemonic,
      'balance': balance,
      'isTestnet': isTestnet,
      'createdAt': createdAt.toIso8601String(),
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
  
  // CopyWith method for immutable updates
  WalletModel copyWith({
    String? publicKey,
    String? secretKey,
    String? mnemonic,
    double? balance,
    bool? isTestnet,
    DateTime? createdAt,
    DateTime? lastUpdated,
  }) {
    return WalletModel(
      publicKey: publicKey ?? this.publicKey,
      secretKey: secretKey ?? this.secretKey,
      mnemonic: mnemonic ?? this.mnemonic,
      balance: balance ?? this.balance,
      isTestnet: isTestnet ?? this.isTestnet,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
  
  // Getters
  bool get hasWallet => publicKey.isNotEmpty;
  bool get hasSecretKey => secretKey != null && secretKey!.isNotEmpty;
  String get displayBalance => balance.toStringAsFixed(7);
  String get shortPublicKey => hasWallet ? '${publicKey.substring(0, 6)}...${publicKey.substring(publicKey.length - 6)}' : '';
  
  @override
  String toString() {
    return 'WalletModel(publicKey: $shortPublicKey, balance: $displayBalance, isTestnet: $isTestnet)';
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