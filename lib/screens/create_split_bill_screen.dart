import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../app/theme/colors.dart';
import '../providers/wallet_provider.dart';
import '../services/split_bill_service.dart';

class CreateSplitBillScreen extends StatefulWidget {
  const CreateSplitBillScreen({super.key});

  @override
  State<CreateSplitBillScreen> createState() => _CreateSplitBillScreenState();
}

class _CreateSplitBillScreenState extends State<CreateSplitBillScreen> {
  final _formKey = GlobalKey<FormState>();
  final _totalAmountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _participantController = TextEditingController();
  
  final List<String> _participants = [];
  bool _isLoading = false;
  
  @override
  void dispose() {
    _totalAmountController.dispose();
    _descriptionController.dispose();
    _participantController.dispose();
    super.dispose();
  }

  void _addParticipant() {
    final participant = _participantController.text.trim();
    if (participant.isEmpty) return;
    
    // Remove @ prefix if exists to match wallet names consistently
    final cleanParticipant = participant.startsWith('@') 
        ? participant.substring(1) 
        : participant;
    
    // Check if user is trying to add themselves
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final currentWalletName = walletProvider.activeWallet?.name;
    
    if (currentWalletName != null && cleanParticipant.toLowerCase() == currentWalletName.toLowerCase()) {
      _showSelfAddWarning();
      return;
    }
    
    // Check if participant already exists
    if (_participants.contains(cleanParticipant)) {
      _showDuplicateParticipantWarning(cleanParticipant);
      return;
    }
    
    setState(() {
      _participants.add(cleanParticipant);
      _participantController.clear();
    });
  }

  void _removeParticipant(String participant) {
    setState(() {
      _participants.remove(participant);
    });
  }

  Future<void> _createSplitBill() async {
    if (!_formKey.currentState!.validate()) return;
    
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final creatorWalletName = walletProvider.activeWallet?.name;
    
    if (creatorWalletName == null || creatorWalletName.isEmpty) {
      _showErrorDialog('Error', 'No active wallet found. Please create or select a wallet first.');
      return;
    }

    if (_participants.isEmpty) {
      _showErrorDialog('Error', 'Please add at least one participant.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final totalAmount = double.parse(_totalAmountController.text);
      final description = _descriptionController.text.trim();

      await SplitBillService.createSplitBill(
        creatorWalletName: creatorWalletName,
        totalAmount: totalAmount,
        description: description,
        participantWalletNames: _participants,
        expiryDuration: const Duration(days: 7),
      );

      if (mounted) {
        _showSuccessDialog('Split Bill Created!', 
          'Split bill created successfully. Participants will receive notifications to pay their share.',
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Error', 'Failed to create split bill: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: Text(title, style: const TextStyle(color: Colors.red)),
        content: Text(message, style: TextStyle(color: AppColors.textPrimary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: AppColors.primaryPurple)),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: Text(title, style: const TextStyle(color: Colors.green)),
        content: Text(message, style: TextStyle(color: AppColors.textPrimary)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close screen
            },
            child: Text('OK', style: TextStyle(color: AppColors.primaryPurple)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amountPerPerson = _participants.isNotEmpty && _totalAmountController.text.isNotEmpty
        ? (double.tryParse(_totalAmountController.text) ?? 0.0) / _participants.length
        : 0.0;

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
          'Split Bill',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    'Create Split Bill',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Split expenses with friends and family easily',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Total Amount
                  _buildTotalAmountField(),
                  
                  const SizedBox(height: 24),
                  
                  // Description
                  _buildDescriptionField(),
                  
                  const SizedBox(height: 24),
                  
                  // Participants Section
                  _buildParticipantsSection(),
                  
                  const SizedBox(height: 24),
                  
                  // Summary
                  if (_participants.isNotEmpty)
                    _buildSummary(amountPerPerson),
                  
                  const SizedBox(height: 32),
                  
                  // Create Button
                  _buildCreateButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTotalAmountField() {
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
              'Total Amount',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _totalAmountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,7}$')),
              ],
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: '0.0000000',
                hintStyle: TextStyle(color: AppColors.textTertiary),
                suffixText: 'XLM',
                suffixStyle: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryPurple,
                ),
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
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter total amount';
                }
                final amount = double.tryParse(value);
                if (amount == null || amount <= 0) {
                  return 'Please enter a valid amount';
                }
                return null;
              },
              onChanged: (value) => setState(() {}),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionField() {
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
              'Description',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'e.g., Dinner at Restaurant',
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
    );
  }

  Widget _buildParticipantsSection() {
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
              'Other Participants',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add other people to split the bill with (you are automatically included)',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            
            // Add participant field
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _participantController,
                    style: TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: '@walletname',
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
                    onFieldSubmitted: (_) => _addParticipant(),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 56,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _addParticipant,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPurple,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Participants list
            if (_participants.isNotEmpty) ...[
              Text(
                'Other Participants (${_participants.length})',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              for (final participant in _participants)
                _buildParticipantChip(participant),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantChip(String participant) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primaryPurple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryPurple.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.person,
            color: AppColors.primaryPurple,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              participant,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            onPressed: () => _removeParticipant(participant),
            icon: const Icon(
              Icons.close,
              color: Colors.red,
              size: 20,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(double amountPerPerson) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.accentGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Amount:',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                Text(
                  '${_totalAmountController.text} XLM',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Per Person:',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                Text(
                  '${amountPerPerson.toStringAsFixed(7)} XLM',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Participants:',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                Text(
                  '${_participants.length} people',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _createSplitBill,
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
                'Create Split Bill',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
      ),
    );
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
          'You cannot add yourself as a participant to your own split bill. As the creator, you will collect the payments from other participants.',
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

  void _showDuplicateParticipantWarning(String participant) {
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
                'Participant Already Added',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        content: Text(
          '@$participant is already in the participants list.',
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
}