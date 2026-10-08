import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/firestore_service.dart';

class AddPlantPage extends StatefulWidget {
  final String? initialPlantName;
  final String? initialPlantType;

  const AddPlantPage({super.key, this.initialPlantName, this.initialPlantType});

  @override
  State<AddPlantPage> createState() => _AddPlantPageState();
}

class _AddPlantPageState extends State<AddPlantPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _typeController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  final FirestoreService _firestoreService = FirestoreService();

  File? _selectedImage;

  String _growthStage = 'Seedling';

  DateTime _plantingDate = DateTime.now();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    _nameController.text = widget.initialPlantName ?? '';
    _typeController.text = widget.initialPlantType ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _typeController.dispose();
    super.dispose();
  }

  // ============================================================
  // IMAGE PICKER
  // ============================================================

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 55,
        maxWidth: 900,
        maxHeight: 900,
      );

      if (image == null) return;

      setState(() {
        _selectedImage = File(image.path);
      });
    } catch (e) {
      _showMessage('Could not open the camera.');
    }
  }

  Future<void> _chooseFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 55,
        maxWidth: 900,
        maxHeight: 900,
      );

      if (image == null) return;

      setState(() {
        _selectedImage = File(image.path);
      });
    } catch (e) {
      _showMessage('Could not open the gallery.');
    }
  }

  void _removePhoto() {
    setState(() {
      _selectedImage = null;
    });
  }

  // ============================================================
  // DATE PICKER
  // ============================================================

  Future<void> _selectPlantingDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _plantingDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked == null) return;

    setState(() {
      _plantingDate = picked;
    });
  }

  // ============================================================
  // PHOTO → BASE64
  // ============================================================

  Future<String?> _prepareImageForFirestore() async {
    if (_selectedImage == null) {
      return null;
    }

    try {
      final bytes = await _selectedImage!.readAsBytes();

      // Keep the stored image safely below Firestore's
      // document size limit.

      if (bytes.length > 450000) {
        _showMessage(
          'Photo is too large to store. '
          'The plant will be saved without the photo.',
        );

        return null;
      }

      return base64Encode(bytes);
    } catch (e) {
      return null;
    }
  }

  // ============================================================
  // SAVE PLANT
  // ============================================================

  Future<void> _savePlant() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('Please log in before adding a plant.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final imageBase64 = await _prepareImageForFirestore();

      final plantName = _nameController.text.trim();
      final plantType = _typeController.text.trim();

      // Add plant using the existing Firestore service.
      await _firestoreService.addPlant(
        name: plantName,
        type: plantType,
        plantedDate: _plantingDate,
      );

      // Find the newly-created plant.
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('plants')
          .where('name', isEqualTo: plantName)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final plantRef = snapshot.docs.first.reference;

        final Map<String, dynamic> additionalData = {
          'growthStage': _growthStage,
          'healthScore': 100,
          'previousHealthScore': 100,
          'diseaseStatus': 'Healthy',
          'status': 'Healthy',
          'observations': [],
          'possibleCauses': [],
          'treatment': [],
          'prevention': [],
          'wateringAdvice': 'Monitor soil moisture regularly.',
          'sunlightAdvice': 'Provide suitable sunlight for this plant.',
          'recoveryPlan': [],
          'needsRescan': false,
          'rescanAfterDays': 0,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (imageBase64 != null) {
          additionalData['imageBase64'] = imageBase64;
          additionalData['hasPlantPhoto'] = true;
        } else {
          additionalData['hasPlantPhoto'] = false;
        }

        await plantRef.update(additionalData);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🌱 Plant added successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Could not save the plant.\n'
        'Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
    );
  }

  // ============================================================
  // PHOTO SECTION
  // ============================================================

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Plant Photo',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 6),

        Text(
          'Add a photo so you can recognize this plant later.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),

        const SizedBox(height: 14),

        Container(
          width: double.infinity,
          height: 230,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.green.shade100, width: 1.5),
          ),
          child: _selectedImage == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.local_florist,
                      size: 65,
                      color: Colors.green.shade300,
                    ),

                    const SizedBox(height: 10),

                    Text(
                      'No photo added',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 18),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _takePhoto,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Camera'),
                        ),

                        const SizedBox(width: 10),

                        OutlinedButton.icon(
                          onPressed: _chooseFromGallery,
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Gallery'),
                        ),
                      ],
                    ),
                  ],
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(21),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(_selectedImage!, fit: BoxFit.cover),

                      Positioned(
                        top: 10,
                        right: 10,
                        child: Material(
                          color: Colors.black54,
                          shape: const CircleBorder(),
                          child: IconButton(
                            onPressed: _removePhoto,
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                        ),
                      ),

                      Positioned(
                        bottom: 10,
                        left: 10,
                        right: 10,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _takePhoto,
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('Retake'),
                            ),

                            const SizedBox(width: 10),

                            ElevatedButton.icon(
                              onPressed: _chooseFromGallery,
                              icon: const Icon(Icons.photo_library),
                              label: const Text('Change'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  // ============================================================
  // TEXT FIELD
  // ============================================================

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return TextFormField(
      controller: controller,
      textCapitalization: TextCapitalization.words,

      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.white,

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.green.shade100),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.green.shade600, width: 2),
        ),
      ),

      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter $label';
        }

        return null;
      },
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FAF5),

      appBar: AppBar(
        title: const Text(
          'Add New Plant',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),

      body: SafeArea(
        child: Form(
          key: _formKey,

          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                // ==================================================
                // HEADER
                // ==================================================

                const Text(
                  'Start your garden 🌱',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 6),

                Text(
                  'Tell us a little about your plant and we '
                  'will start tracking its health.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                ),

                const SizedBox(height: 25),

                // ==================================================
                // PHOTO
                // ==================================================
                _buildPhotoSection(),

                const SizedBox(height: 28),

                // ==================================================
                // NAME
                // ==================================================
                _buildTextField(
                  controller: _nameController,
                  label: 'Plant name',
                  hint: 'Example: My Tomato Plant',
                  icon: Icons.eco,
                ),

                const SizedBox(height: 18),

                // ==================================================
                // TYPE
                // ==================================================
                _buildTextField(
                  controller: _typeController,
                  label: 'Plant type',
                  hint: 'Example: Tomato',
                  icon: Icons.local_florist,
                ),

                const SizedBox(height: 22),

                // ==================================================
                // PLANTING DATE
                // ==================================================
                const Text(
                  'Planting date',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 8),

                InkWell(
                  onTap: _selectPlantingDate,
                  borderRadius: BorderRadius.circular(16),

                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 17,
                    ),

                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.green.shade100),
                    ),

                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_month,
                          color: Colors.green.shade700,
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Text(
                            '${_plantingDate.day.toString().padLeft(2, '0')}/'
                            '${_plantingDate.month.toString().padLeft(2, '0')}/'
                            '${_plantingDate.year}',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),

                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                // ==================================================
                // GROWTH STAGE
                // ==================================================
                const Text(
                  'Growth stage',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 8),

                Container(
                  width: double.infinity,

                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.shade100),
                  ),

                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _growthStage,
                      isExpanded: true,

                      padding: const EdgeInsets.symmetric(horizontal: 16),

                      borderRadius: BorderRadius.circular(16),

                      items: const [
                        DropdownMenuItem(
                          value: 'Seedling',
                          child: Text('🌱 Seedling'),
                        ),
                        DropdownMenuItem(
                          value: 'Young Plant',
                          child: Text('🌿 Young Plant'),
                        ),
                        DropdownMenuItem(
                          value: 'Mature',
                          child: Text('🌳 Mature'),
                        ),
                        DropdownMenuItem(
                          value: 'Flowering',
                          child: Text('🌸 Flowering'),
                        ),
                        DropdownMenuItem(
                          value: 'Fruiting',
                          child: Text('🍅 Fruiting'),
                        ),
                      ],

                      onChanged: (value) {
                        if (value == null) return;

                        setState(() {
                          _growthStage = value;
                        });
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                // ==================================================
                // INFO CARD
                // ==================================================
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),

                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.green.shade100),
                  ),

                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Icon(Icons.auto_awesome, color: Colors.green.shade700),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Text(
                          'After adding your plant, you can scan '
                          'its leaves with the AI Doctor to monitor '
                          'its health and detect possible problems.',
                          style: TextStyle(
                            color: Colors.green.shade900,
                            height: 1.4,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ==================================================
                // SAVE BUTTON
                // ==================================================
                SizedBox(
                  width: double.infinity,
                  height: 58,

                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _savePlant,

                    icon: _isSaving
                        ? const SizedBox(
                            width: 21,
                            height: 21,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.add_circle_outline),

                    label: Text(
                      _isSaving ? 'Adding Plant...' : 'Add Plant to My Garden',

                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.green.shade300,

                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                Center(
                  child: Text(
                    'You can change these details later.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
