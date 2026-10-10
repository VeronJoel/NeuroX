import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SellerCenterPage extends StatefulWidget {
  const SellerCenterPage({super.key});

  @override
  State<SellerCenterPage> createState() => _SellerCenterPageState();
}

class _SellerCenterPageState extends State<SellerCenterPage> {
  final _formKey = GlobalKey<FormState>();

  final _sellerNameController = TextEditingController();
  final _shopNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _category = 'Plants';
  bool _submitting = false;

  static const Color _green = Color(0xFF2E7D32);

  User? get _user => FirebaseAuth.instance.currentUser;

  DocumentReference<Map<String, dynamic>>? get _applicationRef {
    final user = _user;
    if (user == null) return null;

    return FirebaseFirestore.instance
        .collection('seller_applications')
        .doc(user.uid);
  }

  @override
  void dispose() {
    _sellerNameController.dispose();
    _shopNameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String? _required(String? value, String field) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter $field';
    }
    return null;
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) return;

    final user = _user;
    final applicationRef = _applicationRef;

    if (user == null || applicationRef == null) {
      _showMessage('Please sign in before applying.');
      return;
    }

    setState(() => _submitting = true);

    try {
      final existing = await applicationRef.get();

      if (existing.exists) {
        if (!mounted) return;
        _showMessage('An application already exists for this account.');
        return;
      }

      await applicationRef.set({
        'uid': user.uid,
        'email': user.email ?? '',
        'sellerName': _sellerNameController.text.trim(),
        'shopName': _shopNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'city': _cityController.text.trim(),
        'category': _category,
        'description': _descriptionController.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      _showMessage('Application submitted for review!');
    } on FirebaseException catch (e) {
      if (!mounted) return;

      _showMessage(
        e.code == 'permission-denied'
            ? 'Firestore rules do not allow this application yet.'
            : 'Could not submit application: ${e.message ?? e.code}',
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage('Something went wrong. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Widget _buildStatusCard(Map<String, dynamic> data) {
    final status = (data['status'] ?? 'pending').toString().toLowerCase();

    final Color statusColor;
    final IconData statusIcon;
    final String title;
    final String message;

    switch (status) {
      case 'approved':
        statusColor = _green;
        statusIcon = Icons.verified_outlined;
        title = 'Application approved';
        message =
            'Your seller application has been approved. '
            'Product listing access can be enabled next.';
        break;
      case 'rejected':
        statusColor = Colors.red.shade700;
        statusIcon = Icons.cancel_outlined;
        title = 'Application not approved';
        message =
            'Your application was not approved. '
            'Please contact the marketplace administrator '
            'for more information.';
        break;
      default:
        statusColor = Colors.orange.shade800;
        statusIcon = Icons.hourglass_top_rounded;
        title = 'Application under review';
        message =
            'Your details have been submitted. '
            'You can check back here for a status update.';
    }

    return Card(
      elevation: 0,
      color: statusColor.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(statusIcon, color: statusColor, size: 38),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(message),
            const Divider(height: 28),
            _detailRow('Shop', data['shopName']),
            _detailRow('Category', data['category']),
            _detailRow('City', data['city']),
            const SizedBox(height: 8),
            if (status == 'approved')
              const Text(
                'Note: approval status alone does not create '
                'a product listing or enable checkout.',
                style: TextStyle(fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text((value ?? '—').toString())),
        ],
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildApplicationForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Seller application',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Tell us about yourself and your gardening business.',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 20),
          _textField(
            controller: _sellerNameController,
            label: 'Your name',
            hint: 'Enter your full name',
            icon: Icons.person_outline,
            validator: (v) => _required(v, 'your name'),
          ),
          _textField(
            controller: _shopNameController,
            label: 'Shop or business name',
            hint: 'e.g. Green Leaf Nursery',
            icon: Icons.storefront_outlined,
            validator: (v) => _required(v, 'your shop name'),
          ),
          _textField(
            controller: _phoneController,
            label: 'Contact number',
            hint: 'Enter your phone number',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            validator: (v) {
              final requiredError = _required(v, 'a phone number');
              if (requiredError != null) return requiredError;

              final digits = v!.replaceAll(RegExp(r'\D'), '');
              if (digits.length < 10 || digits.length > 15) {
                return 'Enter a valid contact number';
              }
              return null;
            },
          ),
          _textField(
            controller: _cityController,
            label: 'City',
            hint: 'Where is your business located?',
            icon: Icons.location_city_outlined,
            validator: (v) => _required(v, 'your city'),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: DropdownButtonFormField<String>(
              value: _category,
              decoration: InputDecoration(
                labelText: 'Main product category',
                prefixIcon: const Icon(Icons.category_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Plants',
                  child: Text('Plants and saplings'),
                ),
                DropdownMenuItem(value: 'Seeds', child: Text('Seeds')),
                DropdownMenuItem(
                  value: 'Soil and Fertilizers',
                  child: Text('Soil and fertilizers'),
                ),
                DropdownMenuItem(
                  value: 'Pots and Accessories',
                  child: Text('Pots and accessories'),
                ),
                DropdownMenuItem(
                  value: 'Tools',
                  child: Text('Gardening tools'),
                ),
                DropdownMenuItem(
                  value: 'Smart Gardening',
                  child: Text('Smart gardening / IoT'),
                ),
                DropdownMenuItem(value: 'Other', child: Text('Other')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _category = value);
                }
              },
            ),
          ),
          _textField(
            controller: _descriptionController,
            label: 'About your business',
            hint: 'What do you sell? Tell us briefly.',
            icon: Icons.description_outlined,
            maxLines: 4,
            validator: (v) => _required(v, 'a business description'),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _submitting ? null : _submitApplication,
              icon: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(
                _submitting ? 'Submitting...' : 'Submit seller application',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Submitting this form does not guarantee approval. '
            'Do not enter bank or payment details here.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final applicationRef = _applicationRef;

    return Scaffold(
      backgroundColor: const Color(0xFFF6FAF5),
      appBar: AppBar(
        title: const Text('Seller Center'),
        backgroundColor: const Color(0xFFF6FAF5),
      ),
      body: SafeArea(
        child: applicationRef == null
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Please sign in to apply as a marketplace seller.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: applicationRef.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Could not load seller application.\n'
                          '${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final document = snapshot.data;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5F3E5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.storefront_rounded,
                                size: 42,
                                color: _green,
                              ),
                              SizedBox(height: 14),
                              Text(
                                'Grow your business with us',
                                style: TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Join local gardeners, nurseries and '
                                'suppliers on the Urban Farming AI '
                                'marketplace.',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (document?.exists == true)
                          _buildStatusCard(document!.data()!)
                        else
                          _buildApplicationForm(),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
