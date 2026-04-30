import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import '../services/opponent_service.dart';
import '../models/opponent.dart';

/// Bottom sheet for configuring a single seat: name (with opponent search),
/// stack, and hero toggle.
class SeatConfigSheet extends StatefulWidget {
  final int seatNumber;
  final String initialName;
  final double initialStack;
  final bool isHero;
  final bool isActive;
  final double defaultStack;
  final String heroName;
  final Map<String, int> seatedPlayers; // lowercase name → seat
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
    required this.onSave,
  }) : super(key: key);

  @override
  State<SeatConfigSheet> createState() => _SeatConfigSheetState();
}

class _SeatConfigSheetState extends State<SeatConfigSheet> {
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
        _onNameChanged(); // Trigger initial filter
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
    // Move focus to stack field
    FocusScope.of(context).nextFocus();
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _stackController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String hint, {String? prefixText}) {
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.55,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF131616),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle (non-scrolling)
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),

            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.seatConfigSeatTitle(widget.seatNumber),
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 20,
                            color: const Color(0xFF62E3BC),
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.43,
                          ),
                        ),
                        if (_isActive)
                          GestureDetector(
                            onTap: () {
                              widget.onSave(
                                name: '',
                                stack: 0,
                                isHero: false,
                                isActive: false,
                              );
                              Navigator.pop(context);
                            },
                            child: Text(
                              l10n.seatConfigRemove,
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 15,
                                color: const Color(0xFFFF4444),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

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
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF89F1EC),
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
                        prefixText: '\$ ',
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Save button
                    GestureDetector(
                      onTap: _save,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF62E3BC),
                          borderRadius: BorderRadius.circular(60),
                        ),
                        child: Center(
                          child: Text(
                            _isActive ? l10n.seatConfigUpdateButton : l10n.seatConfigAddPlayerButton,
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 17,
                              color: Colors.black,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.43,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
