import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/opponent.dart';
import '../models/opponent_stats.dart';
import '../services/free_tier_limits.dart';
import '../services/opponent_service.dart';
import '../services/opponent_stats_service.dart';
import '../services/subscription_service.dart';
import '../widgets/global_loading_spinner.dart';
import 'opponent_detail_screen.dart';
import 'opponent_hands_screen.dart';
import '../design_system/components/cards/error_state_card.dart';
import '../services/app_data_cache.dart';
import '../l10n/app_localizations.dart';

class MyOpponentsScreen extends StatefulWidget {
  // Static cache accessible from other screens
  static List<Opponent>? _cachedOpponents;
  static Map<String, int>? _cachedHandsCounts;
  static Map<String, OpponentStats>? _cachedStats;

  /// Clear the static cache - call this when opponents are added/modified from other screens
  static void invalidateCache() {
    _cachedOpponents = null;
    _cachedHandsCounts = null;
    _cachedStats = null;
  }

  @override
  _MyOpponentsScreenState createState() => _MyOpponentsScreenState();
}

class _MyOpponentsScreenState extends State<MyOpponentsScreen> with SingleTickerProviderStateMixin {
  List<Opponent> opponents = [];
  Map<String, int> opponentHandsCounts = {};
  Map<String, OpponentStats> opponentStats = {};
  bool isLoading = true;
  String? error;
  String searchQuery = '';
  late TextEditingController _searchController;

  // Inline form state
  bool _showAddForm = false;
  Opponent? _editingOpponent;
  late TextEditingController _nameController;
  late TextEditingController _notesController;
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _notesFocusNode = FocusNode();
  final FocusNode _searchFocusNode = FocusNode();
  OpponentColor _selectedFormColor = OpponentColor.green;
  String? _formNameError;
  late AnimationController _formAnimController;
  late Animation<Offset> _formSlideAnimation;
  bool _showSuccessToast = false;
  String _toastMessage = 'Opponent Added';
  bool _isSearchFocused = false;

  static const _colorSwatches = [
    (OpponentColor.green,  Color(0xFF39FF14)),
    (OpponentColor.orange, Color(0xFFFF8A54)),
    (OpponentColor.red,    Color(0xFFFF3B30)),
    (OpponentColor.blue,   Color(0xFF007AFF)),
    (OpponentColor.purple, Color(0xFFBF5AF2)),
    (OpponentColor.teal,   Color(0xFFFFD60A)),
  ];

