import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/whisper_pay_model.dart';
import '../services/pin_code_service.dart';
import '../models/pin_code_model.dart';

class WhisperPayService extends ChangeNotifier {
  static final WhisperPayService _instance = WhisperPayService._internal();
  factory WhisperPayService() => _instance;
  WhisperPayService._internal();


  final FlutterBlePeripheral _blePeripheral = FlutterBlePeripheral();
  
  // No service UUID needed - using only manufacturer data for identification

  
  WhisperPayState _state = WhisperPayState.idle;
  WhisperPaySession? _currentSession;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _sessionSubscription;
  Timer? _receiveTimer;
  Timer? _sessionCleanupTimer;
  String? _sessionId;
  
  // PIN code integration
  PinCodeModel? _currentPinCode;
  final Map<String, PinCodeModel> _pinCodeCache = {};
  

  
  // Getters
  WhisperPayState get state => _state;
  WhisperPaySession? get currentSession => _currentSession;
  bool get isReceiveModeActive => _state == WhisperPayState.receiveModeActive;
  bool get isScanningActive => _state == WhisperPayState.scanningForDevices;

  /// Initialize WhisperPay service
  Future<bool> initialize() async {
    try {
      // Check and request permissions
      final permissions = await _requestPermissions();
      if (!permissions) {
        debugPrint('WhisperPay: Required permissions not granted');
        return false;
      }

      // Initialize BLE
      final bleSupported = await FlutterBluePlus.isSupported;
      if (!bleSupported) {
        debugPrint('WhisperPay: BLE not supported on this device');
        return false;
      }

      // Start periodic cleanup of expired sessions
      _startSessionCleanup();
      
      debugPrint('WhisperPay: Service initialized successfully');
      return true;
    } catch (e) {
      debugPrint('WhisperPay: Initialization failed: $e');
      return false;
    }
  }

  /// Request necessary permissions for WhisperPay
  Future<bool> _requestPermissions() async {
    try {
      debugPrint('WhisperPay: Requesting permissions...');
      
      // Always request location permission (required for BLE scanning on Android)
      final locationPermission = await Permission.location.request();
      debugPrint('WhisperPay: Location permission: $locationPermission');
      
      if (!locationPermission.isGranted) {
        debugPrint('WhisperPay: Location permission required for BLE scanning');
        return false;
      }

      // Request Bluetooth permissions based on Android version
      // For Android 12+ (API 31+), use new granular permissions
      // For older versions, use legacy permissions
      
      bool bluetoothGranted = false;
      
      try {
        // Try new Android 12+ permissions first
        final bluetoothScanPermission = await Permission.bluetoothScan.request();
        final bluetoothConnectPermission = await Permission.bluetoothConnect.request();
        final bluetoothAdvertisePermission = await Permission.bluetoothAdvertise.request();
        
        debugPrint('WhisperPay: Bluetooth scan permission: $bluetoothScanPermission');
        debugPrint('WhisperPay: Bluetooth connect permission: $bluetoothConnectPermission');
        debugPrint('WhisperPay: Bluetooth advertise permission: $bluetoothAdvertisePermission');
        
        bluetoothGranted = bluetoothScanPermission.isGranted && 
                          bluetoothConnectPermission.isGranted &&
                          bluetoothAdvertisePermission.isGranted;
        
      } catch (e) {
        debugPrint('WhisperPay: New Bluetooth permissions not available, trying legacy: $e');
        
        // Fallback to legacy permissions for older Android versions
        final bluetoothPermission = await Permission.bluetooth.request();
        debugPrint('WhisperPay: Legacy Bluetooth permission: $bluetoothPermission');
        
        bluetoothGranted = bluetoothPermission.isGranted;
      }
      
      if (!bluetoothGranted) {
        debugPrint('WhisperPay: Bluetooth permissions not granted');
        return false;
      }

      debugPrint('WhisperPay: All permissions granted successfully');
      return true;
      
    } catch (e) {
      debugPrint('WhisperPay: Error requesting permissions: $e');
      return false;
    }
  }

