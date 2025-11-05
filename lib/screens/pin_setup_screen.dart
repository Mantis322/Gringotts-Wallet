import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/auth_service.dart';
import '../app/colors.dart';

class PinSetupScreen extends StatefulWidget {
  final bool isChangingPin;
  final VoidCallback? onSuccess;
  
  const PinSetupScreen({
    super.key,
    this.isChangingPin = false,
    this.onSuccess,
  });

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String _pin = '';
  String _confirmPin = '';
  String _oldPin = '';
  bool _isConfirming = false;
  bool _isLoading = false;
  String? _error;
  bool _isOldPinStep = false;

  @override
  void initState() {
    super.initState();
    // If changing PIN, start with old PIN verification
    if (widget.isChangingPin) {
      _isOldPinStep = true;
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
    );
  }

  Widget _buildHeader() {
    String title;
    String subtitle;
    
    if (widget.isChangingPin) {
      if (_isOldPinStep) {
        title = 'Enter Current PIN';
        subtitle = 'Please enter your current PIN to continue';
      } else if (_isConfirming) {
        title = 'Confirm New PIN';
        subtitle = 'Please re-enter your new PIN';
      } else {
        title = 'Enter New PIN';
        subtitle = 'Create a new 6-digit PIN';
      }
    } else {
      if (_isConfirming) {
        title = 'Confirm PIN';
        subtitle = 'Please re-enter your PIN';
      } else {
        title = 'Create PIN';
        subtitle = 'Create a 6-digit PIN to secure your wallet';
      }
    }
    
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _canGoBack() ? _handleBack : null,
                icon: Icon(
                  Icons.arrow_back_ios,
                  color: _canGoBack() ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              if (widget.isChangingPin && !_isOldPinStep)
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.primary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.2, end: 0),
          const SizedBox(height: 12),
          Text(
            subtitle,
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
        ],
      ),
    );
  }

  Widget _buildPinInput() {
    final currentPin = _getCurrentPin();
    
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
                  color: index < currentPin.length 
                    ? AppColors.primary 
                    : AppColors.surface,
                  border: Border.all(
                    color: index < currentPin.length 
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

  String _getCurrentPin() {
    if (_isOldPinStep) return _oldPin;
    if (_isConfirming) return _confirmPin;
    return _pin;
  }

  void _setCurrentPin(String pin) {
    if (_isOldPinStep) {
      _oldPin = pin;
    } else if (_isConfirming) {
      _confirmPin = pin;
    } else {
      _pin = pin;
    }
  }

  bool _canGoBack() {
    if (_isOldPinStep) return false;
    if (widget.isChangingPin && !_isConfirming) return true;
    if (!widget.isChangingPin && _isConfirming) return true;
    return false;
  }

  void _handleBack() {
    setState(() {
      _error = null;
      if (_isConfirming) {
        _isConfirming = false;
        _confirmPin = '';
      }
    });
  }

  void _onNumberPressed(String number) {
    final currentPin = _getCurrentPin();
    
    if (currentPin.length < 6) {
      setState(() {
        _error = null;
        _setCurrentPin(currentPin + number);
      });
      
      // Auto-proceed when PIN is complete
      if (currentPin.length + 1 == 6) {
        _handlePinComplete();
      }
    }
  }

  void _onDeletePressed() {
    final currentPin = _getCurrentPin();
    
    if (currentPin.isNotEmpty) {
      setState(() {
        _error = null;
        _setCurrentPin(currentPin.substring(0, currentPin.length - 1));
      });
    }
  }

  void _handlePinComplete() {
    if (_isOldPinStep) {
      _verifyOldPin();
    } else if (_isConfirming) {
      _confirmPinMatch();
    } else {
      _proceedToConfirmation();
    }
  }

  void _verifyOldPin() async {
    setState(() => _isLoading = true);
    
    final isValid = await AuthService.verifyPin(_oldPin);
    
    if (isValid) {
      setState(() {
        _isOldPinStep = false;
        _isLoading = false;
        _error = null;
      });
    } else {
      setState(() {
        _isLoading = false;
        _error = 'Incorrect PIN. Please try again.';
        _oldPin = '';
      });
    }
  }

  void _proceedToConfirmation() {
    setState(() {
      _isConfirming = true;
      _error = null;
    });
  }

  void _confirmPinMatch() async {
    if (_pin != _confirmPin) {
      setState(() {
        _error = 'PINs do not match. Please try again.';
        _confirmPin = '';
      });
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      if (widget.isChangingPin) {
        final success = await AuthService.changePin(_oldPin, _pin);
        if (!success) {
          throw Exception('Failed to change PIN');
        }
      } else {
        await AuthService.setupPin(_pin);
        await AuthService.setAuthRequired(true);
      }
      
      widget.onSuccess?.call();
      
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to setup PIN. Please try again.';
        _pin = '';
        _confirmPin = '';
        _isConfirming = false;
      });
    }
  }
}