  @override
  void initState() {
    super.initState();
    _loadOpponents(useCache: !AppDataCache.isOpponentsDirty);
    _searchController = TextEditingController()..addListener(() => setState(() {}));
    _nameController = TextEditingController()..addListener(() => setState(() {}));
    _notesController = TextEditingController()..addListener(() => setState(() {}));
    _nameFocusNode.addListener(() => setState(() {}));
    _notesFocusNode.addListener(() => setState(() {}));
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus && _isSearchFocused) {
        setState(() => _isSearchFocused = false);
      }
    });
    _formAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _formSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _formAnimController, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _notesController.dispose();
    _nameFocusNode.dispose();
    _notesFocusNode.dispose();
    _searchFocusNode.dispose();
    _formAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadOpponents({bool useCache = false}) async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      // Use cache if available and requested
      if (useCache && MyOpponentsScreen._cachedOpponents != null && MyOpponentsScreen._cachedHandsCounts != null && MyOpponentsScreen._cachedStats != null) {
        setState(() {
          opponents = MyOpponentsScreen._cachedOpponents!;
          opponentHandsCounts = MyOpponentsScreen._cachedHandsCounts!;
          opponentStats = MyOpponentsScreen._cachedStats!;
          isLoading = false;
        });
        return;
      }

      // Load basic opponent data (name, color, notes, dates) - fast operation
      final loadedOpponents = await OpponentService.getAllOpponents();

      // PARALLEL LOADING: Load all opponent stats simultaneously instead of sequentially
      // Use opponent.id (not name) since stats are stored by ID in Firebase
      final statsFutures = loadedOpponents.map((opponent) =>
        OpponentStatsService.getOpponentStats(opponent.id)
      ).toList();

      final allStats = await Future.wait(statsFutures);

      // Build lookup maps keyed by opponent ID
      final handsCounts = <String, int>{};
      final statsMap = <String, OpponentStats>{};
      for (int i = 0; i < loadedOpponents.length; i++) {
        final opponent = loadedOpponents[i];
        final stats = allStats[i];
        handsCounts[opponent.id] = stats?.handsPlayed ?? 0;
        if (stats != null) {
          statsMap[opponent.id] = stats;
        }
      }

      // Cache the results
      MyOpponentsScreen._cachedOpponents = loadedOpponents;
      MyOpponentsScreen._cachedHandsCounts = handsCounts;
      MyOpponentsScreen._cachedStats = statsMap;
      AppDataCache.clearOpponentsDirty();

      setState(() {
        opponents = loadedOpponents;
        opponentHandsCounts = handsCounts;
        opponentStats = statsMap;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Failed to load opponents: $e';
        isLoading = false;
      });
    }
  }

  List<Opponent> get filteredOpponents {
    if (searchQuery.isEmpty) return opponents;
    return opponents.where((opponent) {
      final nameMatch = opponent.name.toLowerCase().contains(searchQuery.toLowerCase());
      final stats = opponentStats[opponent.id];
      final styleMatch = stats?.playingStyle.toLowerCase().contains(searchQuery.toLowerCase()) ?? false;
      return nameMatch || styleMatch;
    }).toList();
  }

  Widget _buildIcon(String path, double size, Color color) {
    if (path.endsWith('.svg')) {
      return SvgPicture.asset(
        path,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    } else {
      return Image.asset(
        path,
        width: size,
        height: size,
        color: color,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0C),
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Main content
          GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.translucent,
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopHeader(l10n),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildSearchField(l10n),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildBody(),
                ),
              ),
            ],
          ),
          ),

          // Blur overlay when form is open
          if (_showAddForm)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeAddForm,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(color: Colors.black.withOpacity(0.35)),
                ),
              ),
            ),

          // Bottom: sliding form OR toast OR floating bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRect(
              child: _showAddForm
                  ? SlideTransition(
                      position: _formSlideAnimation,
                      child: _buildInlineForm(l10n, bottomInset),
                    )
                  : SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) => SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 1.5),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                          child: _showSuccessToast
                              ? _buildSuccessToast()
                              : _buildFloatingBottomBar(),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader(AppLocalizations l10n) {
    return Container(
      color: const Color(0xFF161719),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.opponentsTitle,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 17,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        height: 22 / 17,
                      ),
                    ),
                    Builder(builder: (context) {
                      final showFreeCounter = !SubscriptionService.isPremium;
                      final subtitle = showFreeCounter
                          ? l10n.opponentsCountFree(opponents.length, FreeTierLimits.maxOpponentProfiles)
                          : l10n.opponentsCountPremium(opponents.length);
                      return Text(
                        subtitle,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 15,
                          color: const Color(0xFFB9B9B9),
                          fontWeight: FontWeight.w400,
                          height: 22 / 15,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField(AppLocalizations l10n) {
    final isFocused = _isSearchFocused;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161719),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isFocused ? const Color(0xFF4CDE78) : const Color(0xFF161719),
          width: isFocused ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          _buildIcon('icons/figma_icons/search.svg', 18, const Color(0xFFB9B9B9)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onTap: () => setState(() => _isSearchFocused = true),
              style: GoogleFonts.ibmPlexSans(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w400,
                height: 22 / 15,
              ),
              decoration: InputDecoration(
                hintText: l10n.opponentsSearchHint,
                hintStyle: GoogleFonts.ibmPlexSans(
                  color: const Color(0xFFB9B9B9),
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  height: 22 / 15,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: true,
                fillColor: Colors.transparent,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
            ),
          ),
          if (_searchController.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() => searchQuery = '');
              },
              child: const Icon(Icons.cancel, color: Color(0xFFB9B9B9), size: 16),
            ),
        ],
      ),
    );
  }

  Widget _buildSuccessToast() {
    return Center(
      key: const ValueKey('success_toast'),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFA3FF78).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Color(0xFFA3FF78), size: 20),
            const SizedBox(width: 8),
            Text(
              _toastMessage,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white,
                height: 20 / 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingBottomBar() {
    return Row(
      key: const ValueKey('floating_bar'),
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.black,
              size: 18,
            ),
          ),
        ),
        GestureDetector(
          onTap: _openAddForm,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF161719),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFF3A3A3C)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Color(0xFFA3FF78),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: Colors.black, size: 16),
                ),
                const SizedBox(width: 8),
                Text(
                  'Add New Opponent',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 15,
                    color: Colors.white,
                    fontWeight: FontWeight.w400,
                    height: 22 / 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _openAddForm({Opponent? opponent}) {
    setState(() {
      _editingOpponent = opponent;
      _nameController.text = opponent?.name ?? '';
      _notesController.text = opponent?.notes ?? '';
      _selectedFormColor = opponent?.color ?? OpponentColor.green;
      _formNameError = null;
      _showAddForm = true;
    });
    _formAnimController.forward(from: 0);
  }

  void _closeAddForm({bool showToast = false, String toastMessage = 'Opponent Added'}) {
    FocusScope.of(context).unfocus();
    _formAnimController.reverse().then((_) {
      if (!mounted) return;
      setState(() => _showAddForm = false);
      if (showToast) _triggerSuccessToast(message: toastMessage);
    });
  }

  void _triggerSuccessToast({String message = 'Opponent Added'}) {
    setState(() {
      _toastMessage = message;
      _showSuccessToast = true;
    });
    // 350ms slide in + 1500ms hold + 350ms slide out (handled by AnimatedSwitcher)
    Future.delayed(const Duration(milliseconds: 1850), () {
      if (mounted) setState(() => _showSuccessToast = false);
    });
  }

  Future<void> _saveOpponent() async {
    final l10n = AppLocalizations.of(context);
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final isEditing = _editingOpponent != null;

    if (isEditing && name.toLowerCase() != _editingOpponent!.name.toLowerCase()) {
      final existing = await OpponentService.findOpponentByName(name);
      if (existing != null && existing.id != _editingOpponent!.id) {
        setState(() => _formNameError = l10n.opponentAlreadyExists(name));
        return;
      }
    }

    if (!isEditing) {
      final existing = await OpponentService.findOpponentByName(name);
      if (existing != null) {
        setState(() => _formNameError = l10n.opponentAlreadyExists(name));
        return;
      }
    }

    setState(() => _formNameError = null);

    try {
      final newOpponent = isEditing
          ? _editingOpponent!.copyWith(
              name: name,
              notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
              clearNotes: _notesController.text.trim().isEmpty,
              color: _selectedFormColor,
            )
          : OpponentService.createNewOpponent(
              name: name,
              notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
              color: _selectedFormColor,
            );

      await OpponentService.saveOpponent(newOpponent);
      _closeAddForm(showToast: true, toastMessage: isEditing ? 'Opponent Updated Successfully' : 'Opponent Added');
      _loadOpponents(useCache: false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.opponentsErrorGeneric(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildInlineForm(AppLocalizations l10n, double bottomInset) {
    final isEditing = _editingOpponent != null;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            SizedBox(
              height: 20,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    isEditing ? l10n.opponentsEditDialogTitle : l10n.opponentsAddDialogTitle,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0C0C0C),
                      height: 20 / 15,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: _closeAddForm,
                      child: const Icon(Icons.close, color: Color(0xFFB9B9B9), size: 18),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Opponent Name
            Text(
              l10n.opponentsNameHint,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _nameFocusNode.hasFocus ? const Color(0xFF0C0C0C) : const Color(0xFFB9B9B9),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFDFDFD),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _nameFocusNode.hasFocus ? const Color(0xFF4CDE78) : const Color(0xFFEFEFEF),
                  width: _nameFocusNode.hasFocus ? 1.5 : 1.0,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      focusNode: _nameFocusNode,
                      textInputAction: TextInputAction.next,
                      style: GoogleFonts.ibmPlexSans(fontSize: 15, color: const Color(0xFF0C0C0C)),
                      decoration: InputDecoration(
                        hintText: 'Enter name',
                        hintStyle: GoogleFonts.ibmPlexSans(fontSize: 15, color: const Color(0xFFB9B9B9)),
                        filled: true,
                        fillColor: Colors.transparent,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_nameController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () => _nameController.clear(),
                      child: const Icon(Icons.cancel, color: Color(0xFFB9B9B9), size: 16),
                    ),
                ],
              ),
            ),
            if (_formNameError != null) ...[
              const SizedBox(height: 4),
              Text(
                _formNameError!,
                style: GoogleFonts.ibmPlexSans(fontSize: 12, color: const Color(0xFFE85A5A)),
              ),
            ],
            const SizedBox(height: 12),
            // Notes
            Text(
              'Notes (Optional)',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _notesFocusNode.hasFocus ? const Color(0xFF0C0C0C) : const Color(0xFFB9B9B9),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFDFDFD),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _notesFocusNode.hasFocus ? const Color(0xFF4CDE78) : const Color(0xFFEFEFEF),
                  width: _notesFocusNode.hasFocus ? 1.5 : 1.0,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _notesController,
                      focusNode: _notesFocusNode,
                      style: GoogleFonts.ibmPlexSans(fontSize: 15, color: const Color(0xFF0C0C0C)),
                      decoration: InputDecoration(
                        hintText: 'Add notes',
                        hintStyle: GoogleFonts.ibmPlexSans(fontSize: 15, color: const Color(0xFFB9B9B9)),
                        filled: true,
                        fillColor: Colors.transparent,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      maxLines: 2,
                      minLines: 1,
                    ),
                  ),
                  if (_notesController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () => _notesController.clear(),
                      child: const Icon(Icons.cancel, color: Color(0xFFB9B9B9), size: 16),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Color picker
            Text(
              l10n.opponentsPickColor,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFB9B9B9),
              ),
            ),
            const SizedBox(height: 8),
            StatefulBuilder(
              builder: (context, setSwatchState) => Row(
                children: _colorSwatches.map((entry) {
                  final (color, swatchColor) = entry;
                  final isSelected = color == _selectedFormColor;
                  return GestureDetector(
                    onTap: () {
                      setSwatchState(() => _selectedFormColor = color);
                      setState(() => _selectedFormColor = color);
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: const Color(0xFF0C0C0C), width: 2)
                            : null,
                      ),
                      child: Center(
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(color: swatchColor, shape: BoxShape.circle),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 32),
            // Back + Save buttons
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _closeAddForm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFB9B9B9)),
                      ),
                      child: Text(
                        'Back',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0C0C0C),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: _saveOpponent,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C0C0C),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Save',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final l10n = AppLocalizations.of(context);
    if (isLoading) {
      return Center(
        child: GlobalLoadingSpinner(
          message: l10n.opponentsLoadingMessage,
          showLogo: false,
        ),
      );
    }

    if (error != null) {
      return ErrorStateCard(onRetry: () => _loadOpponents(useCache: false));
    }

    final displayOpponents = filteredOpponents;

    if (displayOpponents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 140),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            SvgPicture.asset('assets/icons/UsersThree-inactive.svg', width: 32, height: 32),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                searchQuery.isEmpty ? l10n.opponentsEmptyTitle : l10n.opponentsNoResults,
                textAlign: TextAlign.center,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 17,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  height: 22 / 17,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 24),
              child: Text(
                searchQuery.isEmpty
                    ? l10n.opponentsEmptySubtitle
                    : l10n.opponentsEmptySearchSubtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 15,
                  color: const Color(0xFFB9B9B9),
                  fontWeight: FontWeight.w400,
                  height: 22 / 15,
                ),
              ),
            ),
            if (searchQuery.isEmpty) ...[
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _openAddForm,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add, color: Color(0xFF0C0C0C), size: 16),
                      const SizedBox(width: 8),
                      Text(
                        l10n.opponentsAddButton,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0C0C0C),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: displayOpponents.length,
      itemBuilder: (context, index) {
        final opponent = displayOpponents[index];
        return _buildOpponentCard(opponent);
      },
    );
  }

  /// Get initials (first two letters of the name, or first letter of each word)
  String _getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final words = trimmed.split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return trimmed.length >= 2
        ? trimmed.substring(0, 2).toUpperCase()
        : trimmed[0].toUpperCase();
  }

  Widget _buildOpponentCard(Opponent opponent) {
    final avatarColor = _getColorForOpponent(opponent.color);
    final handsCount = OpponentHandsScreen.filteredHandCounts[opponent.id]
        ?? opponentHandsCounts[opponent.id]
        ?? 0;

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OpponentDetailScreen(opponent: opponent),
          ),
        );
        if (result == true) _loadOpponents(useCache: false);
      },
      onLongPressStart: (details) {
        _showOpponentOptionsMenu(opponent, details.globalPosition);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFF161719), width: 1),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: avatarColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  _getInitials(opponent.name),
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 17,
                    color: (opponent.color == OpponentColor.green || opponent.color == OpponentColor.teal)
                        ? Colors.black
                        : Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 9),
            // Name + chip + notes
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        opponent.name,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 22 / 17,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C2C2E),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$handsCount hands',
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFFB9B9B9),
                                height: 16 / 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    opponent.notes?.isNotEmpty == true
                        ? opponent.notes!
                        : 'No notes added',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFFB9B9B9),
                      height: 16 / 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Caret right
            const Icon(Icons.chevron_right, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  void _showOpponentOptionsMenu(Opponent opponent, Offset tapPosition) {
    final l10n = AppLocalizations.of(context);
    final screenSize = MediaQuery.of(context).size;
    const menuWidth = 200.0;
    const menuHeight = 89.0; // two 44px rows + 1px divider

    // Position: prefer to show above tap, shift left/right to stay on screen
    double left = tapPosition.dx - menuWidth / 2;
    left = left.clamp(16.0, screenSize.width - menuWidth - 16.0);

    double top = tapPosition.dy - menuHeight - 8;
    if (top < 60) top = tapPosition.dy + 8;

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      useSafeArea: false,
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              behavior: HitTestBehavior.opaque,
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            left: left,
            top: top,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: menuWidth,
                decoration: BoxDecoration(
                  color: const Color(0xFF0C0C0C),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 24,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Edit row
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _showEditOpponentDialog(opponent);
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l10n.opponentsEditMenu,
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                color: Colors.white,
                                height: 22 / 15,
                              ),
                            ),
                            SvgPicture.asset(
                              'assets/icons/UsersThree.svg',
                              width: 16,
                              height: 16,
                              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Divider
                    Container(height: 1, color: const Color(0xFF1C1F21)),
                    // Delete row
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _showDeleteConfirmation(opponent);
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l10n.opponentsDeleteMenu,
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFFFF3B30),
                                height: 22 / 15,
                              ),
                            ),
                            SvgPicture.asset(
                              'icons/figma_icons/delete.svg',
                              width: 16,
                              height: 16,
                              colorFilter: const ColorFilter.mode(Color(0xFFFF3B30), BlendMode.srcIn),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorForOpponent(OpponentColor color) {
    switch (color) {
      case OpponentColor.green:  return const Color(0xFF39FF14);
      case OpponentColor.orange: return const Color(0xFFFF8A54);
      case OpponentColor.red:    return const Color(0xFFFF3B30);
      case OpponentColor.blue:   return const Color(0xFF007AFF);
      case OpponentColor.purple: return const Color(0xFFBF5AF2);
      case OpponentColor.teal:   return const Color(0xFFFFD60A);
      case OpponentColor.pink:   return Colors.pink;
      case OpponentColor.indigo: return Colors.indigo;
    }
  }

  void _showEditOpponentDialog(Opponent opponent) {
    _openAddForm(opponent: opponent);
  }





  void _showDeleteConfirmation(Opponent opponent) {
    final l10n = AppLocalizations.of(context);
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Delete opponent',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 200),
      transitionBuilder: (context, animation, _, child) => FadeTransition(
        opacity: animation,
        child: child,
      ),
      pageBuilder: (context, _, __) => Stack(
        children: [
          // Blurred barrier — tap to dismiss
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(color: Colors.black.withValues(alpha: 0.45)),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: SizedBox(
          width: 370,
          child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: title + X
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Delete Opponent',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0C0C0C),
                      height: 20 / 15,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, size: 18, color: Color(0xFFB9B9B9)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Body text
              Text(
                l10n.opponentsDeleteConfirmMessage(opponent.name),
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFFB9B9B9),
                  height: 22 / 15,
                ),
              ),
              const SizedBox(height: 32),
              // Buttons row
              Row(
                children: [
                  // Cancel
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFB9B9B9)),
                        ),
                        child: Text(
                          l10n.commonCancel,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0C0C0C),
                            height: 20 / 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Confirm
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        try {
                          await OpponentService.deleteOpponent(opponent.id);
                          Navigator.pop(context);
                          _loadOpponents(useCache: false);
                          _triggerSuccessToast(message: 'Opponent Deleted');
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l10n.opponentsErrorDeleting(e.toString())),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF3B30),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Confirm',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 20 / 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),        // closes Column
          ),        // closes Container
        ),          // closes SizedBox
      ),            // closes Dialog
    ),              // closes Padding
  ),                // closes Center
],                  // closes Stack children
      ),            // closes Stack
    );
  }

}