import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/auth_service.dart';
import '../app/colors.dart';

class PinUnlockScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onSuccess;
  final bool canUseBiometric;
  
  const PinUnlockScreen({
    super.key,
    this.title = 'Enter PIN',
    this.subtitle = 'Please enter your PIN to continue',
    this.onSuccess,
    this.canUseBiometric = true,
  });

  @override
  State<PinUnlockScreen> createState() => _PinUnlockScreenState();
}

class _PinUnlockScreenState extends State<PinUnlockScreen> {
  String _pin = '';
  bool _isLoading = false;
  String? _error;
  int _failedAttempts = 0;
  static const int _maxAttempts = 5;

  @override
  void initState() {
    super.initState();
    _tryBiometricAuth();
  }

  void _tryBiometricAuth() async {
    if (!widget.canUseBiometric) return;
    
    final methods = await AuthService.getAuthenticationMethods();
    if (!methods.isBiometricReady) return;
    
    // Small delay to let the screen build
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (mounted) {
      final success = await AuthService.authenticateWithBiometric(
        localizedReason: 'Unlock your Gringotts Wallet',
      );
      
      if (success && mounted) {
        widget.onSuccess?.call();
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.background,
              AppColors.surface.withAlpha(50),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height - 
                          MediaQuery.of(context).padding.top - 
                          MediaQuery.of(context).padding.bottom,
              ),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: _buildPinInput(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 60),
          // App Logo/Icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.account_balance,
              color: Colors.white,
              size: 40,
            ),
          ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
          
          const SizedBox(height: 32),
          
          Text(
            widget.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.2, end: 0),
          
          const SizedBox(height: 12),
          
          Text(
            widget.subtitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(duration: 300.ms, delay: 100.ms),
          
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withAlpha(100)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ).animate().shake(duration: 300.ms),
          ],
          
          if (_failedAttempts > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Attempts remaining: ${_maxAttempts - _failedAttempts}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.warning,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPinInput() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          
          // PIN Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: index < _pin.length 
                    ? AppColors.primary 
                    : AppColors.surface,
                  border: Border.all(
                    color: index < _pin.length 
                      ? AppColors.primary 
                      : AppColors.border,
                  ),
                ),
              ).animate().scale(
                duration: 200.ms,
                curve: Curves.elasticOut,
              );
            }),
          ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
          
          const SizedBox(height: 60),
          
          // Number Pad
          Expanded(
            child: _buildNumberPad(),
          ),
          
          // Biometric button
          if (widget.canUseBiometric) ...[
            const SizedBox(height: 20),
            _buildBiometricButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildNumberPad() {
    return Column(
      children: [
        // Numbers 1-3
        Row(
          children: [
            _buildNumberButton('1'),
            _buildNumberButton('2'),
            _buildNumberButton('3'),
          ],
        ),
        // Numbers 4-6
        Row(
          children: [
            _buildNumberButton('4'),
            _buildNumberButton('5'),
            _buildNumberButton('6'),
          ],
        ),
        // Numbers 7-9
        Row(
          children: [
            _buildNumberButton('7'),
            _buildNumberButton('8'),
            _buildNumberButton('9'),
          ],
        ),
        // 0 and delete
        Row(
          children: [
            const Expanded(child: SizedBox()),
            _buildNumberButton('0'),
            _buildDeleteButton(),
          ],
        ),
      ],
    );
  }

  Widget _buildNumberButton(String number) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isLoading ? null : () => _onNumberPressed(number),
            borderRadius: BorderRadius.circular(50),
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface.withAlpha(100),
                border: Border.all(color: AppColors.border.withAlpha(100)),
              ),
              child: Center(
                child: Text(
                  number,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isLoading ? null : _onDeletePressed,
            borderRadius: BorderRadius.circular(50),
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface.withAlpha(100),
                border: Border.all(color: AppColors.border.withAlpha(100)),
              ),
              child: Center(
                child: Icon(
                  Icons.backspace_outlined,
                  color: AppColors.textSecondary,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBiometricButton() {
    return FutureBuilder<AuthenticationMethods>(
      future: AuthService.getAuthenticationMethods(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.isBiometricReady) {
          return const SizedBox.shrink();
        }
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isLoading ? null : _tryBiometricAuth,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                decoration: BoxDecoration(
                  color: AppColors.surface.withAlpha(100),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border.withAlpha(100)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.fingerprint,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Use Biometric',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _onNumberPressed(String number) {
    if (_pin.length < 6) {
      setState(() {
        _error = null;
        _pin += number;
      });
      
      // Auto-verify when PIN is complete
      if (_pin.length == 6) {
        _verifyPin();
      }
    }
  }

  void _onDeletePressed() {
    if (_pin.isNotEmpty) {
      setState(() {
        _error = null;
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  void _verifyPin() async {
    setState(() => _isLoading = true);
    
    final isValid = await AuthService.verifyPin(_pin);
    
    if (isValid) {
      widget.onSuccess?.call();
      
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } else {
      setState(() {
        _isLoading = false;
        _failedAttempts++;
        _pin = '';
        
        if (_failedAttempts >= _maxAttempts) {
          _error = 'Too many failed attempts. Please restart the app.';
        } else {
          _error = 'Incorrect PIN. Please try again.';
        }
      });
      
      // Lock the app if too many attempts
      if (_failedAttempts >= _maxAttempts) {
        // You might want to implement app lock logic here
      }
    }
  }
}