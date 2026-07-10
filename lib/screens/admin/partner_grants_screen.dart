import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../design_system/constants/colors.dart';
import '../../design_system/constants/typography.dart';
import '../../design_system/constants/decorations.dart';
import '../../design_system/components/backgrounds/gradient_background.dart';
import '../../design_system/components/modals/confirm_dialog.dart';
import '../../services/partner_grant_service.dart';

class PartnerGrantsScreen extends StatefulWidget {
  const PartnerGrantsScreen({super.key});

  @override
  State<PartnerGrantsScreen> createState() => _PartnerGrantsScreenState();
}

class _PartnerGrantsScreenState extends State<PartnerGrantsScreen> {
  List<Map<String, dynamic>> _grants = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGrants();
  }

  Future<void> _loadGrants() async {
    setState(() => _isLoading = true);
    try {
      final grants = await PartnerGrantService.getAllGrants();
      // Sort: active first, then expired, then revoked, then by grantedAt desc
      grants.sort((a, b) {
        final aStatus = a['status'] as String? ?? '';
        final bStatus = b['status'] as String? ?? '';
        final aOrder = _statusSortOrder(aStatus);
        final bOrder = _statusSortOrder(bStatus);
        if (aOrder != bOrder) return aOrder.compareTo(bOrder);
        final aTime = a['grantedAt'] as Timestamp?;
        final bTime = b['grantedAt'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });
      setState(() {
        _grants = grants;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  int _statusSortOrder(String status) {
    switch (status) {
      case 'active':
        return 0;
      case 'expired':
        return 1;
      default:
        return 2; // revoked
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Stack(
        children: [
          const GradientBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.accentPrimary))
                      : _grants.isEmpty
                          ? _buildEmptyState()
                          : _buildGrantList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'User Management',
              style: AppTypography.ibm(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GestureDetector(
            onTap: _showAddPartnerSheet,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.accentPrimary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person_add_alt_1,
                  color: AppColors.accentPrimary, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.handshake_outlined,
              color: AppColors.textDisabled, size: 48),
          const SizedBox(height: 12),
          Text(
            'No partner grants yet',
            style: AppTypography.ibm(
              color: AppColors.textDisabled,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to grant a user free access',
            style: AppTypography.ibm(
              color: AppColors.textDisabled,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrantList() {
    return RefreshIndicator(
      onRefresh: _loadGrants,
      color: AppColors.accentPrimary,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: _grants.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _buildGrantCard(_grants[i]),
      ),
    );
  }

  Widget _buildGrantCard(Map<String, dynamic> grant) {
    final status = (grant['status'] as String?) ?? 'revoked';
    final isActive = status == 'active';
    final tier = (grant['tier'] as String?) ?? 'pro';
    final aiQuota = grant['aiQuota'] as int? ?? 0;
    final name = (grant['displayName'] as String?) ?? '';
    final email = (grant['email'] as String?) ?? '';
    final notes = (grant['notes'] as String?) ?? '';
    final grantedAt = grant['grantedAt'] as Timestamp?;
    final expiresAt = grant['expiresAt'] as Timestamp?;
    final dateStr = grantedAt != null
        ? DateFormat('MMM d, yyyy').format(grantedAt.toDate())
        : '';

    // Check if an "active" grant has actually expired client-side
    final effectiveStatus = isActive &&
            expiresAt != null &&
            DateTime.now().isAfter(expiresAt.toDate())
        ? 'expired'
        : status;

    final remainingTime = isActive && expiresAt != null
        ? PartnerGrantService.formatRemainingTime(expiresAt)
        : null;
    final isUrgent = remainingTime != null &&
        expiresAt != null &&
        expiresAt.toDate().difference(DateTime.now()).inDays < 7;

    return GestureDetector(
      onTap: () => _showEditSheet(grant),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
          border: Border.all(
            color: effectiveStatus == 'active'
                ? AppColors.accentPrimary.withValues(alpha: 0.2)
                : AppColors.separatorDark,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name + status
            Row(
              children: [
                Expanded(
                  child: Text(
                    name.isEmpty ? email : name,
                    style: AppTypography.ibm(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildStatusBadge(effectiveStatus),
              ],
            ),
            if (name.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                email,
                style: AppTypography.ibm(
                  color: AppColors.textDisabled,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 10),
            // Tier + AI quota row
            Row(
              children: [
                _buildTierBadge(tier),
                const SizedBox(width: 8),
                _buildAiQuotaBadge(aiQuota),
                const Spacer(),
                if (dateStr.isNotEmpty)
                  Text(
                    dateStr,
                    style: AppTypography.ibm(
                      color: AppColors.textDisabled,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            // Expiry info
            if (remainingTime != null && effectiveStatus == 'active') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 14,
                    color: isUrgent
                        ? const Color(0xFFF59E0B)
                        : AppColors.accentPrimary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    remainingTime,
                    style: AppTypography.ibm(
                      color: isUrgent
                          ? const Color(0xFFF59E0B)
                          : AppColors.accentPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (expiresAt != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      'Expires ${DateFormat('MMM d, yyyy').format(expiresAt.toDate())}',
                      style: AppTypography.ibm(
                        color: AppColors.textDisabled,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ],
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                notes,
                style: AppTypography.ibm(
                  color: AppColors.textDisabled,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final Color color;
    final String label;
    switch (status) {
      case 'active':
        color = AppColors.accentPrimary;
        label = 'Active';
      case 'expired':
        color = const Color(0xFFF59E0B); // amber
        label = 'Expired';
      default:
        color = AppColors.errorRed;
        label = 'Revoked';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTypography.ibm(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTierBadge(String tier) {
    final Color color;
    switch (tier) {
      case 'club':
        color = AppColors.accentPrimary;
      case 'elite':
        color = const Color(0xFFAB9FF2);
      default:
        color = const Color(0xFF5B9BD5);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        tier[0].toUpperCase() + tier.substring(1),
        style: AppTypography.ibm(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildAiQuotaBadge(int quota) {
    final label = quota == -1
        ? 'AI: Unlimited'
        : quota == 0
            ? 'AI: Tier default'
            : 'AI: $quota/mo';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTypography.ibm(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 12,
        ),
      ),
    );
  }

  // ── Add Partner ──────────────────────────────────────────────────────────

  void _showAddPartnerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddPartnerSheet(onGrantCreated: _loadGrants),
    );
  }

  // ── Edit Grant ──────────────────────────────────────────────────────────

  void _showEditSheet(Map<String, dynamic> grant) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditGrantSheet(
        grant: grant,
        onUpdated: _loadGrants,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Duration Pill Selector (shared between Add and Edit sheets)
// ═══════════════════════════════════════════════════════════════════════════

const _durationOptions = <MapEntry<String, Duration>>[
  MapEntry('1 Week', Duration(days: 7)),
  MapEntry('1 Month', Duration(days: 30)),
  MapEntry('3 Months', Duration(days: 90)),
];

/// Snap a Duration to the nearest predefined option, or null if no match.
Duration? _snapToPredefined(Duration d) {
  for (final opt in _durationOptions) {
    final diff = (d.inDays - opt.value.inDays).abs();
    if (diff <= 3) return opt.value;
  }
  return null;
}

Widget _buildDurationPills({
  required Duration? selected,
  required ValueChanged<Duration?> onChanged,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Duration',
          style:
              AppTypography.ibm(color: AppColors.textDisabled, fontSize: 13)),
      const SizedBox(height: 8),
      Row(
        children: _durationOptions.map((opt) {
          final isSelected =
              selected != null && selected.inDays == opt.value.inDays;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(opt.value),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.accentPrimary.withValues(alpha: 0.2)
                      : AppColors.bgPrimary,
                  borderRadius:
                      BorderRadius.circular(AppDecorations.radiusMd),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.accentPrimary
                        : AppColors.separatorDark,
                  ),
                ),
                child: Center(
                  child: Text(
                    opt.key,
                    style: AppTypography.ibm(
                      color: isSelected
                          ? AppColors.accentPrimary
                          : AppColors.textDisabled,
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    ],
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// Add Partner Bottom Sheet
// ═══════════════════════════════════════════════════════════════════════════

class _AddPartnerSheet extends StatefulWidget {
  final VoidCallback onGrantCreated;
  const _AddPartnerSheet({required this.onGrantCreated});

  @override
  State<_AddPartnerSheet> createState() => _AddPartnerSheetState();
}

class _AddPartnerSheetState extends State<_AddPartnerSheet> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  Map<String, dynamic>? _selectedUser;
  String _selectedTier = 'pro';
  Duration? _selectedDuration = const Duration(days: 30);
  final _quotaController = TextEditingController(text: '0');
  bool _unlimitedAi = false;
  final _notesController = TextEditingController();
  bool _isSearching = false;
  bool _isSaving = false;
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _quotaController.dispose();
    _notesController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (query.trim().length < 3) {
        setState(() => _searchResults = []);
        return;
      }
      setState(() => _isSearching = true);
      try {
        final results =
            await PartnerGrantService.searchUsers(query.trim());
        if (mounted) setState(() => _searchResults = results);
      } catch (_) {}
      if (mounted) setState(() => _isSearching = false);
    });
  }

  Future<void> _createGrant() async {
    if (_selectedUser == null) return;
    setState(() => _isSaving = true);
    try {
      final aiQuota = _unlimitedAi ? -1 : (int.tryParse(_quotaController.text) ?? 0);
      await PartnerGrantService.createGrant(
        userId: _selectedUser!['userId'] as String,
        email: _selectedUser!['email'] as String,
        displayName: _selectedUser!['displayName'] as String,
        tier: _selectedTier,
        aiQuota: aiQuota,
        notes: _notesController.text.trim(),
        duration: _selectedDuration,
      );
      widget.onGrantCreated();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create grant: $e',
                style: AppTypography.ibm(color: Colors.white)),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Add Partner Grant',
              style: AppTypography.ibm(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),

            // User search
            if (_selectedUser == null) ...[
              Text('Search by name, email, or username',
                  style: AppTypography.ibm(
                      color: AppColors.textDisabled, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: AppTypography.ibm(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Name, email, or username...',
                  hintStyle: AppTypography.ibm(color: AppColors.textDisabled),
                  filled: true,
                  fillColor: AppColors.bgPrimary,
                  prefixIcon: const Icon(Icons.search,
                      color: AppColors.textDisabled, size: 20),
                  suffixIcon: _isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.accentPrimary),
                          ),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppDecorations.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (_searchResults.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 160),
                  decoration: BoxDecoration(
                    color: AppColors.bgPrimary,
                    borderRadius:
                        BorderRadius.circular(AppDecorations.radiusMd),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    itemBuilder: (_, i) {
                      final user = _searchResults[i];
                      final username = user['username'] as String? ?? '';
                      final subtitle = username.isNotEmpty
                          ? '@$username  ·  ${user['email'] ?? ''}'
                          : (user['email'] as String? ?? '');
                      return ListTile(
                        dense: true,
                        title: Text(
                          user['displayName'] as String? ?? '',
                          style: AppTypography.ibm(
                              color: Colors.white, fontSize: 14),
                        ),
                        subtitle: Text(
                          subtitle,
                          style: AppTypography.ibm(
                              color: AppColors.textDisabled, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => setState(() {
                          _selectedUser = user;
                          _searchResults = [];
                          _searchController.clear();
                        }),
                      );
                    },
                  ),
                ),
              ],
            ] else ...[
              // Selected user
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accentPrimary.withValues(alpha: 0.1),
                  borderRadius:
                      BorderRadius.circular(AppDecorations.radiusMd),
                  border: Border.all(
                      color: AppColors.accentPrimary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person,
                        color: AppColors.accentPrimary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedUser!['displayName'] as String? ?? '',
                            style: AppTypography.ibm(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w500),
                          ),
                          Text(
                            _selectedUser!['email'] as String? ?? '',
                            style: AppTypography.ibm(
                                color: AppColors.textDisabled, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _selectedUser = null),
                      child: const Icon(Icons.close,
                          color: AppColors.textDisabled, size: 18),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Tier selector
            Text('Tier',
                style: AppTypography.ibm(
                    color: AppColors.textDisabled, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: ['pro', 'elite', 'club'].map((tier) {
                final selected = _selectedTier == tier;
                final Color color;
                switch (tier) {
                  case 'club':
                    color = AppColors.accentPrimary;
                  case 'elite':
                    color = const Color(0xFFAB9FF2);
                  default:
                    color = const Color(0xFF5B9BD5);
                }
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTier = tier),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? color.withValues(alpha: 0.2)
                            : AppColors.bgPrimary,
                        borderRadius:
                            BorderRadius.circular(AppDecorations.radiusMd),
                        border: Border.all(
                          color: selected
                              ? color
                              : AppColors.separatorDark,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          tier[0].toUpperCase() + tier.substring(1),
                          style: AppTypography.ibm(
                            color: selected ? color : AppColors.textDisabled,
                            fontSize: 14,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Duration selector
            _buildDurationPills(
              selected: _selectedDuration,
              onChanged: (d) => setState(() => _selectedDuration = d),
            ),
            const SizedBox(height: 20),

            // AI quota
            Text('AI Analysis Quota',
                style: AppTypography.ibm(
                    color: AppColors.textDisabled, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _unlimitedAi = !_unlimitedAi),
                  child: Row(
                    children: [
                      Icon(
                        _unlimitedAi
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        color: _unlimitedAi
                            ? AppColors.accentPrimary
                            : AppColors.textDisabled,
                        size: 22,
                      ),
                      const SizedBox(width: 6),
                      Text('Unlimited',
                          style: AppTypography.ibm(
                              color: Colors.white, fontSize: 14)),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                if (!_unlimitedAi)
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: _quotaController,
                      keyboardType: TextInputType.number,
                      style:
                          AppTypography.ibm(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle:
                            AppTypography.ibm(color: AppColors.textDisabled),
                        filled: true,
                        fillColor: AppColors.bgPrimary,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                              AppDecorations.radiusMd),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                if (!_unlimitedAi)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text('/ month',
                        style: AppTypography.ibm(
                            color: AppColors.textDisabled, fontSize: 14)),
                  ),
              ],
            ),
            if (!_unlimitedAi)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '0 = use tier default (Pro: 10, Elite: 30)',
                  style: AppTypography.ibm(
                      color: AppColors.textDisabled, fontSize: 12),
                ),
              ),
            const SizedBox(height: 20),

            // Notes
            Text('Notes',
                style: AppTypography.ibm(
                    color: AppColors.textDisabled, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 2,
              style: AppTypography.ibm(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'E.g. Poker coach partnership',
                hintStyle: AppTypography.ibm(color: AppColors.textDisabled),
                filled: true,
                fillColor: AppColors.bgPrimary,
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppDecorations.radiusMd),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Grant button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedUser == null || _isSaving
                    ? null
                    : _createGrant,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentPrimary,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor:
                      AppColors.accentPrimary.withValues(alpha: 0.3),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black),
                      )
                    : Text(
                        'Grant Access',
                        style: AppTypography.ibm(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Edit Grant Bottom Sheet
// ═══════════════════════════════════════════════════════════════════════════

class _EditGrantSheet extends StatefulWidget {
  final Map<String, dynamic> grant;
  final VoidCallback onUpdated;
  const _EditGrantSheet({required this.grant, required this.onUpdated});

  @override
  State<_EditGrantSheet> createState() => _EditGrantSheetState();
}

class _EditGrantSheetState extends State<_EditGrantSheet> {
  late String _selectedTier;
  late TextEditingController _quotaController;
  late bool _unlimitedAi;
  late TextEditingController _notesController;
  Duration? _selectedDuration;
  bool _isSaving = false;

  bool get _isActive {
    final status = widget.grant['status'] as String?;
    return status == 'active';
  }

  bool get _isInactive {
    final status = widget.grant['status'] as String?;
    return status == 'revoked' || status == 'expired';
  }

  String get _statusLabel {
    final status = widget.grant['status'] as String?;
    if (status == 'expired') return 'expired';
    if (status == 'revoked') return 'revoked';
    // Check client-side expiration for active grants
    final expiresAt = widget.grant['expiresAt'] as Timestamp?;
    if (status == 'active' &&
        expiresAt != null &&
        DateTime.now().isAfter(expiresAt.toDate())) {
      return 'expired';
    }
    return status ?? 'revoked';
  }

  @override
  void initState() {
    super.initState();
    _selectedTier = (widget.grant['tier'] as String?) ?? 'pro';
    final quota = widget.grant['aiQuota'] as int? ?? 0;
    _unlimitedAi = quota == -1;
    _quotaController =
        TextEditingController(text: _unlimitedAi ? '0' : '$quota');
    _notesController =
        TextEditingController(text: (widget.grant['notes'] as String?) ?? '');

    // Initialize duration from existing expiresAt
    final expiresAt = widget.grant['expiresAt'] as Timestamp?;
    if (expiresAt != null && _isActive) {
      final remaining = expiresAt.toDate().difference(DateTime.now());
      if (remaining.isNegative) {
        _selectedDuration = const Duration(days: 30); // default for expired
      } else {
        _selectedDuration =
            _snapToPredefined(remaining) ?? const Duration(days: 30);
      }
    } else if (_isInactive) {
      _selectedDuration = const Duration(days: 30); // default for reactivation
    }
  }

  @override
  void dispose() {
    _quotaController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      final aiQuota =
          _unlimitedAi ? -1 : (int.tryParse(_quotaController.text) ?? 0);
      await PartnerGrantService.updateGrant(
        widget.grant['id'] as String,
        tier: _selectedTier,
        aiQuota: aiQuota,
        notes: _notesController.text.trim(),
        duration: _selectedDuration,
      );
      widget.onUpdated();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e',
                style: AppTypography.ibm(color: Colors.white)),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _revokeGrant() async {
    bool confirmed = false;
    await ConfirmDialog.show(
      context,
      title: 'Revoke Grant',
      message:
          'This will remove free access for ${widget.grant['displayName'] ?? widget.grant['email']}. They will fall back to their purchased plan.',
      confirmLabel: 'Revoke',
      onConfirm: () => confirmed = true,
    );
    if (!confirmed) return;
    setState(() => _isSaving = true);
    try {
      await PartnerGrantService.revokeGrant(widget.grant['id'] as String);
      widget.onUpdated();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to revoke: $e',
                style: AppTypography.ibm(color: Colors.white)),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _reactivateGrant() async {
    setState(() => _isSaving = true);
    try {
      await PartnerGrantService.reactivateGrant(
        widget.grant['id'] as String,
        duration: _selectedDuration,
      );
      widget.onUpdated();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reactivate: $e',
                style: AppTypography.ibm(color: Colors.white)),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.grant['displayName'] as String?) ?? '';
    final email = (widget.grant['email'] as String?) ?? '';
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final statusLabel = _statusLabel;
    final isActiveGrant = statusLabel == 'active';

    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Edit Partner Grant',
              style: AppTypography.ibm(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),

            // User info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgPrimary,
                borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person,
                      color: AppColors.textDisabled, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name.isEmpty ? email : name,
                            style: AppTypography.ibm(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w500)),
                        if (name.isNotEmpty)
                          Text(email,
                              style: AppTypography.ibm(
                                  color: AppColors.textDisabled, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (isActiveGrant) ...[
              // Tier selector
              Text('Tier',
                  style: AppTypography.ibm(
                      color: AppColors.textDisabled, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: ['pro', 'elite', 'club'].map((tier) {
                  final selected = _selectedTier == tier;
                  final Color color;
                  switch (tier) {
                    case 'club':
                      color = AppColors.accentPrimary;
                    case 'elite':
                      color = const Color(0xFFAB9FF2);
                    default:
                      color = const Color(0xFF5B9BD5);
                  }
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTier = tier),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: selected
                              ? color.withValues(alpha: 0.2)
                              : AppColors.bgPrimary,
                          borderRadius:
                              BorderRadius.circular(AppDecorations.radiusMd),
                          border: Border.all(
                            color: selected ? color : AppColors.separatorDark,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            tier[0].toUpperCase() + tier.substring(1),
                            style: AppTypography.ibm(
                              color:
                                  selected ? color : AppColors.textDisabled,
                              fontSize: 14,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Duration selector
              _buildDurationPills(
                selected: _selectedDuration,
                onChanged: (d) => setState(() => _selectedDuration = d),
              ),
              const SizedBox(height: 20),

              // AI quota
              Text('AI Analysis Quota',
                  style: AppTypography.ibm(
                      color: AppColors.textDisabled, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: [
                  GestureDetector(
                    onTap: () =>
                        setState(() => _unlimitedAi = !_unlimitedAi),
                    child: Row(
                      children: [
                        Icon(
                          _unlimitedAi
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          color: _unlimitedAi
                              ? AppColors.accentPrimary
                              : AppColors.textDisabled,
                          size: 22,
                        ),
                        const SizedBox(width: 6),
                        Text('Unlimited',
                            style: AppTypography.ibm(
                                color: Colors.white, fontSize: 14)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  if (!_unlimitedAi)
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: _quotaController,
                        keyboardType: TextInputType.number,
                        style: AppTypography.ibm(
                            color: Colors.white, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: '0',
                          hintStyle: AppTypography.ibm(
                              color: AppColors.textDisabled),
                          filled: true,
                          fillColor: AppColors.bgPrimary,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                                AppDecorations.radiusMd),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  if (!_unlimitedAi)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text('/ month',
                          style: AppTypography.ibm(
                              color: AppColors.textDisabled, fontSize: 14)),
                    ),
                ],
              ),
              if (!_unlimitedAi)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '0 = use tier default (Pro: 10, Elite: 30)',
                    style: AppTypography.ibm(
                        color: AppColors.textDisabled, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 20),

              // Notes
              Text('Notes',
                  style: AppTypography.ibm(
                      color: AppColors.textDisabled, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLines: 2,
                style: AppTypography.ibm(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'E.g. Poker coach partnership',
                  hintStyle:
                      AppTypography.ibm(color: AppColors.textDisabled),
                  filled: true,
                  fillColor: AppColors.bgPrimary,
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppDecorations.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Save + Revoke buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : _revokeGrant,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.errorRed,
                        side: const BorderSide(color: AppColors.errorRed),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppDecorations.radiusLg),
                        ),
                      ),
                      child: Text('Revoke',
                          style: AppTypography.ibm(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentPrimary,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor:
                            AppColors.accentPrimary.withValues(alpha: 0.3),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppDecorations.radiusLg),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.black),
                            )
                          : Text('Save Changes',
                              style: AppTypography.ibm(
                                  fontWeight: FontWeight.w600, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Expired or revoked state — show status + duration + reactivate
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (statusLabel == 'expired'
                          ? const Color(0xFFF59E0B)
                          : AppColors.errorRed)
                      .withValues(alpha: 0.1),
                  borderRadius:
                      BorderRadius.circular(AppDecorations.radiusMd),
                ),
                child: Row(
                  children: [
                    Icon(
                      statusLabel == 'expired'
                          ? Icons.schedule
                          : Icons.block,
                      color: statusLabel == 'expired'
                          ? const Color(0xFFF59E0B)
                          : AppColors.errorRed,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        statusLabel == 'expired'
                            ? 'This grant has expired'
                            : 'This grant has been revoked',
                        style: AppTypography.ibm(
                            color: statusLabel == 'expired'
                                ? const Color(0xFFF59E0B)
                                : AppColors.errorRed,
                            fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Duration selector for reactivation
              _buildDurationPills(
                selected: _selectedDuration,
                onChanged: (d) => setState(() => _selectedDuration = d),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _reactivateGrant,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentPrimary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppDecorations.radiusLg),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black),
                        )
                      : Text('Reactivate Grant',
                          style: AppTypography.ibm(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
