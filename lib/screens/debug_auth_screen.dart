import 'package:flutter/material.dart';
import '../services/auth_service.dart';

/// Debug screen to check PIN and auth status
class DebugAuthScreen extends StatefulWidget {
  const DebugAuthScreen({super.key});

  @override
  State<DebugAuthScreen> createState() => _DebugAuthScreenState();
}

class _DebugAuthScreenState extends State<DebugAuthScreen> {
  Map<String, dynamic> authStatus = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    setState(() => isLoading = true);
    
    try {
      final results = <String, dynamic>{};
      
      results['isPinSetup'] = await AuthService.isPinSetup();
      results['isAuthRequired'] = await AuthService.isAuthRequired();
      results['isBiometricEnabled'] = await AuthService.isBiometricEnabled();
      results['isBiometricAvailable'] = await AuthService.isBiometricAvailable();
      
      final availableBiometrics = await AuthService.getAvailableBiometrics();
      results['availableBiometrics'] = availableBiometrics.map((e) => e.name).toList();
      
      final authMethods = await AuthService.getAuthenticationMethods();
      results['authMethods'] = {
        'biometricAvailable': authMethods.biometricAvailable,
        'biometricEnabled': authMethods.biometricEnabled,
        'pinSetup': authMethods.pinSetup,
        'authRequired': authMethods.authRequired,
        'hasAnyMethod': authMethods.hasAnyMethod,
        'isBiometricReady': authMethods.isBiometricReady,
      };
      
      setState(() {
        authStatus = results;
        isLoading = false;
      });
      
    } catch (e) {
      setState(() {
        authStatus = {'error': e.toString()};
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Auth Status'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkAuthStatus,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Authentication Status:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ...authStatus.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '${entry.key}: ${entry.value}',
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () async {
                      await AuthService.clearAuthData();
                      _checkAuthStatus();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Auth data cleared')),
                        );
                      }
                    },
                    child: const Text('Clear All Auth Data'),
                  ),
                ],
              ),
            ),
    );
  }
}