import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import '../design_system/components/form_drawer.dart';
import '../services/currency_service.dart';
import '../services/opponent_service.dart';
import '../models/opponent.dart';

/// Bottom sheet for configuring a single seat: name (with opponent search),
/// stack, and hero toggle. Uses FormDrawer for consistent design.
class SeatConfigSheet extends StatefulWidget {
  final int seatNumber;
  final String initialName;
  final double initialStack;
  final bool isHero;
  final bool isActive;
  final double defaultStack;
  final String heroName;
  final Map<String, int> seatedPlayers; // lowercase name → seat
  final bool isCash;
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
    required this.onSave,
  }) : super(key: key);

  /// Show the seat config sheet using FormDrawer.
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
    required void Function({
      required String name,
      required double stack,
      required bool isHero,
      required bool isActive,
    }) onSave,
  }) {
    final l10n = AppLocalizations.of(context);
    // Use a GlobalKey to access state for the save action
    final bodyKey = GlobalKey<_SeatConfigBodyState>();

    return FormDrawer.show(
      context: context,
      title: l10n.seatConfigSeatTitle(seatNumber),
      heightFraction: 0.55,
      onSave: () {
        bodyKey.currentState?._save();
      },
      body: _SeatConfigBody(
        key: bodyKey,
        seatNumber: seatNumber,
        initialName: initialName,
        initialStack: initialStack,
        isHero: isHero,
        isActive: isActive,
        defaultStack: defaultStack,
        heroName: heroName,
        seatedPlayers: seatedPlayers,
        isCash: isCash,
        onSave: onSave,
      ),
    );
  }

  @override
  State<SeatConfigSheet> createState() => _SeatConfigSheetState();
}

class _SeatConfigSheetState extends State<SeatConfigSheet> {
  @override
  Widget build(BuildContext context) {
    // Legacy build — callers should use SeatConfigSheet.show() instead
    return _SeatConfigBody(
      seatNumber: widget.seatNumber,
      initialName: widget.initialName,
      initialStack: widget.initialStack,
      isHero: widget.isHero,
      isActive: widget.isActive,
      defaultStack: widget.defaultStack,
      heroName: widget.heroName,
      seatedPlayers: widget.seatedPlayers,
      isCash: widget.isCash,
      onSave: widget.onSave,
    );
  }
}

/// The form body content, used inside FormDrawer.
class _SeatConfigBody extends StatefulWidget {
  final int seatNumber;
  final String initialName;
  final double initialStack;
  final bool isHero;
  final bool isActive;
  final double defaultStack;
  final String heroName;
  final Map<String, int> seatedPlayers;
  final bool isCash;
  final void Function({
    required String name,
    required double stack,
    required bool isHero,
    required bool isActive,
  }) onSave;

  const _SeatConfigBody({
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
    required this.onSave,
  }) : super(key: key);

  @override
  State<_SeatConfigBody> createState() => _SeatConfigBodyState();
}