  /// Start receiving mode (BLE advertising)
  Future<bool> startReceiveMode({
    required String walletAddress,
    required String walletName,
    double? amount,
    String? memo,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    try {
      if (_state != WhisperPayState.idle) {
        await stopCurrentOperation();
      }

      _setState(WhisperPayState.receiveModeActive);


      // Generate session
      debugPrint('WhisperPay: Creating session with wallet: $walletAddress, name: $walletName, amount: $amount');
      final session = await _createSession(
        walletAddress: walletAddress,
        walletName: walletName,
        amount: amount,
        memo: memo,
        timeout: timeout,
      );

      _currentSession = session;

      // Start BLE advertising
      await _startAdvertising(session);

      // Set timeout timer
      _receiveTimer = Timer(timeout, () async {
        await stopReceiveMode();
      });

      debugPrint('WhisperPay: Receive mode started for @$walletName');
      return true;
    } catch (e) {
      debugPrint('WhisperPay: Failed to start receive mode: $e');
      _setState(WhisperPayState.error);
      return false;
    }
  }

  /// Stop receiving mode
  Future<void> stopReceiveMode() async {
    try {
      _receiveTimer?.cancel();
      
      // Stop BLE advertising
      try {
        await _blePeripheral.stop();
        debugPrint('WhisperPay: Stopped BLE advertising');
      } catch (e) {
        debugPrint('WhisperPay: Error stopping BLE advertising: $e');
      }
      
      // Stop scanning if active
      await FlutterBluePlus.stopScan();
      
      if (_currentSession != null) {
        await _deactivateSession(_currentSession!.sessionId);
      }

      _setState(WhisperPayState.idle);
      _currentSession = null;


      debugPrint('WhisperPay: Receive mode stopped');
    } catch (e) {
      debugPrint('WhisperPay: Error stopping receive mode: $e');
    }
  }

  /// Start scanning for nearby WhisperPay devices
  Future<bool> startScanning({
    Duration timeout = const Duration(minutes: 1),
    Function(WhisperPayBeacon)? onDeviceDiscovered,
  }) async {
    try {
      if (_state != WhisperPayState.idle) {
        await stopCurrentOperation();
      }

      // Re-check permissions before scanning
      final hasPermissions = await _requestPermissions();
      if (!hasPermissions) {
        debugPrint('WhisperPay: Cannot start scanning - permissions denied');
        _setState(WhisperPayState.error);
        return false;
      }

      _setState(WhisperPayState.scanningForDevices);

      debugPrint('WhisperPay: [SCAN] 🔍 Starting BLE scanning for WhisperPay devices...');
      debugPrint('WhisperPay: [SCAN] Looking for service UUID: 0000180a-0000-1000-8000-00805f9b34fb');
      debugPrint('WhisperPay: [SCAN] Timeout: ${timeout.inSeconds}s');
      
      // Start BLE scanning for devices with our service UUID
      await FlutterBluePlus.startScan(
        withServices: [Guid("0000180a-0000-1000-8000-00805f9b34fb")],
        timeout: timeout,
      );

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        if (results.isNotEmpty) {
          debugPrint('WhisperPay: [SCAN] 📱 Scan results received: ${results.length} device(s)');
        }
        _processScanResults(results, onDeviceDiscovered).catchError((e) {
          debugPrint('WhisperPay: Error processing scan results: $e');
        });
      });

      debugPrint('WhisperPay: [SCAN] ✅ BLE scanning started successfully');
      return true;
    } catch (e) {
      debugPrint('WhisperPay: Failed to start scanning: $e');
      
      if (e.toString().contains('Location services')) {
        debugPrint('WhisperPay: 📍 Please enable Location Services (GPS) in device settings for BLE scanning');
      }
      
      _state = WhisperPayState.error;
      return false;
    }
  }

  /// Stop scanning for devices
  Future<void> stopScanning() async {
    try {
      await FlutterBluePlus.stopScan();
      _scanSubscription?.cancel();
      
      if (_state == WhisperPayState.scanningForDevices) {
        _setState(WhisperPayState.idle);
      }

      debugPrint('WhisperPay: Scanning stopped');
    } catch (e) {
      debugPrint('WhisperPay: Error stopping scan: $e');
    }
  }

  /// Process BLE scan results
  Future<void> _processScanResults(List<ScanResult> results, Function(WhisperPayBeacon)? onDeviceDiscovered) async {
    debugPrint('WhisperPay: [SCAN] Processing ${results.length} scan result(s)');
    
    for (final result in results) {
      try {
        debugPrint('WhisperPay: [SCAN] 📱 Found device: ${result.device.remoteId}');
        debugPrint('WhisperPay: [SCAN]   Local Name: ${result.advertisementData.advName}');
        debugPrint('WhisperPay: [SCAN]   RSSI: ${result.rssi} dBm');
        debugPrint('WhisperPay: [SCAN]   Service UUIDs: ${result.advertisementData.serviceUuids}');
        debugPrint('WhisperPay: [SCAN]   Manufacturer Data: ${result.advertisementData.manufacturerData}');
        
        // Check for our service data (our identification method)
        // Looking for service data with our UUID pattern
        final serviceData = result.advertisementData.serviceData;
        
        debugPrint('WhisperPay: [SCAN]   Service Data Keys: ${serviceData.keys.map((k) => k.toString()).join(', ')}');
        
        // Try to find our service data UUID
        Guid? foundKey;
        for (final key in serviceData.keys) {
          debugPrint('WhisperPay: [SCAN]     Checking key: $key');
          if (key.toString().toLowerCase().contains('180a')) {
            foundKey = key;
            break;
          }
        }
        
        final hasWhisperPayData = foundKey != null && serviceData[foundKey]?.length == 6;
        debugPrint('WhisperPay: [SCAN]   Found matching key: $foundKey');
        debugPrint('WhisperPay: [SCAN]   Service data length: ${serviceData[foundKey]?.length ?? 0} bytes');
        debugPrint('WhisperPay: [SCAN]   Has WhisperPay service data: $hasWhisperPayData');
        
        if (!hasWhisperPayData) {
          // Don't spam logs for non-WhisperPay devices
          continue;
        }

        // Calculate distance from RSSI
        final distance = _calculateDistance(result.rssi);
        debugPrint('WhisperPay: [SCAN]   📏 Estimated distance: ${distance.toStringAsFixed(1)}m');
        
        if (distance > 0.5) {
          debugPrint('WhisperPay: [SCAN]   ⚠️ Device too far (${distance.toStringAsFixed(1)}m), skipping');
          continue;
        }

        debugPrint('WhisperPay: [SCAN]   ✅ WhisperPay device in range! RSSI: ${result.rssi}, Distance: ~${distance.toStringAsFixed(1)}m');
        
        // Parse the WhisperPay session data using the found key
        final sessionBytes = serviceData[foundKey]!;
        debugPrint('WhisperPay: [SCAN]   🔄 Parsing ${sessionBytes.length} bytes of service data...');
        debugPrint('WhisperPay: [SCAN]   Raw bytes: ${sessionBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
                await _parseAndHandleSessionData(sessionBytes, result, onDeviceDiscovered);
        
      } catch (e) {
        debugPrint('WhisperPay: Error processing scan result: $e');
      }
    }
  }

  /// Parse session data from advertising bytes
  Future<void> _parseAndHandleSessionData(List<int> sessionBytes, ScanResult result, Function(WhisperPayBeacon)? onDeviceDiscovered) async {
    try {
      debugPrint('WhisperPay: [PARSE] Received ${sessionBytes.length} bytes: ${sessionBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
      
      if (sessionBytes.length != 6) {
        debugPrint('WhisperPay: [PARSE] ❌ Invalid data length: ${sessionBytes.length}, expected 6 bytes (PIN code)');
        return;
      }
      
      // Convert bytes back to PIN code string
      final pinCodeString = String.fromCharCodes(sessionBytes);
      
      debugPrint('WhisperPay: [PARSE] Received PIN code: $pinCodeString');
      
      // Validate and get PIN code details
      final pinCodeModel = await PinCodeService.validatePinCode(pinCodeString);
      
      if (pinCodeModel == null) {
        debugPrint('WhisperPay: [PARSE] ❌ Invalid or expired PIN code: $pinCodeString');
        return;
      }
      
      // Cache PIN code for later use
      _pinCodeCache[pinCodeString] = pinCodeModel;
      
      final sessionId = 'WP$pinCodeString';
      final amount = pinCodeModel.amount;
      final walletAddress = pinCodeModel.walletPublicKey;
      
      debugPrint('WhisperPay: [PARSE] 📱 Decoded PIN code data:');
      debugPrint('WhisperPay: [PARSE]   SessionID: $sessionId');
      debugPrint('WhisperPay: [PARSE]   PIN Code: $pinCodeString');
      debugPrint('WhisperPay: [PARSE]   Amount: $amount XLM');
      debugPrint('WhisperPay: [PARSE]   Wallet address: $walletAddress');
      debugPrint('WhisperPay: [PARSE]   Wallet name: ${pinCodeModel.walletName}');
      debugPrint('WhisperPay: [PARSE]   RSSI: ${result.rssi} dBm');
      
      // Don't connect to our own session
      if (sessionId == _sessionId) {
        debugPrint('WhisperPay: [PARSE] ⚠️ Ignoring own session');
        return;
      }
      
      debugPrint('WhisperPay: [PARSE] ✅ Found valid WhisperPay session: $sessionId');
      
      // Create a beacon from discovered PIN code
      final beacon = WhisperPayBeacon(
        sessionId: sessionId,
        deviceId: 'PIN_$pinCodeString',
        timestamp: DateTime.now(),
        hmac: '',
        rssi: result.rssi,
        amount: amount, // Amount from PIN code
        walletAddress: walletAddress, // Wallet address from PIN code
      );
      
      debugPrint('WhisperPay: [PARSE] 🎯 Calling device discovered callback');
      onDeviceDiscovered?.call(beacon);
      
    } catch (e) {
      debugPrint('WhisperPay: [PARSE] ❌ Error parsing session data: $e');
      debugPrint('WhisperPay: [PARSE] Raw bytes: ${sessionBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
    }
  }



  /// Calculate distance from RSSI
  double _calculateDistance(int rssi) {
    if (rssi > -50) return 0.2; // Very close (~20cm)
    if (rssi > -60) return 0.5; // Close (~50cm)
    if (rssi > -70) return 1.0; // Medium (~1m)
    return double.infinity; // Too far
  }





  /// Create a new WhisperPay session
  Future<WhisperPaySession> _createSession({
    required String walletAddress,
    required String walletName,
    double? amount,
    String? memo,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    final now = DateTime.now();
    final sessionId = _generateSessionId();
    final deviceId = _generateDeviceId();
    
    debugPrint('WhisperPay: Creating session - ID: $sessionId, Wallet: $walletAddress, Amount: $amount');
    
    final session = WhisperPaySession(
      sessionId: sessionId,
      deviceId: deviceId,
      walletName: walletName,
      walletAddress: walletAddress,
      amount: amount,
      memo: memo,
      createdAt: now,
      expiresAt: now.add(timeout),
    );

    // Session created for local BLE advertising only

    return session;
  }

  /// Start BLE advertising with session data
  Future<void> _startAdvertising(WhisperPaySession session) async {
    try {
      // Check if peripheral mode is supported
      final isSupported = await _blePeripheral.isSupported;
      if (!isSupported) {
        debugPrint('WhisperPay: BLE peripheral mode not supported');
        return;
      }

      // Request BLE permissions first
      final hasPermissions = await _blePeripheral.requestPermission();
      if (hasPermissions != BluetoothPeripheralState.granted) {
        debugPrint('WhisperPay: BLE peripheral permissions not granted: $hasPermissions');
        return;
      }

      // Create PIN code for payment details
      if (session.walletAddress == null || session.walletAddress!.isEmpty) {
        debugPrint('WhisperPay: ERROR - No wallet address in session');
        throw Exception('No wallet address provided');
      }
      
      debugPrint('WhisperPay: Creating PIN code with wallet: ${session.walletAddress}, amount: ${session.amount}');
      final pinCode = await PinCodeService.createPinCode(
        walletPublicKey: session.walletAddress!,
        amount: session.amount ?? 0,
        walletName: session.walletName,
        memo: session.memo,
      );
      
      _currentPinCode = pinCode;
      debugPrint('WhisperPay: Created PIN code: ${pinCode.pinCode} for ${session.amount} XLM to ${session.walletAddress}');
      
      // Create 6-byte BLE data (just the PIN code)
      final pinCodeBytes = pinCode.pinCode.codeUnits;
      final sessionDataBytes = Uint8List.fromList(pinCodeBytes);
      
      debugPrint('WhisperPay: Creating advertising data - SessionID: ${session.sessionId}, PIN Code: ${pinCode.pinCode}, Amount: ${session.amount} XLM, Wallet: ${session.walletAddress}, Data size: ${sessionDataBytes.length} bytes');
      debugPrint('WhisperPay: Compact data bytes: ${sessionDataBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
      
      // Use service data approach (works better than manufacturer data)
      const serviceUuid = "0000180a-0000-1000-8000-00805f9b34fb"; // Device Information Service
      const serviceDataUuid = "0000180a-0000-1000-8000-00805f9b34fd"; // Custom UUID for data
      
      final advertisingData = AdvertiseData(
        serviceUuid: serviceUuid,
        serviceDataUuid: serviceDataUuid,
        serviceData: sessionDataBytes,
        includeDeviceName: false, // Keep device name disabled
      );
      
      final advertiseSetParameters = AdvertiseSetParameters(
        connectable: false, // We don't need connections, just discovery
        legacyMode: true, // For better compatibility
        scannable: false, // Not scannable to save space
        includeTxPowerLevel: false, // Don't include TX power
      );

      // Start advertising with detailed logging
      debugPrint('WhisperPay: [ADVERTISE] Attempting to start BLE advertising with service data...');
      debugPrint('WhisperPay: [ADVERTISE] Service UUID: $serviceUuid');
      debugPrint('WhisperPay: [ADVERTISE] Service Data UUID: $serviceDataUuid');
      debugPrint('WhisperPay: [ADVERTISE] Data size: ${sessionDataBytes.length} bytes');
      debugPrint('WhisperPay: [ADVERTISE] Device name: disabled, Connectable: false, Scannable: false');
      
      // Stop any previous advertising first
      await _blePeripheral.stop();
      
      // Start with new parameters
      await _blePeripheral.start(
        advertiseData: advertisingData,
        advertiseSetParameters: advertiseSetParameters,
      );
      debugPrint('WhisperPay: [ADVERTISE] ✅ Successfully started BLE advertising for session: ${session.sessionId}');
      debugPrint('WhisperPay: [ADVERTISE] Device should now be discoverable via service data');
      
    } catch (e) {
      debugPrint('WhisperPay: Failed to start BLE advertising: $e');
    }
  }

  /// Deactivate a session (BLE only - no Firebase)
  Future<void> _deactivateSession(String sessionId) async {
    // Just log for BLE-only implementation
    debugPrint('WhisperPay: Session $sessionId deactivated (local only)');
  }

  /// Generate unique session ID
  String _generateSessionId() {
    final random = Random.secure();
    final bytes = List<int>.generate(8, (i) => random.nextInt(256));
    return base64Url.encode(bytes).substring(0, 8);
  }

  /// Generate device ID
  String _generateDeviceId() {
    final random = Random.secure();
    final bytes = List<int>.generate(8, (i) => random.nextInt(256));
    return base64Url.encode(bytes).substring(0, 8);
  }



  /// Start periodic session cleanup
  void _startSessionCleanup() {
    _sessionCleanupTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _cleanupExpiredSessions();
    });
  }

  /// Clean up expired sessions (BLE only - no Firebase)
  Future<void> _cleanupExpiredSessions() async {
    // Local cleanup only for BLE implementation
    debugPrint('WhisperPay: Local session cleanup completed');
  }

  /// Stop current operation
  Future<void> stopCurrentOperation() async {
    switch (_state) {
      case WhisperPayState.receiveModeActive:
        await stopReceiveMode();
        break;
      case WhisperPayState.scanningForDevices:
        await stopScanning();
        break;
      default:
        _setState(WhisperPayState.idle);
        break;
    }
  }





  /// Set state and notify listeners
  void _setState(WhisperPayState newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
    }
  }

  /// Dispose resources
  @override
  void dispose() {
    _scanSubscription?.cancel();
    _sessionSubscription?.cancel();
    _receiveTimer?.cancel();
    _sessionCleanupTimer?.cancel();
    super.dispose();
  }
}