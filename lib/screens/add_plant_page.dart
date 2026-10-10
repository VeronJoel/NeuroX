import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/app_language_service.dart';
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
  final _nameController = TextEditingController();
  final _typeController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final FirestoreService _firestoreService = FirestoreService();
  final AppLanguageService _language = AppLanguageService.instance;

  File? _selectedImage;
  String _growthStage = 'Seedling';
  DateTime _plantingDate = DateUtils.dateOnly(DateTime.now());
  bool _isSaving = false;
  bool _isPickingImage = false;

  static const Color _background = Color(0xFFF6FAF5);
  static const Color _green = Color(0xFF388E3C);

  static const List<String> _growthStages = [
    'Seedling',
    'Young Plant',
    'Mature',
    'Flowering',
    'Fruiting',
  ];

  String _t(String key, String fallback) {
    final translated = _language.translate(key);
    return translated == key ? fallback : translated;
  }

  String _stageLabel(String stage) {
    switch (stage) {
      case 'Seedling':
        return _t('seedling', 'Seedling');
      case 'Young Plant':
        return _t('young_plant', 'Young Plant');
      case 'Mature':
        return _t('mature', 'Mature');
      case 'Flowering':
        return _t('flowering', 'Flowering');
      case 'Fruiting':
        return _t('fruiting', 'Fruiting');
      default:
        return stage;
    }
  }

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

  Future<void> _pickImage(ImageSource source) async {
    if (_isSaving || _isPickingImage) return;

    setState(() => _isPickingImage = true);

    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 35,
        maxWidth: 640,
        maxHeight: 640,
      );

      if (picked == null || !mounted) return;

      final imageFile = File(picked.path);

      if (!await imageFile.exists()) {
        _showMessage(
          _t(
            'selected_photo_unavailable',
            'The selected photo could not be opened.',
          ),
        );
        return;
      }

      final length = await imageFile.length();

      if (length == 0) {
        _showMessage(
          _t(
            'selected_photo_empty',
            'The selected photo is empty. Please try another.',
          ),
        );
        return;
      }

      setState(() => _selectedImage = imageFile);
    } catch (error) {
      debugPrint('Plant photo selection error: $error');
      _showMessage(
        source == ImageSource.camera
            ? _t(
                'camera_open_failed',
                'Could not open the camera. Check app permissions.',
              )
            : _t(
                'photo_select_failed',
                'Could not select the photo. Please try again.',
              ),
      );
    } finally {
      if (mounted) {
        setState(() => _isPickingImage = false);
      }
    }
  }

  void _showImageOptions() {
    if (_isSaving || _isPickingImage) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (sheetContext) {
        return AnimatedBuilder(
          animation: _language,
          builder: (context, _) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _t('choose_plant_photo', 'Choose a plant photo'),
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      leading: const Icon(
                        Icons.camera_alt_outlined,
                        color: _green,
                      ),
                      title: Text(_t('take_photo', 'Take a photo')),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _pickImage(ImageSource.camera);
                      },
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.photo_library_outlined,
                        color: _green,
                      ),
                      title: Text(_t('choose_gallery', 'Choose from gallery')),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _pickImage(ImageSource.gallery);
                      },
                    ),
                    if (_selectedImage != null)
                      ListTile(
                        leading: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        title: Text(_t('remove_photo', 'Remove photo')),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          setState(() => _selectedImage = null);
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<String?> _prepareImageForFirestore() async {
    final image = _selectedImage;
    if (image == null) return null;

    if (!await image.exists()) {
      throw Exception(
        _t(
          'photo_no_longer_available',
          'The selected photo is no longer available.',
        ),
      );
    }

    final bytes = await image.readAsBytes();

    if (bytes.isEmpty) {
      throw Exception(
        _t(
          'photo_empty_choose_again',
          'The selected photo is empty. Please choose it again.',
        ),
      );
    }

    if (bytes.length > 350000) {
      throw Exception(
        _t(
          'photo_too_large',
          'This photo is too large. Please choose a smaller photo.',
        ),
      );
    }

    final encoded = base64Encode(bytes);

    if (encoded.length > 500000) {
      throw Exception(
        _t(
          'photo_storage_too_large',
          'The photo is too large to store. Please choose a smaller photo.',
        ),
      );
    }

    return encoded;
  }

  Future<void> _savePlant() async {
    FocusScope.of(context).unfocus();

    if (_isSaving || _isPickingImage) return;
    if (!_formKey.currentState!.validate()) return;

    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(
        _t('login_before_adding_plant', 'Please log in before adding a plant.'),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final imageBase64 = await _prepareImageForFirestore();

      await _firestoreService.addPlant(
        name: _nameController.text.trim(),
        type: _typeController.text.trim(),
        plantedDate: _plantingDate,
        growthStage: _growthStage,
        imageBase64: imageBase64,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _t('plant_added_successfully', '🌱 Plant added successfully!'),
            ),
            backgroundColor: _green,
            behavior: SnackBarBehavior.floating,
          ),
        );

      Navigator.pop(context, true);
    } catch (error, stackTrace) {
      debugPrint('Add plant save error: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      final rawMessage = error.toString().replaceFirst('Exception: ', '');
      final message = _translateKnownError(rawMessage);

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '${_t('could_not_save_plant', 'Could not save plant')}: $message',
            ),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 7),
          ),
        );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _translateKnownError(String message) {
    final knownErrors = <String, String>{
      'The selected photo is no longer available.': 'photo_no_longer_available',
      'The selected photo is empty. Please choose it again.':
          'photo_empty_choose_again',
      'This photo is too large. Please choose a smaller photo.':
          'photo_too_large',
      'The photo is too large to store. Please choose a smaller photo.':
          'photo_storage_too_large',
    };

    final key = knownErrors[message];
    if (key == null) return message;

    return _t(key, message);
  }

  Future<void> _selectPlantingDate() async {
    if (_isSaving) return;

    final today = DateUtils.dateOnly(DateTime.now());

    final picked = await showDatePicker(
      context: context,
      initialDate: _plantingDate.isAfter(today) ? today : _plantingDate,
      firstDate: DateTime(2000),
      lastDate: today,
      helpText: _t('select_planting_date', 'Select planting date'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _green,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null || !mounted) return;

    setState(() => _plantingDate = DateUtils.dateOnly(picked));
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t('plant_photo', 'Plant Photo'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          _t(
            'photo_instructions',
            'Take a photo or choose one from your gallery.',
          ),
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
              ? InkWell(
                  onTap: _isPickingImage ? null : _showImageOptions,
                  borderRadius: BorderRadius.circular(22),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo_outlined,
                        size: 58,
                        color: Colors.green.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _t('add_plant_photo', 'Add a plant photo'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _isPickingImage ? null : _showImageOptions,
                        icon: _isPickingImage
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.photo_library_outlined),
                        label: Text(
                          _isPickingImage
                              ? _t(
                                  'opening_photo_picker',
                                  'Opening photo picker...',
                                )
                              : _t('camera_gallery', 'Camera / Gallery'),
                        ),
                      ),
                    ],
                  ),
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(21),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(
                        _selectedImage!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          return Center(
                            child: Text(
                              _t(
                                'photo_preview_failed',
                                'Unable to preview this photo',
                              ),
                            ),
                          );
                        },
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: IconButton.filled(
                          tooltip: _t('remove_photo', 'Remove photo'),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black54,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _isSaving
                              ? null
                              : () => setState(() => _selectedImage = null),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                      Positioned(
                        bottom: 10,
                        left: 10,
                        right: 10,
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _isSaving || _isPickingImage
                                  ? null
                                  : () => _pickImage(ImageSource.camera),
                              icon: const Icon(Icons.camera_alt),
                              label: Text(_t('retake', 'Retake')),
                            ),
                            ElevatedButton.icon(
                              onPressed: _isSaving || _isPickingImage
                                  ? null
                                  : () => _pickImage(ImageSource.gallery),
                              icon: const Icon(Icons.photo_library),
                              label: Text(_t('change', 'Change')),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String fieldKey,
  }) {
    return TextFormField(
      controller: controller,
      textCapitalization: TextCapitalization.words,
      enabled: !_isSaving,
      maxLength: 100,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        counterText: '',
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
          borderSide: const BorderSide(color: _green, width: 2),
        ),
      ),
      validator: (value) {
        final text = value?.trim() ?? '';

        if (text.isEmpty) {
          return _t(
            'please_enter_field',
            'Please enter {field}.',
          ).replaceAll('{field}', label);
        }

        if (text.length > 100) {
          return _t(
            'field_max_length',
            '{field} must be 100 characters or fewer.',
          ).replaceAll('{field}', label);
        }

        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateText =
        '${_plantingDate.day.toString().padLeft(2, '0')}/'
        '${_plantingDate.month.toString().padLeft(2, '0')}/'
        '${_plantingDate.year}';

    return AnimatedBuilder(
      animation: _language,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: _background,
          appBar: AppBar(
            title: Text(
              _t('add_new_plant', 'Add New Plant'),
              style: const TextStyle(fontWeight: FontWeight.bold),
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
                    Text(
                      _t('start_your_garden', 'Start your garden 🌱'),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _t(
                        'plant_tracking_intro',
                        'Tell us about your plant and we will start tracking its health.',
                      ),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 25),
                    _buildPhotoSection(),
                    const SizedBox(height: 28),
                    _buildTextField(
                      controller: _nameController,
                      label: _t('plant_name', 'Plant name'),
                      hint: _t(
                        'plant_name_example',
                        'Example: My Tomato Plant',
                      ),
                      icon: Icons.eco,
                      fieldKey: 'plant_name',
                    ),
                    const SizedBox(height: 18),
                    _buildTextField(
                      controller: _typeController,
                      label: _t('plant_type', 'Plant type'),
                      hint: _t('plant_type_example', 'Example: Tomato'),
                      icon: Icons.local_florist,
                      fieldKey: 'plant_type',
                    ),
                    const SizedBox(height: 22),
                    Text(
                      _t('planting_date', 'Planting date'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: _isSaving ? null : _selectPlantingDate,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 17,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.green.shade100),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_month, color: _green),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  dateText,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      _t('growth_stage', 'Growth stage'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
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
                          items: _growthStages.map((stage) {
                            final emoji = switch (stage) {
                              'Seedling' => '🌱',
                              'Young Plant' => '🌿',
                              'Mature' => '🌳',
                              'Flowering' => '🌸',
                              'Fruiting' => '🍅',
                              _ => '🌱',
                            };

                            return DropdownMenuItem<String>(
                              value: stage,
                              child: Text('$emoji ${_stageLabel(stage)}'),
                            );
                          }).toList(),
                          onChanged: _isSaving
                              ? null
                              : (value) {
                                  if (value == null ||
                                      !_growthStages.contains(value)) {
                                    return;
                                  }
                                  setState(() => _growthStage = value);
                                },
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
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
                          Icon(
                            Icons.auto_awesome,
                            color: Colors.green.shade700,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _t(
                                'ai_doctor_tip',
                                'After adding your plant, scan its leaves with the AI Doctor to monitor its health and detect possible problems.',
                              ),
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
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving || _isPickingImage
                            ? null
                            : _savePlant,
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
                          _isSaving
                              ? _t('adding_plant', 'Adding Plant...')
                              : _t(
                                  'add_plant_to_garden',
                                  'Add Plant to My Garden',
                                ),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _green,
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
                        _t(
                          'change_details_later',
                          'You can change these details later.',
                        ),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
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
}
