import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import '../services/currency_service.dart';
import '../services/opponent_service.dart';
import '../models/opponent.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/decorations.dart';

class SeatConfigSheet extends StatefulWidget {
  final int seatNumber;
  final String initialName;
  final double initialStack;
  final bool isHero;
  final bool isActive;
  final double defaultStack;
  final String heroName;
  final Map<String, int> seatedPlayers;
  final bool isCash;
  final bool showSaveAsOpponent;
  final String? titleOverride;
  final void Function({
    required String name,
    required double stack,
    required bool isHero,
    required bool isActive,
  }) onSave;

  const SeatConfigSheet({
    Key? key,
    required this.seatNumber,
    required this.initialName,
    required this.initialStack,
    required this.isHero,
    required this.isActive,
    required this.defaultStack,
    this.heroName = '',
    this.seatedPlayers = const {},
    this.isCash = true,
    this.showSaveAsOpponent = true,
    this.titleOverride,
    required this.onSave,
  }) : super(key: key);

  static Future<void> show({
    required BuildContext context,
    required int seatNumber,
    required String initialName,
    required double initialStack,
    required bool isHero,
    required bool isActive,
    required double defaultStack,
    String heroName = '',
    Map<String, int> seatedPlayers = const {},
    bool isCash = true,
    bool showSaveAsOpponent = true,
    String? titleOverride,
    required void Function({
      required String name,
      required double stack,
      required bool isHero,
      required bool isActive,
    }) onSave,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SeatConfigSheet(
        seatNumber: seatNumber,
        initialName: initialName,
        initialStack: initialStack,
        isHero: isHero,
        isActive: isActive,
        defaultStack: defaultStack,
        heroName: heroName,
        seatedPlayers: seatedPlayers,
        isCash: isCash,
        showSaveAsOpponent: showSaveAsOpponent,
        titleOverride: titleOverride,
        onSave: onSave,
      ),
    );
  }

  @override
  State<SeatConfigSheet> createState() => _SeatConfigSheetState();
}

class _SeatConfigSheetState extends State<SeatConfigSheet> {
  late TextEditingController _nameController;
  late TextEditingController _stackController;
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _stackFocusNode = FocusNode();
  late bool _isHero;
  late bool _isActive;
  bool _saveAsOpponent = false;
  List<Opponent> _allOpponents = [];
  List<Opponent> _filteredOpponents = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _stackController = TextEditingController(
      text: widget.initialStack > 0
          ? widget.initialStack.toStringAsFixed(
              widget.initialStack == widget.initialStack.roundToDouble() ? 0 : 2)
          : '',
    );
    _isHero = widget.isHero;
    _isActive = widget.isActive;
    _nameController.addListener(_onNameChanged);
    _stackController.addListener(() => setState(() {}));
    _nameFocusNode.addListener(() => setState(() {}));
    _stackFocusNode.addListener(() => setState(() {}));
    _loadOpponents();
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _stackController.dispose();
    _nameFocusNode.dispose();
    _stackFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadOpponents() async {
    try {
      final opponents = await OpponentService.getAllOpponents();
      if (mounted) {
        setState(() => _allOpponents = opponents);
        _onNameChanged();
      }
    } catch (_) {}
  }

