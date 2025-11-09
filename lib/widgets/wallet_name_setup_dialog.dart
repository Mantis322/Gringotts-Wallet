import 'package:flutter/material.dart';
import '../app/theme/colors.dart';
import '../services/wallet_registry_service.dart';

/// Wallet Name Setup Dialog
/// Shows when existing wallet needs Firebase registration
class WalletNameSetupDialog extends StatefulWidget {
  final String publicKey;
  final String currentWalletName;
  final VoidCallback onCompleted;

  const WalletNameSetupDialog({
    super.key,
    required this.publicKey,
    required this.currentWalletName,
    required this.onCompleted,
  });

  @override
  State<WalletNameSetupDialog> createState() => _WalletNameSetupDialogState();
}

class _WalletNameSetupDialogState extends State<WalletNameSetupDialog> {
  final _textController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;
  bool _isChecking = false;
  String? _errorMessage;
  String? _availabilityMessage;

  @override
  void initState() {
    super.initState();
    // Pre-fill with current wallet name (cleaned)
    _textController.text = _cleanWalletName(widget.currentWalletName);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  String _cleanWalletName(String name) {
    // Remove "Wallet" and numbers, make it clean for user
    return name
        .replaceAll(RegExp(r'Wallet\s*\d*', caseSensitive: false), '')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  Future<void> _checkAvailability(String walletName) async {
    if (walletName.length < 3) return;
    
    setState(() {
      _isChecking = true;
      _availabilityMessage = null;
      _errorMessage = null;
    });

    try {
      // First validate format
      final validation = WalletRegistryService.validateWalletName(walletName);
      if (!validation.isValid) {
        setState(() {
          _errorMessage = validation.error;
          _isChecking = false;
        });
        return;
      }

      // Then check availability
      final isAvailable = await WalletRegistryService.isWalletNameAvailable(walletName);
      setState(() {
        if (isAvailable) {
          _availabilityMessage = 'Great! "@$walletName" is available';
          _errorMessage = null;
        } else {
          _errorMessage = 'Sorry, "@$walletName" is already taken';
          _availabilityMessage = null;
        }
        _isChecking = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error checking availability: ${e.toString()}';
        _availabilityMessage = null;
        _isChecking = false;
      });
    }
  }

  Future<void> _registerWalletName() async {
    if (!_formKey.currentState!.validate()) return;
    
    final walletName = _textController.text.trim();
    
    setState(() => _isLoading = true);

    try {
      final success = await WalletRegistryService.registerWalletName(
        walletName: walletName,
        publicKey: widget.publicKey,
        displayName: walletName,
      );

      if (success) {
        widget.onCompleted();
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Wallet name "@$walletName" registered successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('WalletRegistryException: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.borderLight),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.badge_outlined,
                    color: AppColors.primaryPurple,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Setup Wallet Name',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Choose a unique name for easy transfers',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Info message
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.warning.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.warning,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'New feature! Give your wallet a unique name so others can send you XLM using @yourname instead of your long address.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Form
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Wallet Name',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  TextFormField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: 'Enter wallet name',
                      prefixText: '@',
                      prefixStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.primaryPurple,
                        fontWeight: FontWeight.w500,
                      ),
                      suffixIcon: _isChecking
                          ? Padding(
                              padding: const EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.primaryPurple,
                                  ),
                                ),
                              ),
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.surfaceInput,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.borderLight),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.borderLight),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.primaryPurple, width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.error, width: 2),
                      ),
                    ),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    onChanged: (value) {
                      // Debounce the availability check
                      Future.delayed(const Duration(milliseconds: 500), () {
                        if (_textController.text == value && value.isNotEmpty) {
                          _checkAvailability(value);
                        }
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a wallet name';
                      }
                      
                      final validation = WalletRegistryService.validateWalletName(value);
                      if (!validation.isValid) {
                        return validation.error;
                      }
                      
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Status messages
                  if (_errorMessage != null)
                    Text(
                      _errorMessage!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.error,
                      ),
                    )
                  else if (_availabilityMessage != null)
                    Text(
                      _availabilityMessage!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.success,
                      ),
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isLoading ? null : () {
                      Navigator.of(context).pop();
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Skip for now',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_isLoading || _isChecking || _errorMessage != null) 
                        ? null 
                        : _registerWalletName,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            'Register Name',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }
}