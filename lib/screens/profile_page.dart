import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/app_language_service.dart';
import 'achievements_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AppLanguageService _language = AppLanguageService.instance;

  static const int _xpPerLevel = 500;
  static const int _maxLevel = 1000;
  static const int _maxXp = _xpPerLevel * _maxLevel;

  bool _loading = true;
  bool _savingName = false;

  String _displayName = '';

  int _plantCount = 0;
  int _healthyPlants = 0;
  int _attentionPlants = 0;
  int _averageHealth = 0;

  int _wateringCount = 0;
  int _scanCount = 0;
  int _diaryCount = 0;
  int _advisorCount = 0;
  int _recoveredPlants = 0;
  int _xp = 0;

  User? get _currentUser => _auth.currentUser;

  CollectionReference<Map<String, dynamic>> get _plantsRef {
    final user = _currentUser!;
    return _firestore.collection('users').doc(user.uid).collection('plants');
  }

  DocumentReference<Map<String, dynamic>> get _userRef {
    final user = _currentUser!;
    return _firestore.collection('users').doc(user.uid);
  }

  int get _level => ((_xp ~/ _xpPerLevel) + 1).clamp(1, _maxLevel);

  int get _currentLevelXp => _xp % _xpPerLevel;

  double get _levelProgress => _currentLevelXp / _xpPerLevel;

  String _t(String key, String fallback) {
    final result = _language.translate(key);
    return result == key ? fallback : result;
  }

  String get _title {
    if (_level >= 100) {
      return _t('legendary_urban_farmer', 'Legendary Urban Farmer');
    }
    if (_level >= 50) {
      return _t('master_urban_farmer', 'Master Urban Farmer');
    }
    if (_level >= 20) {
      return _t('garden_champion', 'Garden Champion');
    }
    if (_level >= 10) {
      return _t('master_gardener', 'Master Gardener');
    }
    if (_level >= 7) {
      return _t('garden_expert', 'Garden Expert');
    }
    if (_level >= 5) {
      return _t('plant_specialist', 'Plant Specialist');
    }
    if (_level >= 3) {
      return _t('urban_gardener', 'Urban Gardener');
    }
    return _t('garden_beginner', 'Garden Beginner');
  }

  @override
  void initState() {
    super.initState();
    _language.load();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = _currentUser;

    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    if (mounted) setState(() => _loading = true);

    try {
      final userDocFuture = _userRef.get();
      final plantsFuture = _plantsRef.get();

      final userDoc = await userDocFuture.timeout(const Duration(seconds: 25));
      final plantsSnapshot = await plantsFuture.timeout(
        const Duration(seconds: 25),
      );

      int totalHealth = 0;
      int healthyCount = 0;
      int attentionCount = 0;
      int wateringCount = 0;
      int scanCount = 0;
      int diaryCount = 0;
      int recoveredCount = 0;

      for (final plantDoc in plantsSnapshot.docs) {
        final data = plantDoc.data();

        final rawHealth = data['healthScore'] ?? data['health'];
        final health = rawHealth is num ? rawHealth.toInt().clamp(0, 100) : 100;

        totalHealth += health;

        if (health >= 80) {
          healthyCount++;
        } else {
          attentionCount++;
        }

        final previousValue = data['previousHealthScore'];
        final previousHealth = previousValue is num
            ? previousValue.toInt()
            : null;

        if (previousHealth != null && previousHealth < 80 && health >= 80) {
          recoveredCount++;
        }

        final scansSnapshot = await plantDoc.reference
            .collection('scans')
            .get()
            .timeout(const Duration(seconds: 25));

        scanCount += scansSnapshot.docs.length;

        final diarySnapshot = await plantDoc.reference
            .collection('diary')
            .get()
            .timeout(const Duration(seconds: 25));

        diaryCount += diarySnapshot.docs.length;

        for (final diary in diarySnapshot.docs) {
          final type = diary.data()['type']?.toString().toLowerCase() ?? '';

          if (type == 'watering') {
            wateringCount++;
          }
        }
      }

      final activitySnapshot = await _userRef
          .collection('activity')
          .get()
          .timeout(const Duration(seconds: 25));

      int advisorCount = 0;

      for (final activity in activitySnapshot.docs) {
        final type = activity.data()['type']?.toString().toLowerCase() ?? '';

        if (type == 'advisor') {
          advisorCount++;
        }
      }

      final plantCount = plantsSnapshot.docs.length;
      final averageHealth = plantCount == 0
          ? 0
          : (totalHealth / plantCount).round();

      final savedName = userDoc.data()?['displayName']?.toString().trim() ?? '';
      final authName = user.displayName?.trim() ?? '';
      final email = user.email ?? '';

      final fallbackName = email.contains('@')
          ? email.split('@').first
          : 'Gardener';

      final calculatedXp = _calculateXp(
        plantCount: plantCount,
        wateringCount: wateringCount,
        scanCount: scanCount,
        diaryCount: diaryCount,
        advisorCount: advisorCount,
        healthyPlants: healthyCount,
        recoveredPlants: recoveredCount,
      );

      if (!mounted) return;

      setState(() {
        _displayName = savedName.isNotEmpty
            ? savedName
            : authName.isNotEmpty
            ? authName
            : fallbackName;

        _plantCount = plantCount;
        _healthyPlants = healthyCount;
        _attentionPlants = attentionCount;
        _averageHealth = averageHealth;

        _wateringCount = wateringCount;
        _scanCount = scanCount;
        _diaryCount = diaryCount;
        _advisorCount = advisorCount;
        _recoveredPlants = recoveredCount;

        _xp = calculatedXp.clamp(0, _maxXp);
        _loading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Profile loading error: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_t('could_not_refresh_profile', 'Could not refresh your profile')}: $error',
          ),
          action: SnackBarAction(
            label: _t('retry', 'Retry'),
            onPressed: _loadProfile,
          ),
        ),
      );
    }
  }

  int _calculateXp({
    required int plantCount,
    required int wateringCount,
    required int scanCount,
    required int diaryCount,
    required int advisorCount,
    required int healthyPlants,
    required int recoveredPlants,
  }) {
    int xp = 0;

    xp += plantCount * 50;
    xp += wateringCount * 10;
    xp += scanCount * 40;
    xp += diaryCount * 15;
    xp += advisorCount * 30;

    if (healthyPlants >= 3) xp += 100;
    if (healthyPlants >= 5) xp += 150;
    if (recoveredPlants >= 1) xp += 100;
    if (recoveredPlants >= 3) xp += 200;

    return xp;
  }

  Future<void> _editName() async {
    if (_savingName) return;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _EditNameDialog(initialName: _displayName, language: _language),
    );

    if (!mounted || result == null || result.trim().isEmpty) return;

    final newName = result.trim();

    if (newName == _displayName.trim()) return;

    setState(() => _savingName = true);

    try {
      final user = _currentUser;

      if (user == null) {
        throw Exception(
          _t(
            'session_expired',
            'Your session has expired. Please sign in again.',
          ),
        );
      }

      await user.updateDisplayName(newName);

      await _userRef.set({
        'displayName': newName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      setState(() => _displayName = newName);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t('profile_name_updated', 'Profile name updated successfully.'),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_t('could_not_update_name', 'Could not update your name')}: $error',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AnimatedBuilder(
          animation: _language,
          builder: (context, _) => AlertDialog(
            title: Text(_t('log_out_question', 'Log out?')),
            content: Text(
              _t(
                'logout_description',
                'You can sign in again anytime to access your garden.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(_t('cancel', 'Cancel')),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(_t('log_out', 'Log Out')),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      await _auth.signOut();

      if (!mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_t('could_not_log_out', 'Could not log out')}: $error',
          ),
        ),
      );
    }
  }

  Color _healthColor(int health) {
    if (health >= 80) return Colors.green;
    if (health >= 60) return Colors.orange;
    return Colors.red;
  }

  Widget _buildProfileHeader() {
    final email = _currentUser?.email ?? '';
    final firstLetter = _displayName.trim().isNotEmpty
        ? _displayName.trim()[0].toUpperCase()
        : 'G';

    return Column(
      children: [
        Container(
          width: 94,
          height: 94,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade700, Colors.green.shade400],
            ),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              firstLetter,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 42,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                _displayName.isEmpty
                    ? _t('gardener', 'Gardener')
                    : _displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              tooltip: _t('edit_name', 'Edit name'),
              onPressed: _savingName ? null : _editName,
              icon: const Icon(Icons.edit_outlined, size: 18),
            ),
          ],
        ),
        Text(
          email,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        if (_savingName)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }

  Widget _buildLevelCard() {
    final xpToNextLevel = _xpPerLevel - _currentLevelXp;
    final isMaxLevel = _level >= _maxLevel;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade800, Colors.green.shade500],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.emoji_events_outlined,
                    color: Colors.white,
                    size: 29,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_t('level', 'Level')} $_level',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _title,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$_xp ${_t('xp_earned', 'XP earned')}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Text('🌱', style: TextStyle(fontSize: 30)),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: isMaxLevel ? 1 : _levelProgress,
              minHeight: 9,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isMaxLevel
                ? _t('maximum_level_reached', 'Maximum level reached!')
                : '$xpToNextLevel ${_t('xp_to_next_level', 'XP to next level')}',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const SizedBox(height: 10),
          Text(
            _t(
              'earn_xp_description',
              'Water plants, scan plant health, record diary entries, and use the AI Advisor to earn XP.',
            ),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _xpChip(Icons.eco_outlined, _t('plants', 'Plants'), _plantCount),
              _xpChip(
                Icons.water_drop_outlined,
                _t('waterings', 'Waterings'),
                _wateringCount,
              ),
              _xpChip(
                Icons.document_scanner_outlined,
                _t('scans', 'Scans'),
                _scanCount,
              ),
              _xpChip(
                Icons.auto_awesome_outlined,
                _t('ai_questions', 'AI questions'),
                _advisorCount,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _xpChip(IconData icon, String label, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 5),
          Text(
            '$label: $count',
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Row(
      children: [
        Expanded(
          child: _stat(
            Icons.eco_outlined,
            '$_plantCount',
            _t('plants', 'Plants'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _stat(
            Icons.favorite_outline,
            '$_healthyPlants',
            _t('healthy', 'Healthy'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _stat(
            Icons.warning_amber_outlined,
            '$_attentionPlants',
            _t('attention', 'Attention'),
          ),
        ),
      ],
    );
  }

  Widget _stat(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.green.shade700, size: 23),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthCard() {
    final color = _healthColor(_averageHealth);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 65,
            height: 65,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: _averageHealth / 100,
                  strokeWidth: 7,
                  backgroundColor: Colors.grey.shade200,
                  color: color,
                ),
                Text(
                  '$_averageHealth',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('garden_health', 'Garden Health'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _plantCount == 0
                      ? _t(
                          'add_plants_for_health',
                          'Add plants to calculate your garden health.',
                        )
                      : '${_t('average_plant_health', 'Your average plant health is')} $_averageHealth/100.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                if (_attentionPlants > 0) ...[
                  const SizedBox(height: 5),
                  Text(
                    '$_attentionPlants ${_t('plants_need_attention', 'plant(s) may need attention.')}',
                    style: const TextStyle(color: Colors.orange, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsButton() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () async {
          await Navigator.push<void>(
            context,
            MaterialPageRoute<void>(builder: (_) => const AchievementsPage()),
          );

          if (mounted) _loadProfile();
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green.shade100),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.emoji_events_outlined,
                  color: Colors.amber.shade700,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('achievements', 'Achievements'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _t(
                        'achievements_description',
                        'Track your gardening progress and unlock rewards.',
                      ),
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(_t('edit_name', 'Edit Name')),
              subtitle: Text(
                _t('change_display_name', 'Change your display name'),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _savingName ? null : _editName,
            ),
          ),
          const Divider(height: 1),
          Material(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(
                _t('about_urban_farming_ai', 'About Urban Farming AI'),
              ),
              subtitle: Text(
                _t(
                  'ai_plant_care_assistant',
                  'AI-powered plant care assistant',
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showAbout,
            ),
          ),
        ],
      ),
    );
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'Urban Farming AI',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          color: Colors.green.shade700,
          shape: BoxShape.circle,
        ),
        child: const Center(child: Text('🌱', style: TextStyle(fontSize: 24))),
      ),
      children: [
        Text(
          _t(
            'about_app_description',
            'An AI-powered urban farming assistant for plant health monitoring, disease detection, watering guidance and smart garden management.',
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        body: Center(
          child: Text(_t('please_log_in_again', 'Please log in again.')),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _language,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF6FAF5),
          appBar: AppBar(
            title: Text(
              _t('profile', 'Profile'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: const Color(0xFFF6FAF5),
            elevation: 0,
            actions: [
              IconButton(
                tooltip: _t('refresh_profile', 'Refresh profile'),
                onPressed: _loading ? null : _loadProfile,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadProfile,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 35),
                    child: Column(
                      children: [
                        _buildProfileHeader(),
                        const SizedBox(height: 25),
                        _buildLevelCard(),
                        const SizedBox(height: 16),
                        _buildStats(),
                        const SizedBox(height: 16),
                        _buildHealthCard(),
                        const SizedBox(height: 16),
                        _buildAchievementsButton(),
                        const SizedBox(height: 16),
                        _buildAccountCard(),
                        const SizedBox(height: 25),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: OutlinedButton.icon(
                            onPressed: _logout,
                            icon: const Icon(Icons.logout, color: Colors.red),
                            label: Text(
                              _t('log_out', 'Log Out'),
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _EditNameDialog extends StatefulWidget {
  final String initialName;
  final AppLanguageService language;

  const _EditNameDialog({required this.initialName, required this.language});

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  late final TextEditingController _controller;
  String? _error;

  String _t(String key, String fallback) {
    final result = widget.language.translate(key);
    return result == key ? fallback : result;
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final name = _controller.text.trim();

    if (name.isEmpty) {
      setState(() {
        _error = _t('please_enter_name', 'Please enter a name.');
      });
      return;
    }

    if (name.length > 40) {
      setState(() {
        _error = _t('name_max_length', 'Use 40 characters or fewer.');
      });
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.language,
      builder: (context, _) {
        return AlertDialog(
          title: Text(_t('edit_name', 'Edit Name')),
          content: TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            maxLength: 40,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: _t('display_name', 'Display name'),
              hintText: _t('enter_your_name', 'Enter your name'),
              prefixIcon: const Icon(Icons.person_outline),
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                FocusManager.instance.primaryFocus?.unfocus();
                Navigator.of(context).pop();
              },
              child: Text(_t('cancel', 'Cancel')),
            ),
            FilledButton(onPressed: _save, child: Text(_t('save', 'Save'))),
          ],
        );
      },
    );
  }
}