class _SeatConfigBodyState extends State<_SeatConfigBody> {
  late TextEditingController _nameController;
  late TextEditingController _stackController;
  late bool _isHero;
  late bool _isActive;
  List<Opponent> _allOpponents = [];
  List<Opponent> _filteredOpponents = [];
  bool _showSaveAsOpponent = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _stackController = TextEditingController(
      text: widget.initialStack > 0
          ? widget.initialStack.toStringAsFixed(
              widget.initialStack == widget.initialStack.roundToDouble()
                  ? 0
                  : 2)
          : '',
    );
    _isHero = widget.isHero;
    _isActive = widget.isActive;
    _loadOpponents();
    _nameController.addListener(_onNameChanged);
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
      setState(() {
        _filteredOpponents = [];
        _showSaveAsOpponent = false;
      });
      return;
    }
    final matches = _allOpponents
        .where((o) => o.name.toLowerCase().contains(query))
        .take(5)
        .toList();
    final exactMatch = _allOpponents.any((o) => o.name.toLowerCase() == query);
    setState(() {
      _filteredOpponents = matches;
      _showSaveAsOpponent = !exactMatch && query.length >= 2;
    });
  }

  Future<void> _saveAsNewOpponent() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    try {
      final newOpponent = OpponentService.createNewOpponent(name: name);
      await OpponentService.saveOpponent(newOpponent);
      _allOpponents.add(newOpponent);
      setState(() {
        _showSaveAsOpponent = false;
        _filteredOpponents = [];
      });
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.seatConfigSavedAsOpponent(name)),
            backgroundColor: const Color(0xFF1A1A1E),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {}
  }

  void _selectOpponent(Opponent opponent) {
    _nameController.removeListener(_onNameChanged);
    _nameController.text = opponent.name;
    _nameController.addListener(_onNameChanged);
    setState(() {
      _filteredOpponents = [];
      _showSaveAsOpponent = false;
    });
    FocusScope.of(context).nextFocus();
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _stackController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String hint, {String? prefixText, String? suffixText}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.ibmPlexSans(
        color: Colors.white.withOpacity(0.4),
        fontSize: 17,
        fontWeight: FontWeight.w400,
        height: 1.44,
      ),
      prefixText: prefixText,
      prefixStyle: GoogleFonts.ibmPlexSans(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w400,
        height: 1.44,
      ),
      suffixText: suffixText,
      suffixStyle: GoogleFonts.ibmPlexSans(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w400,
        height: 1.44,
      ),
      filled: true,
      fillColor: const Color(0xFF1C1C1E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: const Color(0xFF1B262D).withOpacity(0.6),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: const Color(0xFF1B262D).withOpacity(0.6),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF89F1EC)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  void _save() {
    final name = _nameController.text.trim();
    final stackText = _stackController.text.trim();
    final stack = stackText.isEmpty
        ? widget.defaultStack
        : (double.tryParse(stackText) ?? widget.defaultStack);

    widget.onSave(
      name: name,
      stack: stack,
      isHero: _isHero,
      isActive: true,
    );
    Navigator.pop(context);
  }

  void _remove() {
    widget.onSave(
      name: '',
      stack: 0,
      isHero: false,
      isActive: false,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "This is me" toggle
          GestureDetector(
            onTap: () {
              if (!_isHero) {
                // Toggling ON — auto-save with hero name + default stack and close
                final stackText = _stackController.text.trim();
                final stack = stackText.isNotEmpty
                    ? (double.tryParse(stackText) ?? widget.defaultStack)
                    : widget.defaultStack;
                widget.onSave(
                  name: widget.heroName.isNotEmpty ? widget.heroName : _nameController.text.trim(),
                  stack: stack,
                  isHero: true,
                  isActive: true,
                );
                Navigator.pop(context);
                return;
              }
              setState(() => _isHero = false);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _isHero
                    ? const Color(0xFF62E3BC).withOpacity(0.15)
                    : const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isHero
                      ? const Color(0xFF62E3BC)
                      : const Color(0xFF1B262D).withOpacity(0.6),
                  width: _isHero ? 2 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isHero
                        ? Icons.person
                        : Icons.person_outline,
                    color: _isHero
                        ? const Color(0xFF62E3BC)
                        : Colors.white.withOpacity(0.6),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.seatConfigThisIsMe,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 14,
                      color: _isHero
                          ? const Color(0xFF62E3BC)
                          : Colors.white.withOpacity(0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Name field with opponent search
          Text(
            l10n.seatConfigNameLabel,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 13,
              color: Colors.white.withOpacity(0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _nameController,
            style: GoogleFonts.ibmPlexSans(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w400,
              height: 1.44,
            ),
            decoration: _inputDecoration(l10n.seatConfigSearchOrEnterName),
            textCapitalization: TextCapitalization.words,
          ),

          // Opponent search results + save option
          if (_filteredOpponents.isNotEmpty || _showSaveAsOpponent)
            Container(
              margin: const EdgeInsets.only(top: 4),
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2A2A2E)),
              ),
              child: ListView(
                padding: const EdgeInsets.all(6),
                shrinkWrap: true,
                children: [
                  ..._filteredOpponents.map((opponent) {
                    final seatedAt = widget.seatedPlayers[opponent.name.toLowerCase()];
                    return GestureDetector(
                      onTap: () => _selectOpponent(opponent),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        margin: const EdgeInsets.only(bottom: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131616),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: opponent.color.flutterColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              opponent.name,
                              style: GoogleFonts.ibmPlexSans(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            if (seatedAt != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  l10n.seatConfigSeatTitle(seatedAt!),
                                  style: GoogleFonts.ibmPlexSans(
                                    color: const Color(0xFF8C8C8C),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                  if (_showSaveAsOpponent)
                    GestureDetector(
                      onTap: _saveAsNewOpponent,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        margin: const EdgeInsets.only(bottom: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131616),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.person_add_outlined,
                              color: Color(0xFF62E3BC),
                              size: 16,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                l10n.seatConfigSaveAsOpponent(_nameController.text.trim()),
                                style: GoogleFonts.ibmPlexSans(
                                  color: const Color(0xFF62E3BC),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

          const SizedBox(height: 14),

          // Stack field
          Text(
            l10n.seatConfigStackLabel,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 13,
              color: Colors.white.withOpacity(0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _stackController,
            keyboardType: const TextInputType.numberWithOptions(
                decimal: true),
            style: GoogleFonts.ibmPlexSans(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w400,
              height: 1.44,
            ),
            decoration: _inputDecoration(
              widget.defaultStack.toStringAsFixed(0),
              prefixText: widget.isCash ? CurrencyService.prefixText : null,
              suffixText: widget.isCash ? CurrencyService.suffixText : null,
            ),
          ),
          const SizedBox(height: 20),

          // Remove button (only for active seats)
          if (_isActive)
            Center(
              child: GestureDetector(
                onTap: _remove,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    l10n.seatConfigRemove,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 15,
                      color: const Color(0xFFFF4444),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
