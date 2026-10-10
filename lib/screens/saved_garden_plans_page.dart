import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/app_language_service.dart';

class SavedGardenPlansPage extends StatefulWidget {
  const SavedGardenPlansPage({super.key});

  @override
  State<SavedGardenPlansPage> createState() => _SavedGardenPlansPageState();
}

class _SavedGardenPlansPageState extends State<SavedGardenPlansPage> {
  bool _deleting = false;

  final AppLanguageService _language = AppLanguageService.instance;

  String _t(String key, String fallback) {
    final translated = _language.translate(key);
    return translated == key ? fallback : translated;
  }

  String _withValue(String key, String fallback, String value) {
    return _t(key, fallback).replaceAll('{value}', value);
  }

  CollectionReference<Map<String, dynamic>>? get _plans {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return null;

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('balconyPlans');
  }

  Future<void> _deletePlan(
    BuildContext context,
    String planId,
    String planName,
  ) async {
    final plans = _plans;

    if (plans == null) {
      _showMessage(
        _t(
          'saved_plans_sign_in_delete',
          'Please sign in to delete a saved plan.',
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t('saved_plans_delete_title', 'Delete saved plan?')),
        content: Text(
          _t(
            'saved_plans_delete_confirmation',
            'Delete "{value}" permanently?',
          ).replaceAll('{value}', planName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_t('cancel', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(_t('delete', 'Delete')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);

    try {
      await plans.doc(planId).delete();

      if (!mounted) return;

      _showMessage(_t('saved_plans_deleted', 'Garden plan deleted.'));
    } on FirebaseException catch (error) {
      if (!mounted) return;

      _showMessage(
        '${_t('saved_plans_delete_error', 'Could not delete plan')}: '
        '${error.message ?? error.code}',
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        '${_t('saved_plans_delete_error', 'Could not delete plan')}: $error',
      );
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showPlanDetails(BuildContext context, Map<String, dynamic> plan) {
    final plants =
        (plan['plants'] as List<dynamic>?)
            ?.map((item) => item.toString())
            .toList() ??
        <String>[];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => AnimatedBuilder(
        animation: _language,
        builder: (context, _) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan['name']?.toString() ??
                      _t('saved_plans_default_name', 'Balcony garden plan'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _detail(
                  _t('saved_plans_length', 'Balcony length'),
                  '${plan['length'] ?? '-'} ft',
                ),
                _detail(
                  _t('saved_plans_width', 'Balcony width'),
                  '${plan['width'] ?? '-'} ft',
                ),
                _detail(
                  _t('saved_plans_sunlight', 'Sunlight'),
                  plan['sunlight']?.toString() ?? '-',
                ),
                _detail(
                  _t('saved_plans_goal', 'Garden goal'),
                  plan['goal']?.toString() ?? '-',
                ),
                _detail(
                  _t('saved_plans_experience', 'Experience'),
                  plan['experience']?.toString() ?? '-',
                ),
                _detail(
                  _t('saved_plans_layout', 'Layout'),
                  plan['layout']?.toString() ?? '-',
                ),
                _detail(
                  _t('saved_plans_budget', 'Budget'),
                  '₹${_formatNumber(plan['budget'])}',
                ),
                _detail(
                  _t('saved_plans_estimated_cost', 'Estimated cost'),
                  '₹${_formatNumber(plan['estimatedTotal'])}',
                ),
                const SizedBox(height: 14),
                Text(
                  _t('saved_plans_recommended_plants', 'Recommended plants'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (plants.isEmpty)
                  Text(
                    _t('saved_plans_no_plant_list', 'No plant list was saved.'),
                  )
                else
                  ...plants.map(
                    (plant) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.eco_outlined,
                            color: Color(0xFF287342),
                            size: 19,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(plant)),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  _t(
                    'saved_plans_cost_disclaimer',
                    'Cost figures are estimates. Actual prices and plant suitability depend on your location, pot sizes, availability and growing conditions.',
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.blueGrey,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(label, style: const TextStyle(color: Colors.blueGrey)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(dynamic value) {
    if (value is num) return value.round().toString();
    return value?.toString() ?? '0';
  }

  Widget _buildError(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _t('saved_plans_load_error', 'Could not load saved plans.'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error is FirebaseException
                  ? '${error.code}: ${error.message ?? 'Unknown Firebase error'}'
                  : error.toString(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh),
              label: Text(_t('try_again', 'Try again')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                color: Color(0xFFE4F1E5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.yard_outlined,
                size: 46,
                color: Color(0xFF287342),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _t('saved_plans_empty_title', 'No saved plans yet'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
            ),
            const SizedBox(height: 8),
            Text(
              _t(
                'saved_plans_empty_description',
                'Your saved balcony garden plans will appear here.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanList(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFE4F1E5),
            borderRadius: BorderRadius.circular(17),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.bookmark_added_outlined,
                color: Color(0xFF287342),
                size: 30,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _withValue(
                    'saved_plans_count',
                    '{value} saved garden plans',
                    docs.length.toString(),
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ...docs.map((doc) {
          final data = doc.data();
          final name =
              data['name']?.toString() ??
              _t('saved_plans_default_name', 'Balcony garden');
          final plants = (data['plants'] as List<dynamic>?)?.length ?? 0;
          final total = _formatNumber(data['estimatedTotal']);
          final sunlight =
              data['sunlight']?.toString() ??
              _t('saved_plans_sunlight_unspecified', 'Sunlight unspecified');

          return Card(
            color: Colors.white,
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
              side: const BorderSide(color: Color(0xFFE2EAE0)),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(17),
              onTap: () => _showPlanDetails(context, data),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE4F1E5),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Icon(
                            Icons.yard_outlined,
                            color: Color(0xFF287342),
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          enabled: !_deleting,
                          onSelected: (value) {
                            if (value == 'delete') {
                              _deletePlan(context, doc.id, name);
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _t(
                                      'saved_plans_delete_plan',
                                      'Delete plan',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 13),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _tag(
                          Icons.eco_outlined,
                          _withValue(
                            'saved_plans_plant_count',
                            '{value} plants',
                            plants.toString(),
                          ),
                        ),
                        _tag(
                          Icons.currency_rupee,
                          _withValue(
                            'saved_plans_estimated',
                            '₹{value} estimated',
                            total,
                          ),
                        ),
                        _tag(Icons.wb_sunny_outlined, sunlight),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          _t('saved_plans_view_details', 'View plan details'),
                          style: const TextStyle(
                            color: Color(0xFF287342),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 15,
                          color: Colors.grey.shade600,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _tag(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F5EE),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF287342)),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final plans = _plans;

    if (plans == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48),
              const SizedBox(height: 12),
              Text(
                _t('saved_plans_sign_in_view', 'Sign in to view saved plans.'),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: plans.orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildError(snapshot.error!);
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return _buildEmptyState();
        }

        return _buildPlanList(docs);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _language,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF5F8F4),
          appBar: AppBar(
            title: Text(
              _t('saved_plans_title', 'Saved Garden Plans'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: const Color(0xFFF5F8F4),
          ),
          body: _buildContent(),
        );
      },
    );
  }
}
