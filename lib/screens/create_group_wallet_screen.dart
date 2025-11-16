import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../app/theme/colors.dart';
import '../providers/wallet_provider.dart';
import '../services/group_wallet_service.dart';

class CreateGroupWalletScreen extends StatefulWidget {
  const CreateGroupWalletScreen({super.key});

  @override
  State<CreateGroupWalletScreen> createState() => _CreateGroupWalletScreenState();
}

class _CreateGroupWalletScreenState extends State<CreateGroupWalletScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _targetAmountController = TextEditingController();
  final _memberController = TextEditingController();
  final List<String> _members = [];
  bool _isLoading = false;
  DateTime? _targetDate;
  int _requiredSignatures = 1;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _targetAmountController.dispose();
    _memberController.dispose();
    super.dispose();
  }

  void _addMember() {
    final member = _memberController.text.trim();
    if (member.isEmpty) return;
    
    // Remove @ prefix if exists
    final cleanMember = member.startsWith('@') ? member.substring(1) : member;
    
    // Check if user is trying to add themselves
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final currentWalletName = walletProvider.activeWallet?.name;
    
    if (currentWalletName != null && cleanMember.toLowerCase() == currentWalletName.toLowerCase()) {
      _showSelfAddWarning();
      return;
    }
    
    // Check if member already exists
    if (_members.contains(cleanMember)) {
      _showDuplicateMemberWarning(cleanMember);
      return;
    }
    
    setState(() {
      _members.add(cleanMember);
      _memberController.clear();
      // Adjust required signatures when members change
      final maxSignatures = (_members.length + 1).clamp(1, 5);
      if (_requiredSignatures > maxSignatures) {
        _requiredSignatures = maxSignatures;
      }
    });
  }

  void _removeMember(String member) {
    setState(() {
      _members.remove(member);
      // Adjust required signatures when members change
      final maxSignatures = (_members.length + 1).clamp(1, 5);
      if (_requiredSignatures > maxSignatures) {
        _requiredSignatures = maxSignatures;
      }
    });
  }

  Future<void> _selectTargetDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.primaryPurple,
              surface: AppColors.surfaceCard,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (date != null) {
      setState(() {
        _targetDate = date;
      });
    }
  }

  Future<void> _createGroupWallet() async {
    if (!_formKey.currentState!.validate()) return;
    if (_members.isEmpty) {
      _showErrorDialog('Please add at least one member');
      return;
    }

    // Show confirmation dialog first
    final confirmed = await _showConfirmationDialog();
    if (!confirmed) return;

    setState(() => _isLoading = true);

    try {
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      final creatorWalletName = walletProvider.activeWallet?.name;
      
      if (creatorWalletName == null) {
        throw Exception('No active wallet found');
      }

      // Get creator's secret key for initial funding
      final creatorSecretKey = walletProvider.activeWallet?.secretKey;
      
      if (creatorSecretKey == null) {
        throw Exception('Creator wallet secret key not available');
      }

      final groupWalletId = await GroupWalletService.createGroupWallet(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        memberWalletNames: _members,
        creatorWalletName: creatorWalletName,
        creatorSecretKey: creatorSecretKey,
        targetAmount: double.parse(_targetAmountController.text.trim()),
        targetDate: _targetDate,
        requiredSignatures: _requiredSignatures,
      );

      if (mounted) {
        _showSuccessDialog(groupWalletId);
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSelfAddWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Cannot Add Yourself',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        content: Text(
          'You cannot add yourself as a member. As the creator, you are automatically included as an admin.',
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
  }

  void _showDuplicateMemberWarning(String member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: Row(
          children: [
            Icon(Icons.info, color: Colors.blue, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Member Already Added',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        content: Text(
          '@$member is already in the members list.',
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
  }

  Future<bool> _showConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: Row(
          children: [
            Icon(
              Icons.account_balance_wallet,
              color: AppColors.primaryPurple,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Confirm Group Wallet Creation',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.warning.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppColors.warning,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Account Activation Required',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'To create and activate the Group Wallet on Stellar network, 1 XLM will be transferred from your wallet to the new Group Wallet account.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            RichText(
              text: TextSpan(
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
                children: [
                  const TextSpan(text: '• '),
                  TextSpan(
                    text: '1 XLM',
                    style: TextStyle(
                      color: AppColors.primaryPurple,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const TextSpan(text: ' will be deducted from your current wallet\n'),
                  const TextSpan(text: '• This activates the Group Wallet on Stellar network\n'),
                  const TextSpan(text: '• The 1 XLM becomes part of the Group Wallet balance\n'),
                  const TextSpan(text: '• This is a one-time activation fee'),
                ],
              ),
            ),
          ],
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Confirm & Create'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Error',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        content: Text(
          message,
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

  void _showSuccessDialog(String groupWalletId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Group Wallet Created!',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your group wallet "${_nameController.text}" has been created successfully!',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Text(
                'Members can now start contributing to reach your target!',
                style: TextStyle(color: Colors.green),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Return to previous screen
            },
            child: Text(
              'Great!',
              style: TextStyle(color: AppColors.primaryPurple),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          'Create Group Wallet',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Basic Info
                _buildBasicInfoSection(),
                
                const SizedBox(height: 24),
                
                // Target & Date
                _buildTargetSection(),
                
                const SizedBox(height: 24),
                
                // Members
                _buildMembersSection(),
                
                const SizedBox(height: 24),
                
                // Settings
                _buildSettingsSection(),
                
                const SizedBox(height: 32),
                
                // Create Button
                _buildCreateButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceElevated),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Basic Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            
            // Group Name
            TextFormField(
              controller: _nameController,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Group Name',
                hintText: 'e.g., Holiday Fund',
                hintStyle: TextStyle(color: AppColors.textTertiary),
                labelStyle: TextStyle(color: AppColors.textSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.surfaceElevated),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primaryPurple, width: 2),
                ),
                filled: true,
                fillColor: AppColors.surfaceDark,
                prefixIcon: Icon(Icons.group, color: AppColors.primaryPurple),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a group name';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Description
            TextFormField(
              controller: _descriptionController,
              style: TextStyle(color: AppColors.textPrimary),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description',
                hintText: 'What is this group wallet for?',
                hintStyle: TextStyle(color: AppColors.textTertiary),
                labelStyle: TextStyle(color: AppColors.textSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.surfaceElevated),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primaryPurple, width: 2),
                ),
                filled: true,
                fillColor: AppColors.surfaceDark,
                prefixIcon: Icon(Icons.description, color: AppColors.primaryPurple),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please add a description';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    ).animate(delay: 200.ms)
        .slideY(begin: 0.3, duration: 500.ms)
        .fadeIn(duration: 500.ms);
  }

  Widget _buildTargetSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceElevated),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Target & Timeline',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            
            // Target Amount
            TextFormField(
              controller: _targetAmountController,
              style: TextStyle(color: AppColors.textPrimary),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Target Amount (XLM)',
                hintText: '0.0',
                hintStyle: TextStyle(color: AppColors.textTertiary),
                labelStyle: TextStyle(color: AppColors.textSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.surfaceElevated),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primaryPurple, width: 2),
                ),
                filled: true,
                fillColor: AppColors.surfaceDark,
                prefixIcon: Icon(Icons.savings, color: AppColors.primaryPurple),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter target amount';
                }
                final amount = double.tryParse(value.trim());
                if (amount == null || amount <= 0) {
                  return 'Please enter a valid amount';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Target Date
            InkWell(
              onTap: _selectTargetDate,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceElevated),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: AppColors.primaryPurple),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _targetDate == null 
                            ? 'Select Target Date (Optional)'
                            : 'Target: ${_targetDate!.day}/${_targetDate!.month}/${_targetDate!.year}',
                        style: TextStyle(
                          color: _targetDate == null ? AppColors.textTertiary : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (_targetDate != null)
                      IconButton(
                        icon: Icon(Icons.clear, color: AppColors.textSecondary, size: 20),
                        onPressed: () => setState(() => _targetDate = null),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate(delay: 400.ms)
        .slideY(begin: 0.3, duration: 500.ms)
        .fadeIn(duration: 500.ms);
  }

  Widget _buildMembersSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceElevated),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Group Members',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            
            // Add Member Input
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _memberController,
                    style: TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: '@username',
                      hintStyle: TextStyle(color: AppColors.textTertiary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.surfaceElevated),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.primaryPurple, width: 2),
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceDark,
                    ),
                    onFieldSubmitted: (_) => _addMember(),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 56,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _addMember,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPurple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(16),
                    ),
                    child: Icon(Icons.add, color: Colors.white),
                  ),
                ),
              ],
            ),
            
            if (_members.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Members (${_members.length})',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              
              // Members List
              ...List.generate(_members.length, (index) {
                final member = _members[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.surfaceElevated),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person, color: AppColors.primaryPurple, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '@$member',
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.remove_circle, color: Colors.red, size: 20),
                        onPressed: () => _removeMember(member),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    ).animate(delay: 600.ms)
        .slideY(begin: 0.3, duration: 500.ms)
        .fadeIn(duration: 500.ms);
  }

  Widget _buildSettingsSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceElevated),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Multi-Signature Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            
            Text(
              'Required Signatures for Spending',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            
            Row(
              children: [
                Flexible(
                  child: Slider(
                    value: _requiredSignatures.toDouble().clamp(1.0, (_members.length + 1).toDouble().clamp(1.0, 5.0)),
                    min: 1.0,
                    max: (_members.length + 1).toDouble().clamp(1.0, 5.0),
                    divisions: (_members.length).clamp(0, 4) > 0 ? (_members.length).clamp(1, 4) : null,
                    activeColor: AppColors.primaryPurple,
                    inactiveColor: AppColors.surfaceElevated,
                    onChanged: (value) {
                      setState(() {
                        _requiredSignatures = value.round().clamp(1, (_members.length + 1).clamp(1, 5));
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$_requiredSignatures/${_members.length + 1}',
                    style: TextStyle(
                      color: AppColors.primaryPurple,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            Text(
              'Spending requires $_requiredSignatures out of ${_members.length + 1} member approvals',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    ).animate(delay: 800.ms)
        .slideY(begin: 0.3, duration: 500.ms)
        .fadeIn(duration: 500.ms);
  }

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _createGroupWallet,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryPurple,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Create Group Wallet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
      ),
    ).animate(delay: 1000.ms)
        .slideY(begin: 0.3, duration: 500.ms)
        .fadeIn(duration: 500.ms);
  }
}