  void _onNameChanged() {
    final query = _nameController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _filteredOpponents = []);
      return;
    }
    setState(() {
      _filteredOpponents = _allOpponents
          .where((o) => o.name.toLowerCase().contains(query))
          .take(5)
          .toList();
    });
  }

  void _selectOpponent(Opponent opponent) {
    _nameController.removeListener(_onNameChanged);
    _nameController.text = opponent.name;
    _nameController.addListener(_onNameChanged);
    setState(() => _filteredOpponents = []);
    FocusScope.of(context).unfocus();
  }

  void _save() {
    final stackText = _stackController.text.trim();
    final stack = stackText.isEmpty
        ? widget.defaultStack
        : (double.tryParse(stackText) ?? widget.defaultStack);
    final name = _isHero && widget.heroName.isNotEmpty
        ? widget.heroName
        : _nameController.text.trim();
    widget.onSave(name: name, stack: stack, isHero: _isHero, isActive: true);

    if (_saveAsOpponent && name.isNotEmpty && !_isHero) {
      _saveAsNewOpponent(name);
    }

    Navigator.pop(context);
  }

  void _remove() {
    widget.onSave(name: '', stack: 0, isHero: false, isActive: false);
    Navigator.pop(context);
  }

  Future<void> _saveAsNewOpponent(String name) async {
    try {
      final existing = await OpponentService.findOpponentByName(name);
      if (existing != null) return;
      final opponent = OpponentService.createNewOpponent(name: name);
      await OpponentService.saveOpponent(opponent);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context).seatConfigSavedAsOpponent(name)),
          backgroundColor: AppColors.accentPrimary,
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (_) {}
  }

  Color _opponentColor(Opponent o) => o.color.flutterColor;

  String _initials(String name) =>
      name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase();

  Widget _buildToggle(bool value) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 38,
      height: 24,
      decoration: BoxDecoration(
        color: value ? AppColors.textOnInverse : AppColors.borderLight,
        borderRadius: BorderRadius.circular(74),
        border: Border.all(
          color: value ? AppColors.textOnInverse : AppColors.borderLight,
        ),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 180),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 18,
          height: 18,
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: AppColors.bgInverse,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgInverse,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppDecorations.radiusXl),
            topRight: Radius.circular(AppDecorations.radiusXl),
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── HEADER ──────────────────────────────────────────
              Row(
                children: [
                  const SizedBox(width: 18),
                  Expanded(
                    child: Center(
                      child: Text(
                        widget.titleOverride ?? l10n.seatConfigSeatTitle(widget.seatNumber),
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textOnInverse,
                          height: 20 / 15,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close,
                        size: 18, color: AppColors.borderLight),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ─── THIS IS MY SEAT ─────────────────────────────────
              GestureDetector(
                onTap: () => setState(() {
                  _isHero = !_isHero;
                  if (_isHero) {
                    // Hero is never saved as an opponent
                    _saveAsOpponent = false;
                    // Auto-fill hero name and default stack
                    if (widget.heroName.isNotEmpty) {
                      _nameController.removeListener(_onNameChanged);
                      _nameController.text = widget.heroName;
                      _nameController.addListener(_onNameChanged);
                      _filteredOpponents = [];
                    }
                    if (_stackController.text.isEmpty && widget.defaultStack > 0) {
                      _stackController.text = widget.defaultStack == widget.defaultStack.roundToDouble()
                          ? widget.defaultStack.toInt().toString()
                          : widget.defaultStack.toStringAsFixed(2);
                    }
                  }
                }),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isHero
                              ? AppColors.textOnInverse
                              : AppColors.borderLight,
                          width: 1.5,
                        ),
                      ),
                      child: _isHero
                          ? Center(
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.textOnInverse,
                                ),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.seatConfigThisIsMe,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textOnInverse,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ─── PLAYER NAME ──────────────────────────────────────
              Text(
                l10n.seatConfigNameLabel,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _nameFocusNode.hasFocus
                      ? AppColors.textOnInverse
                      : AppColors.borderLight,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.bgInputOnInverse,
                  borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                  border: Border.all(
                    color: _nameFocusNode.hasFocus
                        ? AppColors.accentPrimary
                        : AppColors.borderOnInverseSubtle,
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
                        textCapitalization: TextCapitalization.words,
                        style: GoogleFonts.ibmPlexSans(
                            fontSize: 15, color: AppColors.textOnInverse),
                        decoration: InputDecoration(
                          hintText: l10n.seatConfigSearchOrEnterName,
                          hintStyle: GoogleFonts.ibmPlexSans(
                              fontSize: 15, color: AppColors.borderLight),
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
                        child: Icon(Icons.cancel,
                            color: AppColors.borderLight, size: 16),
                      ),
                  ],
                ),
              ),

              // Inline autocomplete chips
              if (_filteredOpponents.isNotEmpty) ...[
                const SizedBox(height: 4),
                ..._filteredOpponents.map((opponent) {
                  final seatedAt =
                      widget.seatedPlayers[opponent.name.toLowerCase()];
                  return GestureDetector(
                    onTap: () => _selectOpponent(opponent),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: _opponentColor(opponent),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                _initials(opponent.name),
                                style: GoogleFonts.ibmPlexSans(
                                  fontSize: 7.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            opponent.name,
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                              height: 20 / 13,
                            ),
                          ),
                          if (seatedAt != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.accentSecondary,
                                borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
                              ),
                              child: Text(
                                l10n.seatConfigSeatTitle(seatedAt),
                                style: GoogleFonts.ibmPlexSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textOnInverse,
                                  height: 16 / 11,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              ],

              // ─── SAVE AS OPPONENT ─────────────────────────────────
              if (widget.showSaveAsOpponent) ...[
                const SizedBox(height: 8),
                GestureDetector(
                onTap: () => setState(() {
                  _saveAsOpponent = !_saveAsOpponent;
                  // Hero is never saved as an opponent; turning the toggle
                  // off must NOT touch the hero selection
                  if (_saveAsOpponent) _isHero = false;
                }),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.bgInputOnInverse,
                    border: Border.all(color: AppColors.borderOnInverseSubtle),
                    borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Save as opponent',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.borderLight,
                        ),
                      ),
                      _buildToggle(_saveAsOpponent),
                    ],
                  ),
                ),
              ),
              ],

              const SizedBox(height: 8),

              // ─── STACK ────────────────────────────────────────────
              Text(
                l10n.seatConfigStackLabel,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _stackFocusNode.hasFocus
                      ? AppColors.textOnInverse
                      : AppColors.borderLight,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.bgInputOnInverse,
                  borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                  border: Border.all(
                    color: _stackFocusNode.hasFocus
                        ? AppColors.accentPrimary
                        : AppColors.borderOnInverseSubtle,
                    width: _stackFocusNode.hasFocus ? 1.5 : 1.0,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    if (widget.isCash && CurrencyService.prefixText != null) ...[
                      Text(
                        CurrencyService.prefixText!,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: _stackFocusNode.hasFocus
                              ? AppColors.textOnInverse
                              : AppColors.borderLight,
                        ),
                      ),
                    ],
                    Expanded(
                      child: TextField(
                        controller: _stackController,
                        focusNode: _stackFocusNode,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                        ],
                        style: GoogleFonts.ibmPlexSans(
                            fontSize: 15, color: AppColors.textOnInverse),
                        decoration: InputDecoration(
                          hintText: '',
                          hintStyle: GoogleFonts.ibmPlexSans(
                              fontSize: 15, color: AppColors.borderLight),
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
                    if (widget.isCash && CurrencyService.suffixText != null) ...[
                      Text(
                        CurrencyService.suffixText!,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: _stackFocusNode.hasFocus
                              ? AppColors.textOnInverse
                              : AppColors.borderLight,
                        ),
                      ),
                    ],
                    if (_stackController.text.isNotEmpty)
                      GestureDetector(
                        onTap: () => _stackController.clear(),
                        child: Icon(Icons.cancel,
                            color: AppColors.borderLight, size: 16),
                      ),
                  ],
                ),
              ),

              // Remove link (only for already-active seats). For the hero's
              // own seat this unseats the user — the save handler clears
              // ourSeatNumber so it never dangles on a reassigned seat.
              if (_isActive) ...[
                const SizedBox(height: 16),
                Center(
                  child: GestureDetector(
                    onTap: _remove,
                    child: Text(
                      widget.isHero
                          ? l10n.seatConfigRemoveMe
                          : l10n.seatConfigRemove,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.accentDanger,
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // ─── FOOTER ───────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          border:
                              Border.all(color: AppColors.borderLight),
                          borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
                        ),
                        child: Center(
                          child: Text(
                            'Back',
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textOnInverse,
                              height: 20 / 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: _save,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.bgPrimary,
                          borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
                        ),
                        child: Center(
                          child: Text(
                            'Save',
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.bgInverse,
                              height: 20 / 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(
                  height: MediaQuery.of(context).padding.bottom + 24),
            ],
          ),
        ),
      ),
    );
  }
}
