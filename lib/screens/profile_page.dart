import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'achievements_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _loading = true;

  String _displayName = '';

  int _plantCount = 0;
  int _healthyPlants = 0;
  int _attentionPlants = 0;
  int _averageHealth = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  CollectionReference<Map<String, dynamic>> get _plantsRef {
    final uid = _auth.currentUser!.uid;

    return _firestore.collection('users').doc(uid).collection('plants');
  }

  DocumentReference<Map<String, dynamic>> get _userRef {
    final uid = _auth.currentUser!.uid;

    return _firestore.collection('users').doc(uid);
  }

  Future<void> _loadProfile() async {
    if (_auth.currentUser == null) {
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final userDoc = await _userRef.get();

      final plants = await _plantsRef.get();

      int totalHealth = 0;
      int healthy = 0;
      int attention = 0;

      for (final plant in plants.docs) {
        final data = plant.data();

        final health = (data['healthScore'] as num?)?.toInt() ?? 100;

        totalHealth += health;

        if (health >= 80) {
          healthy++;
        } else {
          attention++;
        }
      }

      final average = plants.docs.isEmpty
          ? 0
          : (totalHealth / plants.docs.length).round();

      final firestoreName = userDoc.data()?['displayName']?.toString();

      final email = _auth.currentUser?.email ?? '';

      final fallbackName = email.contains('@')
          ? email.split('@').first
          : 'Gardener';

      if (!mounted) return;

      setState(() {
        _displayName = firestoreName?.isNotEmpty == true
            ? firestoreName!
            : fallbackName;

        _plantCount = plants.docs.length;

        _healthyPlants = healthy;

        _attentionPlants = attention;

        _averageHealth = average;

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _editName() async {
    final controller = TextEditingController(text: _displayName);

    final result = await showDialog<String>(
      context: context,

      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Name'),

          content: TextField(
            controller: controller,

            autofocus: true,

            textCapitalization: TextCapitalization.words,

            decoration: const InputDecoration(
              labelText: 'Display name',
              prefixIcon: Icon(Icons.person),
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },

              child: const Text('Cancel'),
            ),

            ElevatedButton(
              onPressed: () {
                final name = controller.text.trim();

                if (name.isNotEmpty) {
                  Navigator.pop(context, name);
                }
              },

              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == null || result.trim().isEmpty) {
      return;
    }

    try {
      await _userRef.set({
        'displayName': result.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      setState(() {
        _displayName = result.trim();
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profile updated')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update profile: $e')));
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,

      builder: (context) {
        return AlertDialog(
          title: const Text('Log out?'),

          content: const Text(
            'You can sign in again anytime to access your garden.',
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },

              child: const Text('Cancel'),
            ),

            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },

              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),

              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    await _auth.signOut();

    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  int _calculateXp() {
    final base = _plantCount * 50;

    final healthyBonus = _healthyPlants >= 5 ? 150 : _healthyPlants * 20;

    return base + healthyBonus;
  }

  int _calculateLevel() {
    final xp = _calculateXp();

    return (xp ~/ 500) + 1;
  }

  Color _healthColor(int health) {
    if (health >= 80) {
      return Colors.green;
    }

    if (health >= 60) {
      return Colors.orange;
    }

    return Colors.red;
  }

  Widget _buildProfileHeader() {
    final email = _auth.currentUser?.email ?? '';

    final firstLetter = _displayName.isNotEmpty
        ? _displayName[0].toUpperCase()
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
                _displayName.isEmpty ? 'Gardener' : _displayName,

                maxLines: 1,

                overflow: TextOverflow.ellipsis,

                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            IconButton(
              onPressed: _editName,

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
      ],
    );
  }

  Widget _buildLevelCard() {
    final level = _calculateLevel();

    final xp = _calculateXp();

    final currentLevelXp = xp % 500;

    final progress = currentLevelXp / 500;

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
                  color: Colors.white.withOpacity(0.15),
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
                      'Level $level',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      '$xp XP earned',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          ClipRRect(
            borderRadius: BorderRadius.circular(20),

            child: LinearProgressIndicator(
              value: progress,

              minHeight: 9,

              backgroundColor: Colors.white.withOpacity(0.18),

              color: Colors.white,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            '${500 - currentLevelXp} XP to next level',

            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Row(
      children: [
        Expanded(child: _stat(Icons.eco_outlined, '$_plantCount', 'Plants')),

        const SizedBox(width: 10),

        Expanded(
          child: _stat(Icons.favorite_outline, '$_healthyPlants', 'Healthy'),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: _stat(
            Icons.warning_amber_outlined,
            '$_attentionPlants',
            'Attention',
          ),
        ),
      ],
    );
  }

  Widget _stat(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),

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
                const Text(
                  'Garden Health',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),

                const SizedBox(height: 4),

                Text(
                  _plantCount == 0
                      ? 'Add plants to calculate your garden health.'
                      : 'Your average plant health is $_averageHealth/100.',

                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsButton() {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AchievementsPage()),
        );
      },

      borderRadius: BorderRadius.circular(20),

      child: Container(
        padding: const EdgeInsets.all(18),

        decoration: BoxDecoration(
          color: Colors.white,

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

            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    'Achievements',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),

                  SizedBox(height: 4),

                  Text(
                    'Track your gardening progress and unlock rewards.',
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ),

            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
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
          ListTile(
            leading: const Icon(Icons.person_outline),

            title: const Text('Account'),

            subtitle: const Text('Manage your profile'),

            trailing: const Icon(Icons.chevron_right),

            onTap: _editName,
          ),

          const Divider(height: 1),

          ListTile(
            leading: const Icon(Icons.info_outline),

            title: const Text('About Urban Farming AI'),

            subtitle: const Text('AI-powered plant care assistant'),

            trailing: const Icon(Icons.chevron_right),

            onTap: _showAbout,
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

      children: const [
        Text(
          'An AI-powered urban farming assistant '
          'for plant health monitoring, disease '
          'detection, watering guidance and smart '
          'garden management.',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_auth.currentUser == null) {
      return const Scaffold(body: Center(child: Text('Please log in again.')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6FAF5),

      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),

        backgroundColor: const Color(0xFFF6FAF5),

        elevation: 0,

        actions: [
          IconButton(
            tooltip: 'Refresh',

            onPressed: _loadProfile,

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

                        label: const Text(
                          'Log Out',
                          style: TextStyle(
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
  }
}
